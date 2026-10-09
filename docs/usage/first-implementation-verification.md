# First implementation: verification report

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Date: 2026-09-25. MATLAB R2025b Update 7, ArgyllCMS 3.5.0 from `/usr/local/bin`. Implementation in `src/+inkprof`, tests in `tests/testTargets.m`. No ChromIQ code was read or reused during this implementation.

## Completed

The final run passed all **ten test cases**, including portability and the sled width limit:

1. Real PXF/TXF/TXT files with 2033 patches: values, IDs, repeated colours, imported layout attributes and scales.
2. XML with a DTD/entity and with duplicate IDs is rejected.
3. Incorrect CGATS row count and insufficient RGB scale are rejected.
4. Generation, identical randomisation on repeated export, preserved order as an option, padding patches, overwrite protection and detection of a changed package file.
5. Import of the whole TXF target, multiple pages, mapping to the original ID, byte-identical source copy and verification after the package has been moved.
6. Fractional CGATS values, repeated colours, quoted names and paths containing spaces, apostrophes and dollar signs.
7. Relative paths after changing the current MATLAB directory; Java user.dir must not govern them.

8. The whole code package is copied to another directory and configured/run from there, from an independent current folder. Local Argyll configuration is saved separately and the project path follows the new location. This test has passed.
9. A page width above 320 mm is rejected; an export at the limit is checked including margins and pixel rounding.
10. The named formats A4 landscape (297 × 210 mm) and A3 portrait (297 × 420 mm) are exported and pixel-verified. Conflicting format choices and unknown formats are rejected.

MATLAB code analysis gave no error indication; a preallocation recommendation for the short log list is not a functional error.

## Remaining example packages

| Package under `projects/` | Source patches | Argyll padding | Pages | TIFF |
|---|---:|---:|---:|---|
| first-generated-100 | 100 | 5 | 1 | RGB16, 300 dpi |
| first-imported-2033 | 2033 | 4 | 5 | RGB16, 300 dpi |

The 100-patch target uses randomisation with seed 42. The imported target uses the TXF patch order and a new Argyll layout without randomisation. The previews of the first and last pages in the 2033 package have also been inspected visually.

The checked inner pixels of all patches match the RGB16 codes derived from TI2 exactly: **0 code levels of deviation**. This also includes Argyll's padding. The largest quantisation deviation of the generated target from the source values is 0.5 code level; the integer values of the TXF target on the 0–255 scale can be represented exactly in 16 bits (numerical residual error about 7.3 × 10⁻¹² code levels).

The run's `verification.json` and `manifest.json` in each package contain details and file checksums. `projects/` is intentionally excluded from Git; source code, tests and this report are in the Git project.

## Remaining practical tests

Physical printing and row measurement have not been performed. An experimental TXF candidate can now be created for packages that are exactly representable in 8 bits, but the recipient's physical layout has not been verified. The limitations are marked in the manifest and the print instructions. An older or original TXF must not be used to measure a new or relocated TIFF.

See the [run instructions](target-generation.md) for the API, package structure and next steps.


## Corrected measurement direction in 0.1.1

The project owner clarified that 321 mm including margins applies **along the measurement row**. The previous implementation had vertical Argyll strips; a check of the page width alone therefore did not meet the need. From 0.1.1 the native map is generated with reversed page axes. Patch and spacer pixels are transposed without resampling, row letters are drawn upright on the left and patch numbers at the top. Native files are archived separately in argyll/. The final TI2 has the same data table as the original and an updated PAPER_SIZE.

All ten tests pass after the change. The tests check that every strip lies horizontally, that patch numbers increase towards the right, that A lies above B, and that TIFF pixels and TI2 still agree. The limit test now uses 321 mm and rejects 322 mm.

Two corrected packages have been created and their previews reviewed:

- `projects/import-A3-horizontal`: the user's latest imported 2033-patch target, seed 42, A3 portrait, three pages, four padding patches, about 297.011 mm total width.
- `projects/target-256-A4-horizontal`: the existing 256 patches, seed 42, A4 landscape, one page, seventeen padding patches, same total width.

All checked inner patch pixels match the 16-bit codes of the TI2 exactly. This verifies file linkage and orientation, but not yet physical row measurement. The older packages have not been overwritten.


## Updated size limit in 0.1.2

The project owner's final dimensions are 320 mm horizontally × 300 mm vertically including margins. This replaces the previous 321 mm limit and adds a separate height limit. Paper format and printed target size are kept separate. A3 paper gives a target TIFF of about 297 × 300 mm, with unused paper area when printing at 100%.

All ten tests pass, including both maximum limits, larger selected paper and horizontal reading order. The package `projects/import-A3-320x300` has 2033 original patches and four padding patches on four pages. All TIFF pages are 3508 × 3543 pixels at 300 dpi, i.e. 297.0107 × 299.974 mm. Patch pixels and TI2 match exactly. The preview of the first page has been reviewed. Earlier packages remain as history and should not be used as examples of the new height limit.


## Coordinates in 0.1.3

Columns are labelled A, B, C from left to right and rows 1, 2, 3 from top to bottom. Row numbers continue across page boundaries. Argyll's index pattern was changed at the same time: SAMPLE_LOC is written row first, for example 12C, while the JSON also contains the readable coordinate C12.

All ten MATLAB tests pass. New packages are `projects/import-A3-ABC-123` (2033 patches, four pages) and `projects/target-256-A4-ABC-123` (256 patches, one page). Both use randomisation with seed 42. The previews have been reviewed visually: A starts on the left and row 1 at the top. TIFF16 and TI2 have been verified together. The size limit of 320 × 300 mm including margins remains. Physical row measurement remains to be verified.


## Size limit in 0.1.4

The maximum dimensions are changed to 320 × 280 mm including margins, replacing the previous height limit of 300 mm. All ten MATLAB tests pass. New verified packages: `projects/import-A3-320x280` (2033 patches, four pages) and `projects/target-256-A4-320x280` (256 patches, one page). Columns A, B, C from the left and rows 1, 2, 3 from the top remain. The preview of the first A3 page has been reviewed visually.


## General CGATS import/export

Four new CGATS tests pass, together with the ten tests of the targets suite after switching to the common parser. Real i1Profiler files for M0/M1/M2 were read, exported and read back with all 2040 × 36 spectral values unchanged. The patch definition with 2033 RGB values survives export and re-import without loss of values. Multiple tables, unknown metadata, repeated keywords and IDs, empty strings and Lab are included in the tests. Incorrect row counts, incomplete tables, duplicate wavelengths, contradictory spectral metadata and non-finite colour values are rejected by the respective structural/numerical check.

API: importCgats, exportCgats and cgatsData. See cgats-import-export.md. The export retains the source's dialect; conversion between CGATS.17 and CTI3 is not implemented. No physical measurement or import of the new exports into i1Profiler/ChromIQ has been verified.


## TXF prototype

A separate experimental exporter and a multi-page test have been added. Practical review in i1Profiler 3.8.5 confirmed import of integer RGB but rejected the corresponding decimal sample. A target exported from MATLAB could be opened with i1Pro 2; Custom Paper Size required PaperFormat=0. The grid was recalculated and did not match InkProf's layout. The function is therefore not approved for measurement. See i1profiler-txf-export.md for reproduction material and remaining work.

The single-page 575 export now writes TIFF16, TI2, source CGATS, physical layout CGATS, JSON manifest and a TXF candidate when the values can be represented exactly. Automatic checks show 575 source patches exactly once, five padding positions, 20 × 29 cells and identical TIFF/TI2 values. `chartread` reads the TI2 as 29 steps per row and 20 rows. This is structural verification; `physicalMeasurementVerified` remains `false`.

### Renewed i1Profiler test with dongle

2026-09-25: the measurement step and re-export work. Corrected percentage fields preserve 10 × 8 mm, but i1Profiler changes 21 × 29 to 24 × 26 (23 × 27 with a 30 mm right margin). The existing Argyll print is still not qualified for i1Profiler measurement. See `i1profiler-txf-export.md`. The instrument was reported as not connected.


### 2026-09-26: regressions for the 575 model

The model's reference files are now in `tests/fixtures/targets/chart-575/`, so the tests do not depend on the ignored local project folder. `testTiff16` tests RGB scale 255 and 100 with identical image pixels, `.tiff` and manifest checksums, 29 × 20 geometry, five padding fields, the 2A label, failed TXF export without published partial files, collision protection and the CompactA4 layout. Generated status fields are format-neutral. Physical measurement remains unverified.


### 2026-09-26: same template for multiple pages

The 575 limitation now applies only to the older reference-order mode. The general two-argument path in `createTiff16` renders any positive number of patches with 580 positions per page and continued row index. The five `testTiff16` cases of the test suite passed, including 2033 patches on four pages, 287 padding fields, four re-read TXF candidates, identical randomisation with the same seed and a small target with seven patches. TI2 uses a comma-separated `PASSES_IN_STRIPS2`, the same structure as existing Argyll files. Page count, RGB pixels and patch identities are checked on all pages. No physical row measurement has been performed.
