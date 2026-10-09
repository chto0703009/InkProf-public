# TXF export to i1Profiler: experimental implementation

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

## Verified PXF import, printing and measurement – 2026-10-03

Christer Törnkvist has carried out and approved a manual recipient test with a new PXF test file exported from InkProf with the current, minimal XML template and `RGBEncoding="round8"`. In i1Profiler the test name, patch count and colour cells were displayed as expected. The user's feedback was: "Everything looked as expected. Accept". Christer then confirmed: "Printing and measurement also worked". **PXF import, printing and physical measurement are user-verified for this test.**

This is a user-confirmed practical test of import, display, printing and measurement, in addition to InkProf's automatic reload tests. The exact i1Profiler version and patch count were not stated in the feedback; the version from older tests must not be assumed to apply to this test. Re-export and exact agreement with an earlier InkProf layout have not been reported. The approval applies to the print and measurement the user tried. `round8` allows rounding to 8-bit RGB; the test file does not qualify an already printed RGB16 target as measurement input.

Below follow the older TXF and layout tests with their original limitations.

Status 2026-09-25: export code exists, and `createTiff16` can place an experimental `*-candidate.txf` next to the single-page 575 TIFF when the RGB values are exactly representable. **The same print is not yet qualified for measurement in the recipient program.** Do not use the candidate file as finished measurement input until its imported grid and a practical measurement test have been verified.

Decimal CGATS can contain RGB16 values that the tested integer TXF variant cannot represent exactly. In that case no TXF candidate is created; the package's manifest explains the precision obstacle. No silent rounding is done.

## API

```matlab
paths = setupInkProf();
report = inkprof.exportTxfTarget( ...
    fullfile(paths.Projects,'import-A3-320x280'), ...
    fullfile(paths.Projects,'txf-kompatibilitetsprov'), ...
    Experimental=true);
```

The function verifies the existing print package and writes to a new, separate directory. It changes neither TIFF, TI2 nor the package's manifest. Without `Experimental=true` the run is aborted.

A reference TXF is needed for X-Rite's private Prism structure. The default is `source/original.txf` in the source package; otherwise specify `Template='sokvag/till/referens.txf'`. Only the observed cc/xrp serialisation is supported. The reference's other private metadata and profile settings are preserved as template content; they imply no verified profile recommendation. The template is identified by SHA256 in the report.

Each print page gets its own `page_NN.txf`, because the last page's row count may differ. All patches actually printed, including Argyll's padding, are included in order from top to bottom, left to right. A separate JSON map saves the original SAMPLE_ID, coordinate, page, row, column, rectangle and RGB16. TXF IDs are local to each page and must not be used alone to join the pages' measurements.

## Precision

For the tested Prism variant RGB must be integers 0–255. The export therefore allows only RGB16 codes that are exactly divisible by 257. Values are not silently rounded. `inkprof:TXFPrecision` means that the existing print cannot be described exactly with the tested variant.

- Existing imported 2033 target: all patches, including padding, are exactly representable.
- Existing generated 256 target: 242 patches have at least one channel that is not exactly representable. The export is aborted.

That the TIFF is 16-bit does not contradict this: a TIFF16 can contain either 8-bit-representable or finer RGB control values. If a future i1Profiler workflow quantises control values, this must happen before generating a new coherent TIFF/TI2/TXF package and imply a new print.

## Practical review

In i1Profiler 3.8.5 the user's unchanged PXF was opened. A sample that kept the reference file's structure and used 273 integer RGB objects was also opened; the program showed 273 patches and the correct sample name. The same structure with RGB decimals was rejected with "Cannot load patch set file". Compact initial XML samples were also rejected; it is not established which additional detail in the compact structure triggered the error.

The program showed DEMO. Test Chart attempts changed the file name but kept the old geometry; this does not count as a successful layout import. The measurement step was inactive. The user has been asked to reconnect the licence dongle. The original PXF could be opened even in demo mode, so not all import errors may be attributed to the licence.

## Remaining verification

- Open the final MATLAB export in Test Chart and check that the page's grid and RGB are actually used.
- Check object order against the page's physical placement and how i1Profiler names rows/columns.
- Determine how Argyll's coloured gaps should be handled. The observed TXF attributes do not describe arbitrary separators between patches. The patches' nominal dimensions are not sufficient proof of the same physical map.
- Verify edge fields, margins, last page and padding. The program must not regenerate the order.
- Carry out a practical row-measurement test with i1Pro 2. Import and file checks are not such a test.

If Argyll's layout cannot be expressed in i1Profiler, a jointly supported layout and a new print are required. InkProf should then clearly distinguish this route from exporting measurement input for an already printed sheet.

## Final import test and remaining layout error

The first page from the MATLAB export of the 2033 target was opened in Test Chart and identified as i1Pro 2 with 609 patches. The reference template's PaperFormat=16 made the program use Letter and two pages despite specified page dimensions. With PaperFormat=0, Custom Paper Size of about 297 × 279.9 mm and one page were displayed. The exporter therefore now uses 0.

**i1Profiler nevertheless recalculated the grid. The preview did not match InkProf's 21 columns × 29 rows.** Specified NumberPatchColumns/Rows are thus not enough to lock the physical map. The files must not be used to measure the existing prints. It remains to determine i1Profiler's layout rules and separator handling, or to create a new joint target. Import is confirmed for this manually adjusted sample, but the exporter still sets no general compatibility flags to true.

The code test for multi-page, reading order, padding, RGB16 re-read, requirement for the experiment flag, precision and overwrite protection passes. No physical row measurement has been performed.

## New test with the dongle connected, 2026-09-25

The dongle made it possible to proceed to the measurement step and to save out both TIFF and TXF. The program, however, reported `i1Pro 2 not found`; no physical measurement was performed.

Re-export from i1Profiler 3.8.5 gave the following for the first page's 609 objects:

| Sample | Patch dimensions after re-export | Columns × rows |
|---|---|---|
| Custom paper, template's percentage values | 8.89 × 8.67 mm | 27 × 23 |
| Corrected percentage values | 10 × 8 mm | 24 × 26 |
| Same, with 30 mm right margin | 10 × 8 mm | 23 × 27 |
| InkProf's existing TIFF/TI2 | 10 × 8 mm | 21 × 29 |

609 RGB objects retained their values and list order in all three re-export samples. This does not prove that their physical positions are preserved: i1Profiler recalculates the grid. The margin test did not solve the problem.

For 10 × 8 mm in i1Pro 2 mode, `PatchSizeWidthPercent=16.666666666666668` and `PatchSizeHeightPercent=0` are also required. The exporter now writes these values and limits the experimental route to the verified patch dimensions. Nominal millimetre values alone are not sufficient. The template's percentage values referred to a different instrument.

The Argyll target's 1 mm coloured separators between the patches are still not represented. One possible continued investigation is a new joint target without separators (`printtarg -n`), with control values quantised before printing if i1Profiler requires it. This is an untested route and would require a new TIFF/TI2/TXF and a new print.

The temporary local tests in `work/` have been cleaned up. The machine-readable test summary and the documented conclusion remain in version-controlled documentation. The import obstacle from demo mode has been removed; the remaining limitation is layout compatibility and practical instrument verification. The export remains experimental.

After the correction the MATLAB test `testTxfExport` passed again. A machine-readable test summary with file hashes is in `docs/research/i1profiler-interchange/licensed-txf-roundtrip-2026-09-25.json`.

## New check of the page template 2026-09-26

The column order of the `createTiff16` candidates has been corrected after import and image re-export. Four pages match in RGB, patch size and grid; however, the recipient's colour fields lie 0.75 mm to the right. Physical measurement remains. See [full verification](../research/i1profiler-interchange/txf-template-verification-2026-09-26.md). Older candidates need to be regenerated.
