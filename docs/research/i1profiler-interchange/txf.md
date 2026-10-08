# TXF: i1Profiler Test Charts

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25. Status: preliminary read/write contract for InkProf.

A real [TXF reference case with 2,033 patches](chart-2033-txf-inspection.md) has now been inspected. It documents concrete XML paths and layout attributes; rendering and measurement have not yet been verified.

## Source-backed role

`.txf` is used for i1Profiler's test targets. [S5] The file contains device values and can describe patch placement via CxF3's location information and custom resources. PXF and TXF may be structurally close; the difference is not just the file extension. [S4] See [common rules and sources](README.md).

## Proposed meaning in InkProf

A TXF is treated as a target definition with a possible physical layout. Document separately which parts have actually been read: control values, logical order, page/row/column, size and instrument-related parameters. A missing layout does not mean the patches may be assumed to lie in row order.

## Import requirements

- Read and validate control values according to the [PXF contract](pxf.md).
- Save both original order and physical position when both exist. A permutation between them must be explicit.
- Preserve location data and custom XML resources. Exact paths and units must be established from the schema and reference files; this document states no invented private tags.
- Check that patches are not unintentionally placed at the same position and that page/row/column indices are interpreted according to the producer's convention.
- Match the layout against the printed target before it is used for measurement.

## Export requirements

A target export for measurement needs a real layout that the recipient can use. If i1Profiler regenerates the layout after import, the new target must be printed. Its description must not be used to measure a previously printed sheet with a different placement.

For an already printed chart, the export must preserve patch order and geometry sufficiently for correct identification during measurement. If this cannot be substantiated, InkProf must offer export of a patch set for a new layout, not call the result an equivalent TXF.

## Interchange with Argyll

TXF corresponds functionally to TI2, but a TI2 may require layout and instrument information that has no direct or known TXF equivalent. Conversion requires a specially verified adapter. Changing the extension or copying only the RGB list is not sufficient.

The loss report must distinguish between preserved colour values, changed physical layout and loss of instrument settings. The target image or print file must be archived together with the layout description.

## Verification cases

Test several pages, an incomplete last row, randomised patches and a layout with asymmetric control colours in the corners. Compare the produced chart with the original and check the reading direction. Which private resources the recipient requires is an open version question.

## Practical review of i1Profiler 3.8.5

See the [verification report](ui-verification-3.8.5.md) for observed menu choices, the performed MXF import, spectral CGATS export and TIFF export. The report distinguishes performed tests from remaining format and layout verification.
