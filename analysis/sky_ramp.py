# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Blue-sky gradient diagnostic for an ICC output profile (numerical, not print validation).

The reference path follows the sky of the user's banding test image (adobe church,
blue sky). It was derived from 1 602 sky pixels of an 8-bit sRGB screenshot
(columns 40, 450, 880 and 910), converted to D50 Lab (Bradford-adapted sRGB) and
fitted by quadratics in L*:
    a*(L) = -0.0002925 L^2 + 0.0266884 L - 3.4891828   (max |residual| 1.3)
    b*(L) =  0.0233526 L^2 - 1.9894985 L + 1.5542271   (max |residual| 2.5)
The pixels span L* 38.8-67.8; banding was reported around L* 40-55. Two parallel
paths (b* +/- 4) test the neighbourhood. Only the fitted coefficients are kept,
not the image.

Each path is sent through the profile's B2A (xicclu -fb, relative colorimetric
and perceptual), giving the printer RGB the driver would receive, and back
through A2B. A smooth Lab ramp should give smooth printer RGB: large second
differences, RGB reversals or long 8-bit plateaus mark kinks/posterisation.
"""
import argparse, hashlib, json, subprocess
from pathlib import Path
import numpy as np

A_COEFF = (-0.0002925, 0.0266884, -3.4891828)
B_COEFF = (0.0233526, -1.9894985, 1.5542271)
L_RANGE = (38.0, 70.0)
BAND_WINDOW = (40.0, 55.0)
OFFSETS = (('sky', 0.0), ('sky b*-4', -4.0), ('sky b*+4', 4.0))
SAMPLES = 1025


def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def sky_paths(samples=SAMPLES):
    L = np.linspace(*L_RANGE, samples)
    a = np.polyval(A_COEFF, L); b = np.polyval(B_COEFF, L)
    return {name: np.column_stack([L, a, b + offset]) for name, offset in OFFSETS}


def lookup(exe, profile, values, direction, intent):
    if intent not in ('r', 'p') or direction not in ('f', 'b'):
        raise ValueError('Unsupported lookup.')
    values = np.asarray(values, dtype=float)
    r = subprocess.run([str(exe), '-v0', '-f' + direction, '-i' + intent, '-pl', str(profile)],
                       input=''.join(' '.join(f'{x:.10f}' for x in row) + '\n' for row in values),
                       text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)
    if r.returncode: raise ValueError(r.stderr or r.stdout)
    out = np.asarray([line.split()[:3] for line in r.stdout.splitlines() if line.strip()], dtype=float)
    if out.shape != values.shape or not np.isfinite(out).all(): raise ValueError('Invalid xicclu output.')
    return out


def delta_e00(lab1, lab2):
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'profiles'))
    from colour_math import delta_e00 as de
    return de(lab1, lab2)


def stats(v):
    v = np.asarray(v, dtype=float)
    return dict(mean=float(v.mean()), median=float(np.median(v)), p95=float(np.percentile(v, 95)), max=float(v.max()))


def path_metrics(L, rgb, lab_out):
    """rgb in 0..1 along a Lab path sampled uniformly in L*."""
    dt = (L[-1] - L[0]) / (len(L) - 1)
    first = np.abs(np.diff(rgb, axis=0)).max(axis=1) * 100
    second = np.abs(np.diff(rgb, n=2, axis=0)).max(axis=1) * 100
    window = (L[1:-1] >= BAND_WINDOW[0]) & (L[1:-1] <= BAND_WINDOW[1])
    # Reversals: sign changes of a channel's slope where both steps are clearly non-zero.
    d = np.diff(rgb, axis=0); thr = 1e-5
    rev = (np.sign(d[1:]) * np.sign(d[:-1]) < 0) & (np.abs(d[1:]) > thr) & (np.abs(d[:-1]) > thr)
    steps = delta_e00(lab_out[:-1], lab_out[1:])
    codes = np.clip(np.round(rgb * 255), 0, 255).astype(int)
    changes = np.any(np.diff(codes, axis=0) != 0, axis=1)
    runs, run = [], 1
    for c in changes:
        if c: runs.append(run); run = 1
        else: run += 1
    runs.append(run)
    k = int(np.argmax(second))
    median_step = float(np.median(steps))
    return dict(rgbStepPercent=stats(first), rgbSecondDifferencePercent=stats(second),
                rgbSecondDifferencePercentBandWindow=stats(second[window]) if window.any() else None,
                normalizedCurvatureMax=float(second.max() / 100 / dt ** 2),
                channelReversals=int(rev.sum()), channelReversalsBandWindow=int(rev[window].sum()),
                colourStepDeltaE00=stats(steps),
                colourStepMaxOverMedian=None if median_step < 1e-6 else float(steps.max() / median_step),
                lightnessReversals=int((np.diff(lab_out[:, 0]) < -1e-4).sum()),
                unique8bitCodes=int(len(np.unique(codes, axis=0))), longest8bitPlateau=int(max(runs)),
                worstSecondDifference=dict(L=float(L[k + 1]), rgbPercent=(rgb[k:k + 3] * 100).tolist()))


def run(profile, exe, out):
    profile = Path(profile); out = Path(out)
    if out.exists(): raise ValueError('Output directory already exists.')
    digest = sha(profile)
    results = []
    for intent, label in (('r', 'relative colorimetric'), ('p', 'perceptual')):
        for name, lab in sky_paths().items():
            rgb = lookup(exe, profile, lab, 'b', intent)
            lab_out = lookup(exe, profile, rgb, 'f', intent)
            m = path_metrics(lab[:, 0], rgb, lab_out)
            m.update(path=name, intent=label)
            results.append(m)
    if sha(profile) != digest: raise ValueError('Profile changed during check.')
    main = [r for r in results if r['path'] == 'sky']
    summary = {r['intent']: dict(secondDiffMax=r['rgbSecondDifferencePercent']['max'],
                                 secondDiffBandMax=r['rgbSecondDifferencePercentBandWindow']['max'],
                                 reversalsBand=r['channelReversalsBandWindow'], colourStepMaxOverMedian=r['colourStepMaxOverMedian'],
                                 longest8bitPlateau=r['longest8bitPlateau']) for r in main}
    result = dict(schemaVersion=1, documentType='inkprof.sky-ramp-check', profileSHA256=digest,
                  reference=dict(source="User's blue-sky banding test image (8-bit sRGB screenshot); quadratic fit, coefficients only",
                                 aCoefficients=A_COEFF, bCoefficients=B_COEFF, lRange=L_RANGE, bandWindow=BAND_WINDOW,
                                 samples=SAMPLES, offsets=[o for _, o in OFFSETS]),
                  method='xicclu -fb (B2A) then -ff (A2B); float lookups, no 8-bit conversion except the plateau count',
                  summary=summary, paths=results,
                  caveat='Numerical diagnostic. Smooth B2A output does not prove absence of banding on paper; driver, CMM, dithering and 8-bit image data also matter.')
    out.mkdir(parents=True)
    (out / 'sky-ramp.json').write_text(json.dumps(result, indent=2, allow_nan=False))
    lines = ['# Himmelsgradient (blå himmel, L* 38–70)', '', f'Profil: {digest}', '',
             '| Avsikt | Bana | RGB 2:a diff max (pp) | max i L* 40–55 | Kanalvändningar 40–55 | ΔE-steg max/median | Längsta 8-bitsplatå | Värst vid L* |',
             '|---|---|---:|---:|---:|---:|---:|---:|']
    for r in results:
        ratio = r['colourStepMaxOverMedian']
        lines.append(f"| {r['intent']} | {r['path']} | {r['rgbSecondDifferencePercent']['max']:.4f} | "
                     f"{r['rgbSecondDifferencePercentBandWindow']['max']:.4f} | {r['channelReversalsBandWindow']} | "
                     f"{'–' if ratio is None else f'{ratio:.2f}'} | {r['longest8bitPlateau']} | {r['worstSecondDifference']['L']:.1f} |")
    lines += ['', result['caveat']]
    (out / 'sky-ramp.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return result


if __name__ == '__main__':
    a = argparse.ArgumentParser(); a.add_argument('profile'); a.add_argument('executable'); a.add_argument('output')
    v = a.parse_args(); run(v.profile, v.executable, v.output)
