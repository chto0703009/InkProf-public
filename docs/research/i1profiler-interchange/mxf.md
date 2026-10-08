# MXF: i1Profiler Measurements

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Current status: see [acceptance 2026-09-27](acceptance-20260927.md).
Dated statements below about pending import tests describe earlier troubleshooting.

Date: 2026-09-25. Status: preliminary read/write contract for InkProf.

Three [real MXF reference cases](mxf-examples-inspection.md) have now been reviewed: CMYK with Lab only and two RGB files with spectra for M0/M1/M2. They give concrete position keys via `TagCollection Name="Location"`; XML object ID and `SampleID` cannot alone be assumed to link measurement to target.

## Source-backed role

`.mxf` here denotes i1Profiler's measurement format, not the video format with the same extension. X-Rite lists it as Measurements. [S5] In the CxF3 variant, the target's device values are linked to measurement results. [S4] See [common rules and sources](README.md).

## Proposed meaning in InkProf

MXF is the main candidate for importing a complete profiling basis from i1Profiler. Completeness must however be checked in each file: spectra, measurement conditions, layout and instrument metadata must not be assumed to be present merely because of the file extension.

## Concrete reading map from reviewed ChromIQ code

```text
Resources / ObjectCollection / Object
  target objects:      DeviceColorValues / ColorRGB / R, G, B
  measurement objects: ColorValues / ReflectanceSpectrum
```

The reviewed converter searches for object groups with designations such as `Target` and `M0_Measurement`, `M1_Measurement` or `M2_Measurement`. These designations and the linking by list order are observations of a supported variant, not universal CxF rules.

## Import requirements

- Establish an unambiguous link between target and measurement. Use explicit references where they exist. Order requires a verified ordering contract; an equal number of objects is not sufficient proof.
- Keep all measurement conditions and repetitions. Do not silently select the first group.
- Read wavelength information from the spectrum and the associated specification. Do not always assume 380 nm start or 10 nm interval.
- Preserve both spectra and existing colorimetry. Document whether XYZ/Lab is later recalculated and under what conditions.
- Preserve unknown metadata without calling it verified. Do not correct suspected scales by guessing.

## Export requirements

InkProf must have matched control values and measurements for the chosen target. The chosen i1Profiler version, XML variant, colour specifications and any private resources must be verified with a reference file and an import test.

If only Lab/XYZ exists, spectra must not be constructed as if they were measured. If spectra exist, they should be included in the supported export variant; any reduction to colorimetry must be clearly reported. Resampling and rounding must be reported numerically.

## Interchange with TI3 and ChromIQ

MXF → TI3 must keep control values, measurement links and available spectra. If several measurement conditions must be split into several TI3 files, a manifest must link the files to the original.

The locally reviewed ChromIQ function `cxf_measurement_to_ti3` writes only RGB and derived XYZ, not spectral columns. Its result is therefore insufficient for a spectral re-export to MXF. Read the original MXF in InkProf or use another verified conversion path. See code revision and details in the [overview](README.md#code-observations-in-local-chromiq).

## Verification cases

Test several measurement conditions, repeated patches, different wavelength intervals and a deliberately reordered measurement list. Incorrect linking must be detected. Compare spectra and metadata after a full read/write cycle, not just calculated ΔE.

## Practical review of i1Profiler 3.8.5

See the [verification report](ui-verification-3.8.5.md) for observed menu choices, the performed MXF import, spectral CGATS export and TIFF export. The report distinguishes performed tests from remaining format and layout verification.

## First spectral export candidate (2026-09-27)

`exchange/export_mxf.py` creates an M0 candidate from a complete canonical
measurement JSON and a real Prism/CxF3 reference file with the same target order.
RGB is compared position by position before export; equal colours are not used as a
unique key. Target and measurement objects get the same Page/Column/Row from chart.json.
Padding cells are omitted. M1/M2 from the reference are removed, spectra are divided
by 100 without resampling, and the original XYZ values accompany the JSON
report. The file's colorimetry is calculated by the recipient from the spectra.

This is a limited adapter for the observed 380–730 nm/10 nm,
XRGA, RGB, M0 variant. Private Prism attributes come partly from the reference
and are compatibility aids, not verified information about paper/print.
Private profile settings are removed. Re-reading checks all RGB values,
position links and spectra. Import in the recipient program remains to be done.

The first file uses the complete 575 measurement from 09:58. Separate
control measurements of row 19 and rows 1–3 have not been merged in automatically.

### Import error and serialisation v2

The first candidate was rejected by the recipient with `Error reading CxF version
information` (the user's screenshot 2026-09-27 11:34). ElementTree had changed the
XML declaration and namespace serialisation, and the exporter had removed
PrismAppName/PrismAppVersion. V2 preserves the reference's outer XML, version tags
and private prefixes, while Creator still states InkProf. The version tags
are compatibility markers for the dialect, not a claim that the file was created
by i1Profiler. All RGB and spectra are identical to the first candidate.
Which single difference triggered the error has not been isolated. V2 requires a new
import test; XML correctness alone is not recipient verification.

## RGB and later choice of paper type (2026-09-27)

InkProf works with RGB targets. RGB is therefore a fixed colour format in this flow,
not a user choice between RGB and CMYK. CMYK input must be rejected with an
understandable error about the wrong colour format.

The **Glossy/Matte** choice under Paper Information can be introduced in a later step.
It does not need to be decided for the current format verification. On import,
an existing paper choice must be preserved in internal JSON and be able to accompany
the export. A missing value must be left unknown until the user specifies it; a
reference file's default value must not be described as verified print paper.
A later user choice must be kept separate from the imported original value
so that origin and change can be followed.

The working reference file and the rejected MXF v2 export both state
`ColorSpace="RGB"` and `Paper="Glossy"`. These two fields therefore do not explain
the difference in import result. How Glossy/Matte affects the recipient's
profile calculation has not yet been verified. The choice must not be interpreted as M0/M1/M2
or used to change already measured spectra.

## Implemented measurement import (2026-09-27)

`inkprof.importMeasurement()` takes TI3 or MXF and opens the same colour chart
as internal measurements. The spectral MXF adapter uses explicit
position keys, preserves original and metadata, and creates a normalised
TI3 and measurement JSON. An accepted spot re-measurement gives a new TI3/JSON revision;
the original MXF is not changed. See [usage and limitations](../../usage/measurement-file-import.md).

## 2026-09-29: iteration 2, 911 patches and integer RGB compatibility

The merged 575 + 336 fitting-patch MXF was rejected by i1Profiler 3.8.5 with
“Error reading CxF version information”. This message did not identify the
actual numerical serialization issue. Restoring only Creator, FileInformation,
and ProfileSettings did not fix the decimal-RGB variant. With the known-good
reference envelope unchanged, replacing decimal ColorRGB values by integers
0–255 made the file load. The final file was opened in the Measurement step:
`InkProf-911-iteration2-M0-compatible-RGB8.mxf` (XRGA, M0, Glossy).
This verifies import, not subsequent profile generation or colour accuracy.

`exchange/repair_mxf_compatibility.py` implements this limited compatibility
route. It requires matching spectral specifications and unambiguous locations,
retains the reference metadata envelope, pairs spectra and RGB by location, and
writes a sidecar mapping original Target names to exported names. The
`--allow-rgb8-rounding` flag is required for material rounding; existing outputs
are never overwritten. Tests cover explicit rounding consent, mapping, spectral
preservation and overwrite refusal.

All 911 × 36 spectral samples were preserved. The maximum channel rounding was
0.4980665 on 0–255 (0.1953202 percentage points). Thus this is **not an exact-RGB
comparison** against the full-precision InkProf fit. JSON and TI3 remain the
full-precision source. In sensitive regions even small RGB rounding can matter.
The 84 frozen holdouts and 80 control occurrences are not included in the 911
fitting export. The later 15 ramp points are also not included.

Creator, dates, private profile settings and printer/paper fields retained from
the reference are compatibility metadata, not proof of source provenance or a
prescription for the recipient's profiling recipe. See the export JSON for
actual sources and per-patch rounding. The virtual layout is for transfer and
profile construction, not physical remeasurement. Do not infer that all CxF or
CGATS routes have this same RGB8 limitation.
