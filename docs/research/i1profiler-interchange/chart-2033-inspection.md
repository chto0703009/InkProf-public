# Reference case: Chart 2033 Patches

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Reviewed 2026-09-25. Original files provided by Christer from i1Profiler. The exact i1Profiler version has not yet been stated. No re-import into i1Profiler or physical measurement has been carried out.

**Later addition the same day:** a TXF has since been added and reviewed separately in the [TXF note](chart-2033-txf-inspection.md). Statements below about the absence of a TXF describe the first material with two files.

## Files and preservation

The originals are kept unchanged under `tests/fixtures/i1profiler/chart-2033/` in InkProf:

- `Chart 2033 Patches.pxf`
- `Chart 2033 Patches.txt`

The files are target definitions, not measurement results. Reference data from an external program must not be regarded as InkProf code or be given new rights claims through copying.

## Checked results

| Check | Result |
|---|---|
| PXF format | XML with the namespace `http://colorexchangeformat.com/CxF3-core`. |
| PXF producer | `X-Rite - Prism`. |
| TXT format | `CGATS.17`, producer `i1Profiler - X-Rite, Inc.`. |
| Patch count | 2,033 in both; the TXT also declares 2,033 rows. |
| IDs | PXF `c1`–`c2033`, TXT `1`–`2033`, consecutive. |
| Channels | RGB, values in the range 0–255 in this reference case. |
| Identical RGB rows | 23 of 2,033. |
| Differing channel values | 4,861 of 6,099. |
| Largest absolute deviation | 0.96 on the 0–255 scale, about 0.3765 percentage points on the 0–100 scale. |
| Relationship between the files | All PXF channels are exactly the integer part of the corresponding non-negative TXT value. This is truncation, not rounding to the nearest integer. |
| Unique RGB triplets | 2,027 in each file; repeated patches must be preserved. |
| PXF location elements | No `Location` elements were found. |
| Spectra | None; the TXT has only ID, name and RGB. |

Example: patch 2 has R = 23 in the PXF and R = 23.18 in the TXT. Patch 5 has R = 92 and 92.73 respectively. The files' ID sequence and the channel-by-channel truncation relationship support that they describe the same ordered patch set with different numerical precision.

This verifies the relationship in these particular files. It does not prove how all i1Profiler exports work or which of the values are used internally when i1Profiler prints.

## PXF metadata must not be over-interpreted

Custom Prism resources contain, among other things, `NumberPatchPages="2"`, but `NumberPatchColumns="0"` and `NumberPatchRows="0"`. The value fields of the patch dimensions are also zero. There is also `ScramblePatches="False"` and various paper and profile settings. Taken together, this does not give a complete physical patch map.

`MeasurementDevice="i1Pro 3"` and serial number `0` occur. This is exported setting information, not evidence of an instrument actually used or calibrated. Numeric codes such as `MeasurementMode="1"`, `SelectedMeasurementCondition="-1"` and `DimensionUnit="2"` are preserved without guessed interpretation.

`BitDepth` is 16 under `ProfileSettings`, while the RGB patch values themselves are integers in the range 0–255. This profile setting therefore gives no evidence of higher precision in the patch values or that a TIFF has been exported.

## Consequences for the first delivery

1. These files suffice as real reference cases for PXF import and one i1Profiler CGATS variant.
2. The TXT variant must not be treated as TI3 with RGB percentages. In this case 0–255 is used, even though the format is CGATS-based.
3. PXF and TXT must be imported separately with their actual values. They must not be merged or silently made equal.
4. To retain the higher available numerical resolution when generating a new TIFF16, the TXT can be chosen. This does not promise exact reproduction of an earlier i1Profiler print.
5. Without a TXF or other complete layout description we create a new instrument-adapted layout and a matching TI2. No original physical layout is claimed to be preserved.
6. A TIFF16 from the PXF does not restore the decimals that are missing. Exact reproduction of source values and the export's quantisation is checked separately.
7. The generated map's later i1Profiler compatibility remains to be verified; the files solve the patch import, not the whole layout interchange.

## Proposed regression expectations

The importer must obtain 2,033 patches and preserve all repetitions. ID mapping, the files' separate precision and the difference results above must be reproducible. A missing full layout must be reported. `BitDepth=16` must not change the interpretation of the RGB encoding.

The review was done with separate XML and table reading and decimal arithmetic. It is not a full XSD validation or a test of a finished InkProf importer.
