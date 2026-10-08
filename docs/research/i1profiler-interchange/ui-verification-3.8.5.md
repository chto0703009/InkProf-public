# Practical verification in i1Profiler 3.8.5

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25. Source: direct review of the user's macOS program and files exported from it. These are version-bound observations, not a complete format specification.

## Environment and scope

The start page shows i1Profiler 3.8.5, XRD 3.0.152, Prism 3.7.8.18027 and an active "PUBLISH & DEVICE LINK" licence with green marks. The user has connected a dongle. No comparison with the dongle disconnected was made.

No physical measurement, printing or profile generation was performed. The program reported i1Pro 3 missing in the target flow and i1Pro 2 missing after loading the older measurement basis. Licence access and a connected measuring instrument are separate matters. The original files were not overwritten.

## Observed import and export choices

| Place in the RGB profiling flow | Choices actually shown |
|---|---|
| Patch Set → Load | Patch sets (.pxf), CGATS (.txt), Cxf (.cxf) |
| Test Chart → Save as | TIFF (.tif), PDF (.pdf), EPS (.eps) |
| Measurement → Load | Measurement (.mxf), Reference Measurement (.rmxf), CGATS (.txt), CxF (.cxf) |
| Measurement → Save | MXF, RMXF, CxF, Tab Delimited Text, i1Profiler CGATS Spectral/CIELab/Custom, ProfileMaker5 CGATS Spectral/CIELab |

A listed file type is not proof that all variants are accepted. CMXF was not shown in this measurement import dialog; that does not rule out support in other workflows. **RMXF is an additional observed format**, whose structure has not yet been analysed. It must not be confused with CMXF or given an invented conversion contract.

## Actual TIFF export

The already loaded set "Chart 2033 Patches" showed 2033 patches and Scramble off. The next step showed i1Pro 3, Letter, mm, zero margins and three pages. Export via Save as → TIFF created three separate TIFF files.

A check of all files' TIFF tags gave:

- 1084 × 784 pixels, RGB, one image per file.
- BitsPerSample = (8, 8, 8): **8 bits per channel**.
- Resolution about 101.6 dpi (4 pixels/mm).
- No embedded ICC profile was detected.

This applies to the tested export path and setting, not a general statement about all i1Profiler exports. No bit-depth choice was shown in the save dialog used. The setting for the ICC profile's bit depth must therefore not be used as evidence of the target image's bit depth.

The TIFF images' actual patch order, cropping, control fields and colour values have not been compared pixel by pixel with the TXF. This run is not a verified TXF → image → physical measurement cycle. InkProf's TIFF16 requirement remains and needs to be verified separately in its Argyll-based export.

## Actual MXF import and spectral CGATS export

The file `/Library/Application Support/X-Rite/i1Profiler/ColorSpaceRGB/Measurements/Chart 2040 Patches.mxf` was opened via Measurement → Load. The program showed the correct name, four pages, RGB Printer, XRGA, geometry 45:0 and the choices M0 (UV Included), M1 (D50), M2 (UV Excluded). The XML review of the same original is in the [MXF example report](mxf-examples-inspection.md).

Save → i1Profiler CGATS Spectral was used with M0 selected in the view. **A single export created three files with the suffixes _M0, _M1 and _M2.** The base name happened to already contain M0; it is the suffix and the file's MEASUREMENT_SOURCE that state the respective condition.

Each file contains CGATS.17, 2040 rows and 41 fields: SAMPLE_ID, SAMPLE_NAME, three RGB channels and 36 spectral bands from 380 to 730 nm at 10 nm intervals. RGB is stored on the 0–255 scale. The spectral values correspond to the MXF's reflectance fractions, not percent.

Numerical comparison of all rows against the respective group in the original MXF:

| Check | M0 | M1 | M2 |
|---|---:|---:|---:|
| Number of rows | 2040 | 2040 | 2040 |
| Largest RGB deviation, scale 0–255 | 0 | 0 | 0 |
| Largest spectral deviation, reflectance fraction | 0.00005 | 0.00005 | 0.00005 |

Spectra are written with four decimals. The deviation corresponds to at most 0.005 percentage points of reflectance; it is an export rounding, not measurement uncertainty. The comparison used the order from this particular verified export, not a general assumption for arbitrary files.

The export's SAMPLE_ID is a running number and SAMPLE_NAME is for example A1, B1. They must not be equated with the XML objects' ID. The text format has no separate Page/Row/Column fields in this export. The MXF original's full metadata and position linking must therefore be archived even when CGATS is used.

## Consequences for InkProf

1. Direct MXF import remains suitable for preserving precision, metadata and all measurement conditions.
2. i1Profiler CGATS Spectral is now a concretely tested alternative export path from i1Profiler. InkProf's future adapter needs to recognise SPECTRAL_NM380 etc., RGB 0–255 and reflectance fractions. Argyll's spectral percent encoding requires explicit scaling on TI3 export.
3. Group the multi-file export in a JSON manifest and read the conditions from the content; do not silently choose the first file.
4. Preserve the distinction between observed but untested menu choices, actual file import/export and full compatibility. No InkProf-generated file has yet been re-imported or physically measured here.
5. Investigate RMXF and CMXF in their respective workflows later. They are not needed for the first target delivery.

## Saved verification material

`tests/fixtures/i1profiler/ui-verification-3.8.5/` contains three exported TIFF files, three spectral CGATS files and `verification-results.json` with checksums, TIFF properties and numerical comparisons. The files are reference data from i1Profiler, not a new InkProf implementation.
