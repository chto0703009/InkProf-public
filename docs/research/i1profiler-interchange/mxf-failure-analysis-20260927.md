# Analysis: working MXF, rejected InkProf exports and ChromIQ

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Current status: see [acceptance 2026-09-27](acceptance-20260927.md).
Dated statements below about pending import tests describe earlier troubleshooting.

2026-09-27. Investigation of local files and local ChromIQ code, commit
`92e6ead0`. The original measurements have not been changed.

## Conclusion

The new i1Profiler file is a working reference: the user's screenshot
12:08:06 shows it reopened with colour chart, XRGA, M0 and Device ready.
The earlier message Device: Invalid Argument disappeared after instrument
calibration. This is a separate sequence from the CxF version errors in our exports.

Our two MXF exports are valid XML with complete spectra, but were not
accepted by i1Profiler. Internal XML re-reading was thus not sufficient. Several changes
had been made at the same time. Creator is now a concrete hypothesis, not an established
root cause. Two control files isolate Creator and the spectral payload respectively.

## Comparison

Reference: `InkProf-575-from-TI2-v2_i1profile.mxf`.
Rejected files: `InkProf-575-M0.mxf` and `InkProf-575-M0-v2.mxf`.
All are in the project's exports folder.

| Property | Working reference | Export v1 | Export v2 |
|---|---|---|---|
| Creator | X-Rite - Prism | InkProf | InkProf |
| PrismAppName/PrismAppVersion | i1Profiler / 1.1.0 | Missing | Restored |
| XML declaration | Double quotes | Single quotes | As reference |
| Private Prism prefix | xrp, locally declared | pr, declared on the root | As original template |
| RGB | Integers 0–255 | Decimals from TI2 | Decimals from TI2 |
| Objects | 575 M0 + 575 Target | 575 M0 + 575 Target | 575 M0 + 575 Target |
| Spectral specification | 380–730 nm, 10 nm, XRGA/M0 | Same | Same |
| Layout | 29 columns × 20 rows, 1 page | 21 columns, 2 pages | 21 columns, 2 pages |
| SampleID / SampleName | -1 / empty | Source ID / coordinate | Source ID / coordinate |
| MeasurementMode | 1 | 2, inherited from another template | 2, inherited from another template |
| ProfileSettings | Present | Removed | Removed |
| WriteProtected | True | False | False |
| Line endings/BOM | LF, no BOM | LF, no BOM | LF, no BOM |

That v2 was also rejected shows that restored version tags and XML header
did not solve the problem alone. Different line endings/BOM are not the explanation
for these concrete files. XML permits single quotes and alternative prefixes;
that a reader may be sensitive to serialisation is a hypothesis about the recipient,
not a general XML requirement.

More private attributes differ, including Media_Type, paper dimensions,
title and printer name. The reference states Translucent Media despite the print
flow used. Such private fields must not be interpreted or changed as if their
semantics were fully known.

## The patch linking

The file analysis has verified 575 unique position keys `(Page, Column, Row)`
for both target and M0 measurements. The position sets are identical. All
RGB values and the target's list order match exactly the PXF that InkProf created.
All 575 spectra have 36 finite values. The reflectance factor lies between
0.002413 and 1.049892; no value has been clipped.

The reference fills column by column. The first 20 patches are in column 0, rows
0–19. The InkProf original had two pages with 21 patches per row. This is a
different layout, not in itself an incorrect spectrum. A reordering must move
RGB and spectrum together. Repeated RGB values occur, so RGB alone is
not an unambiguous identity.

## What ChromIQ actually does

Files reviewed:
- `workflow/i1profiler_export.py`: `write_pxf`, `export_from_ti1`, `write_pwxf`.
- `workflow/i1profiler_import.py`: `parse_pxf`.
- `workflow/reference_convert.py`: `cxf_measurement_to_ti3`.
- `docs/dev_pxwf_format.md`.

The PXF export rounds RGB to 8-bit integers, uses TargetN/cN and
WriteProtected=True/ScramblePatches=False. Creator is ChromIQ. InkProf PXF v2
follows corresponding principles and has now been followed through i1Profiler to a saved
MXF whose patch set is verified.

The PWXF export (workflow, not MXF) on the other hand uses Creator=X-Rite - Prism,
Description=Prism CXF3 file and PrismApp version tags. The code comment states
that the header mirrors the original so that the workflow reader will accept the file.
This supports testing Creator separately for MXF too, but does not prove that the
MXF reader has the same requirements. ChromIQ's older document advice says to keep
ChromIQ as Creator until an import test shows otherwise; the current code
thus uses a more conservative header than that document advice.

In the reviewed workflow code, MXF import, PXF and PWXF export were found,
but no corresponding MXF writer to treat as a verified solution.
The MXF import selects one available measurement group, pairs lists by order,
assumes 10 nm wavelength steps, calculates XYZ under D50 and writes TI3 with RGB/XYZ.
It does not write spectral columns or preserve physical SAMPLE_LOC. InkProf
should therefore not copy that path for a lossless MXF interchange.

## Two controlled import tests

The files are in `exports/mxf-compatibility-tests/`, with JSON provenance:

1. **01-Creator-only.mxf**: exactly the same bytes as the working reference, except
   Creator changed from X-Rite - Prism to InkProf. All measurement values are the
   reference's original values. If only this file is rejected, that isolates the
   Creator dependency in this flow.
2. **02-Spectra-only.mxf**: exactly the same reference file outside the 575 spectral
   text fields. There, InkProf's complete M0 measurement from 09:58 has been inserted, with
   percent divided by 100 and a verified numerical re-read error below
   1e-8 in percentage points. Target order is checked against source ID and all RGB;
   measurement objects are linked to target via position keys. No reordering or
   position change is made in the reference file.

Control 2 explicitly retains the reference's Creator, date, layout and
private settings as experimental controls. It is an InkProf-generated
**diagnostic file**, not correct complete production provenance for the InkProf
print. The JSON states the actual source, reference hash, export hash and the mapping
between the original's and the reference's coordinates. Do not use it as a template for
re-measuring the InkProf original's paper.

Test with the same calibrated instrument/app mode as the working reference.
If the Creator test is rejected and the spectral test accepted, the header is a clear
explanation. If both are accepted, the fault lies among the other changes and these
must be introduced one at a time. If the spectral test is rejected, first investigate the payload's
numerical format and the recipient's requirements, without simultaneous layout changes.

Neither of the control files has yet been verified through recipient import.

## Addendum: RGB and Glossy/Matte

A check of the reference and the rejected v2 export shows the same
`ColorSpace="RGB"` and `Paper="Glossy"`. These choices are not a distinguishing
cause of failure. RGB is fixed for InkProf. Glossy/Matte may become a user choice in a
later step; imported data must be preserved, while a missing paper type
must not be guessed from the export template. The significance for the recipient's
profile calculation remains to be verified. See the [MXF specification](mxf.md).
