# TIFF16 dialog for patch definitions

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Open in MATLAB after `paths=setupInkProf()`:

```matlab
window=inkprof.renderTarget();
% Or with a preselected file:
window=inkprof.renderTarget(fullfile(paths.Projects,'chart.pxf'));
```

The dialog is in English. Choose an input file with **Browse…**. The supported RGB variants of TI1, TI2, PXF, TXF, CGATS/TXT and CxF are handled by the existing importer. For generic CGATS/CxF, choose the RGB scale explicitly when the format requires it. CMYK is rejected.

**A4 landscape** (297 × 210 mm) and 300 dpi are the defaults. Choose another standard format, or change width and length for **Custom**. Dimension limits come from Project details → Target paper; 320 × 370 mm are editable starting values. The length is decided by the user, without the earlier 280 mm limit; the image sizes actually possible depend on available memory and the renderer. DPI can be 72–1200.

The input file's base name plus `-TIFF16` is suggested as the **Output package name**. **Generate and save…** opens a dialog where the name and parent folder can be changed. The name is that of a new package folder; inside it the standard names `target*.tif`, `target.ti1`, `target.ti2` and the JSON files are kept. Existing packages are not overwritten. Generation is synchronous; wait for it to finish before closing the window. When a calculation or render takes longer than about 2 seconds, an elapsed-time clock (**Working — elapsed N min SS sec**) with a **Cancel** button is shown and updated every second.

After generation the dialog closes and a small PNG of page 1 is shown in the results window. PNG files are also saved in the package, but they are previews only. The print files are RGB TIFF with 16 bits per channel, without an embedded ICC profile. Make sure the printing application does not assign a working space to them: for example, Photoshop can be set to assign Adobe RGB (1998) to untagged files, which changes the printed colours. C2 verification targets carry the printer ICC as a tag for this reason. Coloured contrast markers are used.

The patch definitions get a new layout. Even an imported TI2 gets new measurement files that belong to exactly the new TIFF pages, and the original is kept as the source. The new layout does not change the RGB definitions beyond the TIFF16 quantization.

## JSON and traceability

`target.json` and `manifest.json` have the same `printSettings`: package name, full output folder, input file path, DPI, page width and length in mm, margin, contrast markers, randomization settings, 16-bit format and the absence of an embedded ICC profile. The source's name, hash and mesh information stay in `targetInfo`.

`manifest.json` also contains the actually rendered page size (rounded down to whole pixels), the full generation options and the files' checksums. `layout.json` gives the patches' identities, RGB values, pages and positions. `target.ti2` matches the print for later measurement. The footer shows the final TIFF path.

## Cancel, save and page count

**Cancel** closes the window without saving. During computation or rendering, the button requests cancellation at the next safe checkpoint; an ongoing external Argyll call must return first. Temporary print files are cleaned up, and no new package is published on cancellation. **Stop generation** in the mesh window, in contrast, only stops the refinement and leaves the window open.

After a successful save, the generation window closes automatically. A separate results window shows **Saved TIFF16 target — N pages**, a PNG of page 1 and the package path. On a save error, the generation window stays open. The page count is also saved in the package's JSON (`manifest.pageCount` and `printSettings.pageCount`), and, for mesh-generated targets, in the design's `print.pageCount`. The TIFF footer's `1 (N)` marking is kept.

## Page count before saving, and the scale of the RGB numbers

Click **Calculate / preview** after choosing the file and page settings. **Pages: N** and a PNG of page 1 are shown directly in the TIFF16 window, before any final package is saved. The computation uses the same renderer, DPI and layout as the export; it is not a rough estimate. Temporary files are removed after the computation. The footer's temporary path is replaced with the final path when saving. Changed settings clear the old page count and preview; click again for a current computation.

**RGB: automatic** refers to the number range in the input file. For known formats, the importer decides it automatically: TI1/TI2 normally use 0–100 and the supported PXF/TXF variants 0–255. For generic formats that require an explicit scale, choose the file's documented number range: 0–1, 0–100 or 0–255. This is neither a colour profile, a colour space nor a TIFF bit-depth setting. The output is always RGB with 16 bits per channel.

## Window focus and page browsing

The TIFF16 dialog uses `WindowStyle="alwaysontop"` and `focus` to stay in front of MATLAB; `modal` is not enough, because it does not block MATLAB's main window. During file selection the normal window mode is used temporarily, and the always-on-top mode is restored when the file chooser closes.

After **Calculate / preview**, all pages can be reviewed with **◀ Previous** and **Next ▶** under the image. **Page X of N** shows the current page. The arrows are disabled at the first and last page, and when the settings change. The small PNG images are kept in memory, so that temporary rendering files can still be removed.

The results window after saving has the same page browsing and also opens in front of MATLAB. The page order follows the page numbers, also for targets with ten or more pages.

The window behaviour follows the [MathWorks documentation for uifigure](https://www.mathworks.com/help/matlab/ref/uifigure.html).

## Separate step after mesh generation

The mesh window saves only the TI1 and the design JSON, with `saveRGBDefinition`. Open the TI1 here when a print is to be created. Keep the JSON next to the TI1 for hash-verified mesh information. **Randomize positions** and its seed are now here, together with page size and DPI. Both preview and saving use the same choices. A new print folder is created; the saved mesh definition is not changed.

## ICC conversion and the embedded tag

Read `PRINTING.txt` beside the TIFF (or `*-README.txt` for the legacy exporter). It now states **ICC conversion**, **Embedded ICC**, the printer-profile name and SHA-256 when tagged, and the heading **PRINT THIS TARGET WITHOUT FURTHER COLOUR CONVERSION** (print with colour management disabled). The same information is saved in modern target `printSettings.iccHandling`.

Base and refinement targets render device RGB directly; InkProf applies no printer ICC conversion. Ordinary C2 colour-reference targets have already been converted once, absolute colorimetric without BPC. C2 device-RGB reference sets are an exception: their RGB is rendered directly and the ICC only predicts reference Lab. Both kinds of C2 TIFF carry the printer ICC as an identifying tag. Embedding changes no pixels; an application may nevertheless use the tag if colour management is enabled. Preserve the tag without conversion, do not assign another profile, and disable application, OS and driver colour conversion. An untagged TIFF does not establish its prior history; the embedded tag likewise does not prove absence of earlier conversions.

Newly generated packages include these instructions; existing print packages are preserved. Read the C2 package-level `PRINTING.txt` as well as `print/PRINTING.txt`.
