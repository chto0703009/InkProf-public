# TXF verification with licence dongle, 2026-09-26

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Check in i1Profiler 3.8.5 with a visible PUBLISH & DEVICE LINK licence. Four TXF candidates from the current `createTiff16` were tested, based on 2033 RGB patches, random seed 42 and 287 padding fields. Each candidate contains 580 positions on one page.

## Result and correction

The import retains i1Pro 2, 263 × 195 mm, 29 columns × 20 rows and 8 × 8 mm patches. The first image check showed that the recipient places objects column by column, whereas the exporter previously wrote them row by row. `writeTxfCandidate` has therefore been corrected: only the TXF object order changes, while the TIFF/TI2 and the physical JSON map keep their order. The coordinate names follow the correct patch even after the reordering. The regression test checks both RGB and names after re-import.

All four corrected TXF files were opened and saved as TIFF through the recipient's user interface. The inner colour fields of all 2320 patches match exactly against InkProf's JSON and TIFF basis, including padding. The recipient's TIFF is RGB8 at about 101.6 dpi and is used only as a control image, not as a replacement for InkProf's TIFF16. All test values are exactly representable in RGB8.

## Remaining geometric deviation

The recipient's colour fields begin at x=15.5 mm, whereas the InkProf template begins at x=14.75 mm. The deviation is +0.75 mm horizontally. The Y position 24.5 mm and the patch size 8 × 8 mm match. After this constant x offset, the whole patch rectangles were compared: 2320 of 2320 matched exactly, maximum RGB8 deviation 0.

Absolute page placement is thus not identical. No physical row measurement has been performed and the files continue to be marked as candidates. No general compatibility flag has been set to approved. Older candidates created before the order correction must be regenerated; the print images are not changed by the correction.

Each TXF is a separate page. The recipient therefore shows Page 1 of 1 and local row numbers even for InkProf's pages 2–4. Use the correct page file and preserve the JSON map when merging measurement results later. The reviewed path is the `createTiff16` page template; the older `exportTxfTarget` path for Argyll layouts with separators has not been qualified here.

## Evidence

Machine-readable report and file hashes: `txf-template-verification-2026-09-26.json`. Local tests and re-exports: `work/txf-verification-20260926/` (ignored working directory). The last page's TXF was also re-exported as XML; all 580 RGB objects retained values and order.
