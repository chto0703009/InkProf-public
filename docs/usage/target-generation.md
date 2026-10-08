# Creating a target with InkProf 0.1.4

> InkProf 1.0.0-rc.2, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

## Warning: external prints without contrast markers

**Targets printed without contrast markers between the patches can cause problems in row measurement with chartread**, particularly when adjacent patches have similar colours. This can, for example, produce errors if too few or too many patches are detected. A correctly imported patch definition does not guarantee that the existing sheet can be read reliably.

**Recommended workflow:** import the patch definitions as TI1/TI2 in the first instance, or as generic CGATS from another program, and let InkProf generate a new TIFF16 print with contrast markers and matching TI2/JSON. Then use the TI2 of that new print package for the measurement. Contrast markers reduce the risk of segmentation problems but do not guarantee error-free sweeps.

An import or reordering in the program does not change a sheet that has already been printed. If the existing sheet is measured in another program, its measurement file can be imported separately with the patch linkage preserved.


The first implementation is a MATLAB API with two export paths. `createTarget` creates general Argyll packages with TIFF16, TI1, TI2, geometry description and JSON. `createTiff16` uses a multi-page layout template with 580 positions per page, with TIFF16, TI2, two CGATS tables, JSON checks and a conditional TXF candidate. Neither function yet controls a measurement instrument or creates ICC profiles.

## Choice of import format

**TI1/TI2 is the first choice. For RGB patch definitions from other programs, generic CGATS is recommended when TI1/TI2 is missing.** CxF/PXF/TXF remain as supplementary alternatives. Specify the RGB scale for CGATS and check whether the file actually contains print positions. See [format priority and limitations](cgats-import-export.md#recommended-import-formats-for-rgb-patch-definitions).

## Getting started

Run from the InkProf folder in MATLAB:

```matlab
paths=setupInkProf();
folder=fullfile(paths.Projects,'mitt-target');
inkprof.createTarget(folder, ...
    PatchCount=100, Randomize=true, Seed=42, DPI=300);
inkprof.previewTarget(folder);
```

Requires MATLAB Base with Java and ArgyllCMS `targen`/`printtarg`. Tested with MATLAB R2025b Update 7 and ArgyllCMS 3.5.0 on macOS. Python, Image Processing Toolbox, SpectraLab and Camera-41 are not needed for the target part. Measurement and future colour calculations shall also be independent of SpectraLab and Camera-41; interactive measurement uses InkProf's own Python bridge to Argyll. No ChromIQ code is used.

`setupInkProf` finds source code and project folders from its own location. The code can therefore be moved or cloned to another directory. The function adds `src` for the current MATLAB session without changing the global saved MATLAB path. `examples/first_target.m` also finds the repo from the script's own location and can be run from another current directory.

Argyll is found in this order: the named argument `ArgyllBin`, local configuration, the environment variable `ARGYLL_BIN`, common Homebrew directories (macOS/Linux), then the computer's `PATH`. Otherwise specify the actual bin directory:

```matlab
paths=setupInkProf(ArgyllBin='/usr/local/bin');
inkprof.createTarget(fullfile(paths.Projects,'annat-target'), PatchCount=200);
```

The computer-specific tool path is saved in `local-config/settings.json`, which is Git-ignored. No user-specific path exists in the MATLAB code. On a new computer, run setup with that computer's Argyll directory, for example `setupInkProf(ArgyllBin="C:\Tools\Argyll\bin")`. Windows `.exe` files and paths are supported by the setup, but the integration tests have so far only been run on macOS. `SaveLocalConfig=false` performs the setup without writing a configuration file; in that case specify `ArgyllBin=paths.ArgyllBin` on export if the directory cannot already be found. `inkprof.paths()` shows the current folders.

Code and data are moved separately: the Git project contains the code; `projects/` contains local print packages and must be copied or backed up separately. Each such package has relative internal file references and its own source data. Version and origin paths in the manifest are provenance, not a requirement that the old computer or location still exists.

## Importing PXF, TXF and CGATS definitions

```matlab
inkprof.createTarget('projects/gammal-patchlista-ny-karta', ...
    Source='tests/fixtures/i1profiler/chart-2033/Chart 2033 Patches.txf', ...
    Randomize=false, DPI=300);
```

PXF and TXF are read as RGB patch lists in the reviewed CxF3/Prism variant with `ObjectType="Target"` and `ColorSpecification="Unknown"`. The RGB scale is 255 for this variant. Other XML colour specifications are rejected until they have a verified adapter. Layout attributes are archived, but **the old TXF chart is not reproduced**. The print gets a new Argyll layout.

For the observed i1Profiler layout with 575 patches on one landscape A4 page, the compact Argyll layout can be chosen explicitly:

```matlab
inkprof.createTarget('projects/chart-575-A4', ...
    Source='Chart 575 Patches.pxf', CompactA4=true, ...
    Randomize=false, DPI=300);
```

The option uses long-strip mode, no outer margin and a compact i1Pro scale. For 575 patches this gives 20 rows and 29 columns on one TIFF. It is still a new Argyll layout; physical compatibility with i1Profiler's chart has not been verified.

## Reusable page template for any patch count

The 575 target is the model for the formatting, not a limit on the number of patches. `createTiff16` uses the same template for PXF, TXF, TI1 and RGB CGATS:

```matlab
paths=setupInkProf();
info=inkprof.createTiff16( ...
    fullfile(paths.Projects,'mitt-target.ti1'), ...
    fullfile(paths.Projects,'utskrift.tif'), ...
    DPI=300,Randomize=true,Seed=42);
```

The template has 29 columns × 20 rows with 8 × 8 mm patches, guide lines, columns A–Z and 2A–2C, and a 263 × 195 mm image area. The header is **InkProf Quality Profiling RGB printer**, centred in 20 points. Date and time are at the bottom left and the page number, for example `1 (4)`, at the bottom right. Row numbers continue across page boundaries: 1–20, 21–40, and so on.

- 575 patches → one page, five padding fields.
- 2033 patches → four pages, 287 padding fields on the last page.
- Other counts → as many full template pages as needed. At most 49 pages with the current TI2 row index.

The default is source order. `Randomize=true` uses a local random stream with a saved `Seed`; the same final order is used in all formats. Padding is grey, marked `isPadding` and is not a source patch. The general path fills in row order and places the padding last. No reference image is required.

The first TIFF file uses the chosen name, for example `utskrift.tif`; the following ones are named `utskrift_02.tif` and so on. A common `utskrift.ti2` describes all pages. JSON and physical CGATS specify page, row and patch linkage. The manifest lists all TIFF files and checksums. `info.tiffs` gives the full file paths.

CGATS requires an explicit `RGBScale`. Both `.tif` and `.tiff` are supported. TIFF16 values are checked against TI2 on all pages. If a compatible XML template exists, an experimental TXF candidate can be written per page, but the recipient layout and physical measurement remain to be verified. MXF is created only after measurement.

The older call with three positional arguments `(source, reference, output)` remains in order to exactly recreate the original 575 target's colour order and five spread-out padding squares. That mode requires 575 patches and does not allow randomisation. For new targets, use the two-positional-argument call above.


TI1 can be imported in the same way. RGB CGATS TXT requires an explicit scale:

```matlab
target=inkprof.importTarget('Chart 2033 Patches.txt', RGBScale=255);
inkprof.createTarget('projects/precisionsvariant', ...
    Source='Chart 2033 Patches.txt', RGBScale=255);
```

The reader supports a single-table CGATS file (for TI1, the first table; multi-table CGATS TXT is rejected) with SAMPLE_ID and RGB_R/G/B and optional SAMPLE_NAME. TI1 has scale 100. The scale is never derived from the observed maximum value. Duplicate RGB values are kept; duplicate or empty IDs are rejected. External XML entities/DTD are not allowed.

## Options

Current dimension limits and changeable proposals are taken from the project's JSON. See [paper proposals and measurement slide](target-paper-planning.md). The older fixed limits of 320 × 280 mm do not apply to new packages.

```matlab
paths=setupInkProf();
inkprof.createTarget(fullfile(paths.Projects,'target-256-A4L'), ...
    PatchCount=256, Paper="A4-landscape", Randomize=true, Seed=42, DPI=300);
inkprof.createTarget(fullfile(paths.Projects,'target-256-A3P'), ...
    PatchCount=256, Paper="A3-portrait", Randomize=true, Seed=42, DPI=300);
```

Specify either `Paper` or your own `PaperSizeMm`, not both. Without a format choice, portrait A4 is used as before. The same already generated patch list can get a new layout through `Source` with its TI1 file.

| Argument | Default | Meaning |
|---|---|---|
| PatchCount | 100 | `targen -f`, requested total count at generation; the actual count is recorded |
| GraySteps | 9 | `targen -g`, equal RGB control values along the grey axis, no guarantee of a neutral print colour |
| WhitePatches / BlackPatches | 4 / 4 | Repeats at generation |
| Paper | A4-portrait | A4-landscape or A3-portrait are the two wider choices |
| PaperSizeMm | Optional | Own [width height] in mm, alternative to Paper |
| MarginMm | 10 | `printtarg -M`, margin included in the TIFF |
| DPI | 300 | 72–1200, TIFF16 per RGB channel |
| PatchScale / SpacerScale | 1 / 1 | Argyll's `-a` and `-A`, instrument-dependent scaling |
| CompactA4 | false | Compact single-page 20 × 29 layout for 575 patches on landscape A4; sets paper, margin and scaling |
| Randomize | false | `false` preserves the patch list's order in the new layout; `true` uses printtarg |
| Seed | 1 | `printtarg -R` when randomisation is selected |
| TimeoutSeconds | 120 | Time limit per process |

The first supported geometry is Argyll's **`-ii1`**, the i1Pro family's rectangular row layout. The program does not yet allow other instrument geometries. An existing Scramble flag in a TXF does not activate automatic reshuffling. Choose `Randomize=true` explicitly for a new randomised chart.

## The general `createTarget` package

- `source/`: unchanged import original or generated TI1.
- `target.ti1`: numeric SAMPLE_ID 1…N, with linkage to the original ID in the JSON. Argyll's extra helper tables are created by `targen`.
- `target.ti2`: actual layout and quantised RGB values from the same printtarg run as the images.
- `target*.tif`: print pages, RGB uint16. The images have physical resolution; automatic rescaling should be turned off when printing.
- `argyll/`: unchanged TI1/TI2/TIFF/CHT intermediate files from Argyll. These have the original vertical orientation and shall not be printed. InkProf uses the geometry to check the final horizontal chart.
- `target.json`: original ID, name, source values, scale, percentage values, estimated XYZ and imported layout attributes.
- `layout.json`: each TI2 position with original ID, page, strip, patch number in strip, rectangle in mm and RGB16. ID 0 is Argyll's padding, not an original patch.
- `manifest.json`: schema version, settings, tool versions, arguments, checksums and compatibility status.
- `verification.json`: verification results.
- `target*-preview.png`: smaller on-screen previews, not print data.
- `PRINTING.txt`: printing instructions and limitations.

JSON is an intermediate format. TI1 and TI2 are the primary Argyll data. TIFF16 does not restore precision that is missing in an imported integer RGB target. For a new TI1 without its own XYZ, clearly labelled sRGB/D65 estimates are used solely for layout/recognition heuristics; no RGB control values are colour-converted. The estimates do not describe the actual printer.

## Checks and reproducibility

```matlab
report=inkprof.verifyPackage('projects/mitt-target');
```

Each source patch must appear exactly once in the TI2/CHT linkage, even when colour values are repeated. All pixels in the central half of each rectangular patch are checked against TI2's RGB16 code, including padding. Source values may deviate by at most half a 16-bit quantisation level (with a small numerical tolerance). Page dimensions, bit depth and file checksums are checked. CHT squares and TI2 positions must match unambiguously.

The package is first written to a temporary neighbouring folder and moved to the chosen name after the checks pass. Existing packages are not overwritten. All necessary target data is in the package; it can be moved. The original external path is saved only as provenance and is not needed for verification. The manifest is an integrity check, not a digital signature.

Random seed and version are preserved together with the actual patch mapping. For exact reuse, finished packages should be archived: the same generation settings alone do not promise identical files across tool versions or timestamps.

## Remaining before measurement compatibility is complete

In the general `createTarget` package, TI2 and native TIFF/CHT come from the same Argyll run. The final TIFF image uses transposed patch/spacer pixels without resampling, and upright column letters and row numbers are drawn in the white area. Patch ID, SAMPLE_LOC, strip membership, RGB and reading order are unchanged; TI2's PAPER_SIZE is updated to the final orientation. Native CHT refers only to the native images in `argyll/`, not to the final TIFF files. InkProf verifies the transformed positions against the final TIFF. Physical printing and row measurement with `chartread` remain to be done.

The single-page 575 package from `createTiff16` instead uses its documented reference geometry and writes matching TI2/CGATS/JSON directly. A `*-candidate.txf` can be created there without loss of precision, but the candidate's recipient layout and physical measurement are not verified. An older or original TXF must never be used to measure a new layout.

The app now has measurement, supported TI3/MXF import, spectral calculations, ICC generation, verification and iteration. Format support is limited to documented variants; general CMXF support is not promised. `previewTarget` already provides a simple page overview in MATLAB.

## Tests

```matlab
results=runtests('tests/testTargets.m');
assertSuccess(results);
```

Tests use the real 2033 patch files, a generated target, repeated colours, fractional control values, multiple pages, randomisation, a relocated package, faulty files and changed checksums. Argyll must be available also for the integration tests.

Argyll's external tools and their generated helper tables are used; no Argyll binary is distributed in InkProf.

## Measurement direction and coordinates from 0.1.1

Earlier packages from 0.1.0 had vertical strips and must be regenerated for this workflow; rotating an on-screen preview is not a correction of the print package. Print only target*.tif in the package root. Native intermediate images in argyll/ shall not be printed.

### Coordinate contract from 0.1.3

Argyll is given numeric strip indices (`-x0-9,@-9,@-9;1-999`) and alphabetic patch indices (`-yA-Z, A-Z`). TI2 retains Argyll's `INDEX_ORDER STRIP_THEN_PATCH`, so for example row 12, column C is written `12C` in SAMPLE_LOC. In layout.json the same raw `location` is present, along with `column="C"`, `strip="12"` and the user coordinate `coordinate="C12"`. The difference in writing order is explicit; it is the same patch and the same physical reading order. No stand-alone renumbering is done after randomisation.


## Experimental TXF compatibility

`createTiff16` can create `*-candidate.txf` for the single-page 575 layout when all RGB16 values are exactly representable in the tested TXF variant. `exportTxfTarget` exists for separate experiments with general Argyll packages. Neither path is qualified for measuring an existing print until the recipient's actual grid and a physical measurement test have been verified. See [TXF status](i1profiler-txf-export.md) and [the first delivery's acceptance requirements](target-print-standard.md).


## Update 2026-09-26: fixed 575 model and neutral names

The 575 model retains the reference's 29 × 20 positions, five padding fields, 8 × 8 mm patches, guide lines and 263 × 195 mm image area. The columns are A–Z, 2A–2C and the rows 1–20. The image header identifies InkProf, 575 patches and date. The source file's name and identity are in the manifest. (Note 2026-10-08: the current header is **InkProf Quality Profiling RGB printer**; date/time, page number, full TIFF path and the target summary with patch count are in the footer. See [print standard](target-print-standard.md#header-and-footer).)

`createTiff16` now normalises the RGB scale during reference matching and accepts both `.tif` and `.tiff`. The package is built and verified in a temporary neighbouring folder. Only after the checks pass are the files published; existing files are not overwritten. On an ordinary publishing error, files published by the same call are rolled back. This is not a guarantee of atomic publishing in the event of a power failure or process crash.

Public status fields are now called `receiverLayoutVerified` and `receiverImportVerified`. Older saved reports retain their earlier field names. Import/export of standard formats is retained; historical references and the formats' technical identifiers are not changed.

Machine-specific configuration shall be set on each computer with `setupInkProf(ArgyllBin="...")`. This computer uses `/usr/local/bin`. `local-config` shall not be transferred from a computer with a different installation.

## RGB delimitation

Target import and TIFF16 printing are limited to RGB. The header **InkProf Quality Profiling RGB printer** is drawn on every page in both the page template and the general Argyll path. The change applies to newly generated packages; existing print files are not changed. CMYK targets are not included.

CMYK in target definitions is rejected with `inkprof:ColorFormat` and the message "Fel färgformat: InkProf stöder endast RGB-target." (Wrong colour format: InkProf supports only RGB targets.) The check applies to XML-based targets and CGATS/TI1. The general CGATS reader can still preserve CMYK measurement data as exchange data; this does not give support for CMYK targets or CMYK printing.

## RGB data for later measurement with i1Pro 2

Export of target and measurement data checks three RGB channels and the correct numerical scale before writing. Four-channel data is rejected with `inkprof:ColorFormat`; no CMYK→RGB conversion is done.

- **TI2:** common patch definition for Argyll `chartread`, with the same RGB, order and page division as the TIFF16. After the measurement, TI3 is obtained. Physical measurement of the template remains to be tried.
- **TXF:** experimental candidate per page for the recipient program's Test Chart import. The page template's candidate now specifies i1Pro 2 and the percentage parameters for 8 × 8 mm; this still needs to be verified in the recipient and with an instrument. Importable XML is not a guarantee of an identical physical layout.
- **CGATS:** source table and physical patch table for data exchange, including page/row/padding. Generic CGATS is not automatically a ready-made instrument control format or a replacement for TXF/TI2.

The general document function `exportCgats` still preserves imported CGATS documents, including those containing CMYK measurement data. The RGB restriction applies when it exports an InkProf target and when the print's measurement data is created. This preserves the possibility of lossless data exchange without allowing CMYK targets in the printing workflow.

## Contrast fields in the Argyll layout

`createTarget(...,SpacerMode="colored")` passes `printtarg -c`. Other values are `auto` (default), `bw` (-b) and `none` (-n). `SpacerScale` controls -A. A changed layout requires a new print and a matching TI2. The contrast test `projects/test-575-kontrast-rad13-17` uses problem colours from the earlier 575 print; it is a separate target with new row numbers.

## Print standard

See [InkProf – target print standard](target-print-standard.md) for the header, date/time, page number, row and column labels, physical dimensions and measurement data. That document gathers the common standard for both printing routines.

## New print from TI2

`createTarget(folder,Source="original.ti2",Paper="A4-landscape",SpacerMode="colored")` imports the RGB patches from a validated CTI2. The RGB scale is 0–100. SAMPLE_ID 0 is padding and is not carried over as a source patch. Other identities, RGB and any estimated XYZ are kept; XYZ in TI2 is not measured values. Original positions, metadata and helper tables are preserved in `target.json` under `sourceLayout`, and the original file is archived under `source/`.

A new layout is created for the print with new positions and, if needed, new padding. Use the package's new `target.ti2` when measuring the new print. To measure an already printed original, use `prepareChart` with the original's TI2 instead, without re-layout.
