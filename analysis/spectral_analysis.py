# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""InkProf spectral analysis v1. External JSON job; no instrument access."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import sys
import tempfile

import colour
import numpy as np
import scipy

ENGINE_VERSION = "1.0.0"
OBSERVERS = {"1931_2": "CIE 1931 2 Degree Standard Observer",
             "1964_10": "CIE 1964 10 Degree Standard Observer"}
ILLUMINANTS = ("D50", "D65", "A")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load(path):
    payload = Path(path).read_bytes()
    return json.loads(payload), hashlib.sha256(payload).hexdigest()


def vector(value, name):
    result = np.asarray(value, dtype=float).reshape(-1)
    require(result.size > 0 and np.isfinite(result).all(), f"Invalid {name}.")
    return result


def matrix(value, columns, name):
    result = np.asarray(value, dtype=float)
    if result.ndim == 1 and result.size == columns:
        result = result.reshape(1, columns)  # MATLAB single-row JSON
    require(result.ndim == 2 and result.shape[1] == columns and result.shape[0] > 0
            and np.isfinite(result).all(), f"Invalid {name} matrix.")
    return result


def labels(value, count, name, optional=False):
    if optional and (value is None or value == []):
        return [""] * count
    if isinstance(value, str):
        value = [value]
    require(isinstance(value, list) and len(value) == count
            and all(isinstance(v, str) for v in value), f"Invalid {name}.")
    return value


def colorimetry(waves, spectra, illuminant="D50", observer="1931_2"):
    """Linear resampling, trapezoid integration on measured support only.

    XYZ is on Y=100 perfect-diffuser scale. No patch-wise normalization,
    extrapolation, adaptation, gamut mapping or fluorescent compensation.
    """
    waves = vector(waves, "wavelengths")
    require(waves.size >= 3 and np.all(np.diff(waves) > 0),
            "At least three strictly increasing wavelengths are required.")
    spectra = matrix(spectra, waves.size, "spectra")
    require(np.all(spectra >= 0), "Negative reflectance is not supported; raw values were not changed.")
    require(illuminant in ILLUMINANTS, "Supported illuminants: D50, D65, A.")
    require(observer in OBSERVERS, "Supported observers: 1931_2, 1964_10.")
    cmf = colour.MSDS_CMFS[OBSERVERS[observer]]
    light = colour.SDS_ILLUMINANTS[illuminant]
    require(waves[0] >= max(cmf.wavelengths[0], light.wavelengths[0])
            and waves[-1] <= min(cmf.wavelengths[-1], light.wavelengths[-1]),
            "Measured wavelength range exceeds the available observer/illuminant data.")
    # Include original knots and endpoints; intervals never exceed 1 nm.
    grid = np.unique(np.r_[waves, np.arange(np.ceil(waves[0]), waves[-1], 1.0)])
    response = np.column_stack([np.interp(grid, cmf.wavelengths, cmf.values[:, j]) for j in range(3)])
    light_values = np.interp(grid, light.wavelengths, light.values)
    weights = light_values[:, None] * response
    white_raw = np.trapezoid(weights, grid, axis=0)
    require(white_raw[1] > 0, "No luminous energy in the measured interval.")
    white = white_raw * (100 / white_raw[1])
    sampled = np.array([np.interp(grid, waves, row) for row in spectra])
    xyz = np.trapezoid(sampled[:, :, None] * weights[None, :, :], grid, axis=1) * (100 / white_raw[1])
    white_xy = colour.XYZ_to_xy(white)
    lab = colour.XYZ_to_Lab(xyz / 100, illuminant=white_xy)
    require(np.isfinite(lab).all(), "Nonfinite colorimetric result.")
    return xyz, lab, white, white_xy


def condition_name(condition):
    for key in ("reported", "interpreted"):
        value = condition.get(key)
        if value in ("M0", "M1", "M2"):
            return value
    return "unknown"


def compare(result, reference):
    require(reference.get("documentType") == "inkprof.spectral-analysis" and reference.get("schemaVersion") == 1,
            "Reference must be an InkProf spectral-analysis JSON v1.")
    require(result["calculation"] == reference.get("calculation"),
            "Reference has different colorimetric settings, white point or spectral support.")
    mode = condition_name(result["measurementCondition"])
    require(mode != "unknown" and mode == condition_name(reference.get("measurementCondition", {})),
            "Delta E comparison requires matching known measurement conditions (M0/M1/M2).")
    current = result["data"]
    other = reference["data"]
    keys = list(zip(current["ids"], current["locations"]))
    other_keys = list(zip(other["ids"], other["locations"]))
    require(len(set(other_keys)) == len(other_keys) and set(keys) == set(other_keys),
            "Reference patch identities differ or are duplicated.")
    lookup = {key: i for i, key in enumerate(other_keys)}
    order = [lookup[key] for key in keys]
    ref_rgb = matrix(other["rgbPercent"], 3, "reference RGB")[order]
    require(np.allclose(current["rgbPercent"], ref_rgb, rtol=0, atol=1e-4),
            "Reference RGB values differ at matched patch identities.")
    ref_lab = matrix(other["lab"], 3, "reference Lab")[order]
    de = colour.difference.delta_E_CIE2000(np.asarray(current["lab"]), ref_lab)
    return {"method": "CIEDE2000", "kL": 1, "kC": 1, "kH": 1,
            "patchDeltaE00": de.tolist(), "count": len(keys), "mean": float(np.mean(de)),
            "median": float(np.median(de)), "p95": float(np.percentile(de, 95)), "max": float(np.max(de)),
            "scope": "All supplied measured rows; includes any measured controls or layout markers. Not a profile accuracy test."}


def analyse(job):
    require(job.get("schemaVersion") == 1, "Unsupported analysis job schema.")
    source_path = Path(job["measurementPath"]).resolve()
    source, digest = load(source_path)
    require(source.get("documentType") == "inkprof.chart-measurement" and source.get("schemaVersion") == 1,
            "Input must be an InkProf chart-measurement JSON v1.")
    scale = job.get("spectralScale")
    require(type(scale) in (int, float) and np.isfinite(scale) and scale > 0,
            "Specify spectralScale explicitly: 100 for percent or 1 for fractional reflectance.")
    data = source["data"]
    declared = data.get("scales", {}).get("SpectralScale")
    require(declared is None or declared == scale, "Spectral scale conflicts with source metadata.")
    waves = vector(data["wavelengthNm"], "wavelengths")
    raw = matrix(data["spectra"], len(waves), "spectra")
    spectra = raw / scale
    rgb = matrix(data["rgbPercent"], 3, "RGB percent")
    require(rgb.shape[0] == raw.shape[0] and np.all((rgb >= 0) & (rgb <= 100)), "Invalid RGB data or row count.")
    ids = labels(data["ids"], len(raw), "patch IDs")
    locations = labels(data.get("locations"), len(raw), "patch locations", optional=True)
    require(all(ids) and len(set(zip(ids, locations))) == len(ids), "Missing or duplicate patch identities.")
    illuminant, observer = job.get("illuminant", "D50"), job.get("observer", "1931_2")
    xyz, lab, white, white_xy = colorimetry(waves, spectra, illuminant, observer)
    notices = ["No fluorescence compensation; relighting fluorescent paper is approximate."]
    if waves[0] > 360 or waves[-1] < 780:
        notices.append("Limited measured wavelength range: no spectral extrapolation; results may differ from full-range or ASTM E308 calculations.")
    if np.max(np.diff(waves)) > 10:
        notices.append("Spectral sampling is coarser than 10 nm; numerical resampling does not recover missing spectral detail.")
    if np.max(spectra) > 1:
        notices.append("Reflectance exceeds 1: retained without clipping; verify scale and fluorescence.")
    condition = source.get("measurementCondition", {"reported": "unknown", "interpreted": "unknown"})
    if condition_name(condition) == "unknown":
        notices.append("Measurement condition is unknown; it has not been inferred from the chosen illuminant.")
    result = {"schemaVersion": 1, "documentType": "inkprof.spectral-analysis",
              "createdUTC": datetime.now(timezone.utc).isoformat(),
              "engine": {"name": "InkProf spectral analysis", "version": ENGINE_VERSION,
                         "python": platform.python_version(), "numpy": np.__version__,
                         "scipy": scipy.__version__, "colourScience": colour.__version__},
              "source": {"path": str(source_path), "sha256": digest,
                         "chartJSONSHA256": source.get("chartJSONSHA256"),
                         "sourceTI3SHA256": source.get("sourceTI3SHA256"),
                         "complete": source.get("complete"), "spectralScale": scale},
              "measurementCondition": condition,
              "calculation": {"illuminant": illuminant, "observer": observer,
                              "method": "linear interpolation; trapezoid; measured support only; grid <= 1 nm",
                              "wavelengthNm": waves.tolist(), "xyzScale": 100,
                              "whiteXYZ100": white.tolist(), "whiteXY": white_xy.tolist(),
                              "adaptation": "none", "fluorescenceCompensation": False},
              "data": {"ids": ids, "locations": locations, "rgbPercent": rgb.tolist(),
                       "chartIndex": source.get("chartIndex"), "xyz100": xyz.tolist(), "lab": lab.tolist()},
              "warnings": notices}
    if "targetInfo" in source:
        result["targetInfo"] = source["targetInfo"]
    if job.get("referenceAnalysisPath"):
        ref_path = Path(job["referenceAnalysisPath"]).resolve()
        reference, ref_hash = load(ref_path)
        result["comparison"] = compare(result, reference)
        result["comparison"]["reference"] = {"path": str(ref_path), "sha256": ref_hash}
    return result


def save_new(path, result):
    """Publish completely written JSON without replacing an existing file."""
    path = Path(path)
    require(path.parent.is_dir(), "Output directory does not exist.")
    payload = json.dumps(result, ensure_ascii=False, allow_nan=False, indent=2) + "\n"
    fd, temporary = tempfile.mkstemp(prefix=".inkprof-analysis-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.link(temporary, path)  # atomic creation; fails if destination exists
    finally:
        os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("job", type=Path)
    args = parser.parse_args()
    try:
        job, _ = load(args.job)
        output = Path(job["outputPath"])
        require(not output.exists(), "Output already exists; choose a new analysis filename.")
        result = analyse(job)
        save_new(output, result)
        print(json.dumps({"status": "saved", "outputPath": str(output.resolve()), "patchCount": len(result["data"]["ids"])}))
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(f"InkProf analysis: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
