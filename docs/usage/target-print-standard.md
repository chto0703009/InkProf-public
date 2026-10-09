# InkProf – target print standard

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

## Warning: external prints without contrast markers

**Targets printed without contrast markers between the patches can cause problems in row measurement with chartread**, particularly when adjacent patches have similar colours. This can, for example, produce errors if too few or too many patches are detected. A correctly imported patch definition does not guarantee that the existing sheet can be read reliably.

**Recommended workflow:** import the patch definitions as TI1/TI2 in the first instance, or as generic CGATS from another program, and let InkProf generate a new TIFF16 print with contrast markers and matching TI2/JSON. Then use the TI2 of that new print package for the measurement. Contrast markers reduce the risk of segmentation problems but do not guarantee error-free sweeps.

An import or reordering in the program does not change a sheet that has already been printed. If the existing sheet is measured in another program, its measurement file can be imported separately with the patch linkage preserved.


Established: 2026-09-26. Applies to new targets from both the general Argyll layout and InkProf's reusable page template. Existing packages are not changed retroactively.

## Patch definitions, own prints and external measurements

InkProf controls the layout standard for its own prints. An import must preserve the file's patch definition, original layout and measurement linkage. Only when the user creates a new print from, for example, an RGB PXF is a separate InkProf layout created, with matching JSON and measurement data. The original's layout and earlier measurements must not be overwritten or reinterpreted.

**Contrast markers shall be the default for new targets intended for row measurement**, also when measured later in i1Profiler. They are part of the layout and the compatible measurement data but are not counted as source patches or profile data. The recipient's support for the layout must be verified.

Data that has already been measured, for example a supported MXF, shall be importable and analysable regardless of which program created the print and whether contrast markers were used. Patch linkage, RGB values, spectra, units and measurement conditions shall be checked and preserved.

An external target that has already been printed without contrast markers can be more sensitive to row measurement with chartread. In that case, measure in the originating program if needed and import the result, or create a new InkProf print from the patch definition. A new TI2 cannot add contrast markers to an existing sheet.

See [specification and implementation status: patch definition, layout and measurement results](../decisions/008-target-layout-measurement-separation.md).

All formats in the project's format specification shall be handled according to their content, even if their targets do not follow this print standard. Available information about how the sheet looked at the time of measurement shall be preserved. Missing information and format variants not yet supported shall be reported explicitly.

TIFF import and the instrument's reading of a print are separate steps. Neighbouring patches that are very similar can make physical row measurement more difficult. Scrambling can reduce the problem but does not guarantee neighbour contrast; it requires a new print with exactly the same permutation in the JSON and measurement data. Contrast markers are retained. A TIFF on its own must not be assumed to contain all patch identity or measurement metadata.

## Header and footer

| Part | Text and placement |
|---|---|
| Header | **InkProf Quality Profiling RGB printer**, centred at the top, **20 points**. |
| Date and time | Bottom left, `YYYY-MM-DD HH:mm`. Refers to the generation of the file, in the computer's local time. The same time on all pages in the package. |
| Target information | Centred above the file path: source file name, method when known, patch count and a short geometric grid summary from the JSON field `targetInfo`. |
| Target file | Centred at the very bottom: full path and TIFF file name including extension for the current page. |
| Page number | Bottom right, `1 (3)`, `2 (3)`, `3 (3)`: current page followed by the total number of pages in parentheses. A single page is labelled `1 (1)`. |

The complete final path is shown, including the TIFF file name, never the name of the temporary build folder. The text is centred and wrapped to two lines if necessary, normally at 9 points and at least 6 points. If the complete path does not fit, generation is aborted with a clear message, without truncation. If the file is moved after generation, the original path is retained in the image.

The current rendering places the header text box centred about 9 mm from the top edge. From 2026-09-28, the footer of full-page targets is centred 12 mm from the bottom edge, with an 8 mm side margin. This gives at least about 8 mm of white space below even a two-line path. The earlier 3.5 mm gave clipped date text on the user's print. The printer's actual printable area still needs to be checked. The footer uses 9 points. The point size is recalculated according to the TIFF file's resolution. The header and footer shall lie in the white margin without overlapping patches or other markings.

## Rows, columns and measurement path

- Column letters are placed **above the patches**, from left to right.
- Rows are numbered from top to bottom. The reusable 29 × 20 template continues the row numbering between pages: 1–20, 21–40 and so on.
- Row numbers are placed on the left, near the top edge of the row. The nominal text height of the row numbers is 2 mm (previously 1.2 mm). The numbers are mid-grey (RGB16: 32768, 32768, 32768) for better legibility. In the Argyll layout they are normally placed 8 mm from the left page edge, closer to the edge if the margin requires it. The fixed 29 × 20 template retains its placement 1.25 mm from the edge. The numbers are placed near the top edge of the row to keep the central measurement path free of text. Legibility needs to be assessed on a print.
- The instrument is moved along the middle of the row, starting and ending on white paper outside the patch area.
- Row boundaries are marked with clear, solid grey guide lines on **both sides** of the patch field, in both rendering paths. The lines mark the upper and lower edge of the row, not the centre line of the sweep. Standard: 0.4 mm thickness, up to 6 mm length, RGB grey at 35 % of full white. At least 6 mm is left white between the line and the patch/contrast field. With narrow margins the lines are shortened symmetrically; if not even 1 mm fits, a clear layout error is raised. Dimensions and positions are saved in `page-placement.json` and in the template's layout JSON, respectively. Older prints and target packages are not changed.
- The suspicion that text or markings contributed to earlier misreads is not proven. A layout check does not replace physical measurement verification.

The template shows columns after Z as 2A, 2B and 2C; Argyll's TI2 may designate the corresponding columns AA, AB and AC. The mapping shall be preserved in the layout description.

## Centring on the page

The target area shall be centred horizontally and vertically in the available area between the header/column labels and the footer. The centring includes the patches and their contrast fields. The shift is made in whole pixels without rescaling; the position description in the JSON is updated at the same time. The Argyll rendering reserves 20 mm at the top and 22 mm at the bottom, or 30 mm at the bottom for targets narrower than 240 mm (including A5 in both orientations). Argyll's page capacity is reduced correspondingly; patches are not scaled. The footer dimensions are saved in the target JSON under `printSettings`. TI2 retains patch identity, row order and RGB values; the absolute page placement is stored in the layout JSON and `page-placement.json`. Older packages without a placement file retain their original coordinates.

In the i1Pro 2 test on 2026-09-26, the overrun on the first row was, according to the user, caused by the sheet sitting too far to the right in the slide. After the placement was corrected, all seven rows were accepted. Centring shall leave room for starting and ending on paper; the overrun shall not be attributed to patch recognition.

The older cropped 263 × 195 mm image retains a 3.5 mm footer distance within the image and must be placed centred within the paper's printable margins. It is not a full-page A4 rendering.

The 29 × 20 template has retained its fixed geometry; general automatic centring has been introduced in the Argyll rendering.

## Image format, size and printing

- The print file is **RGB TIFF16**, 16 bits per channel, with no embedded ICC profile for base/refinement targets. C2 verification TIFFs embed the printer ICC as an identifying tag, without another conversion. CMYK targets are rejected as the wrong colour format.
- Normal resolution is 300 ppi. Resolution and physical dimensions shall be stated correctly in the TIFF file.
- The target's total image area, including margins, is limited by the project's **Target paper** settings in JSON. The starting value 320 × 370 mm applies to Christer's measurement slide and can be changed; see [paper proposals](target-paper-planning.md).
- Landscape A4 is **297 × 210 mm**. The dimensions are rounded to whole pixels at the chosen resolution. The reusable page template is **263 × 195 mm** and shall not be described as a full-size A4 image.
- Portrait A3 requires the project's length limit to allow 420 mm. With a smaller measurement slide, a split sheet or another proposal is chosen. The TIFF16 dialog's manual starting format is landscape A4 (297 × 210 mm).
- Print at **100 % actual size**, without fit-to-page and without colour conversion in the printing workflow. A profile-free file does not in itself guarantee that the printing program avoids colour conversion.
- Preview images are for on-screen viewing only; print the TIFF16 file.

Patch dimensions, contrast fields and the number of rows are determined by the chosen layout and shall be documented in the package. They must not be changed by scaling when printing. The current page template has 8 × 8 mm patches; the contrast test for the earlier rows 13–17 has 10 × 8 mm patches and 1 mm contrast fields. These are different layouts, not universal patch dimensions.

Since 2026-10-03, narrow targets have a separate footer layout: the source description is centred 27 mm, the file path 19 mm and the date/page number 10 mm from the bottom edge. The path can be wrapped to at most four lines within 12 mm. The bottom 8 mm is kept white. The paper proposals take the larger footer space into account. Create a new TIFF16 package to get the new layout; existing TIFF files and measurement data are not changed. Use the new package's matching TI2/JSON when the new print is measured.

## Measurement data and traceability

Every print shall have a corresponding definition of the patches' RGB values, identity, page and position. The internal description is JSON; the Argyll exchange uses TI1 for patch definition, TI2 for print layout and TI3 for later measurement results.

Randomisation shall be reflected in TI2 and JSON. Padding shall be distinguished from source patches. Always use the measurement data that belongs to the layout actually printed; an imported patch list does not mean that the originating program's layout has been recreated.

The package check shall verify patch linkage, RGB16 pixel values, geometry, resolution and file hashes. A change to the header or margins must not change the patches' values or size. If patches are moved, the position description must be updated. File checks and physical readability shall be reported separately.

Document the printer, paper, printing program/driver, media mode and quality settings used when printing. The date in the footer is the generation time; the actual print time and measurement time are recorded separately when needed.

## Implementation

The project's general target workflow uses contrast markers; supplementary targets use black/white. Older createTiff16 templates have a different layout and shall not be confused with the current app workflow. MXF import exists for the documented format variants.

A centred complete TIFF path is implemented in both rendering paths, together with the header, date/time and page number.

The standard is used by `inkprof.createTarget` and `inkprof.createTiff16`. The shared header and footer are rendered by `inkprof.internal.drawPrintFurniture` using Java2D in MATLAB with JVM. Patch data undergo no colour conversion in the text rendering.

See [generate targets](target-generation.md) and [measure targets](chart-measurement.md) for workflows.

Detailed structure and provenance: [targetInfo in JSON and TIFF](target-metadata.md).

## Printer-applied coating

Record clear coating applied by the printer in **Project details > Printing settings**. **Printer coating** is `unknown`, `off`, `on` or `automatic`; **Coating settings** records the product and driver mode, coverage or amount (for example Chroma Optimizer or Gloss Optimizer). These describe the printer's treatment, separately from the paper's Glossy/Matte finish.

The source of truth is `printing.printerCoating` and `printing.coatingSettings` in `inkprof-project.json`. New projects default to unknown; older projects without these fields do not imply that coating was disabled. The profiling recipe reads these fields from the project and does not provide a second editable copy. Both certificate export paths include the recorded settings.

Record the setting actually used for the measured print targets. A correction to project printing details invalidates dependent profiling results through the existing workflow rules. Changing the physical coating setup calls for a new project and targets printed and measured with that setup. Recording coating does not apply a numerical correction to existing measurements or control the printer. Previously exported certificates are not rewritten automatically.

## Ink type

**Project details > Project and materials > Ink type** records `Dye`, `Pigment`, `Mixed`, `Other` or `unknown` in `printing.inkType`. Use **Ink / ink set** to specify the actual product and channels, especially for mixed sets. The ink type is separate from printer-applied coating and paper finish. It is not inferred from the printer model or brand.

The profiling recipe reads the project value; both PDF and HTML measurement certificates include it in the printing conditions. Existing projects without the field remain unspecified. Recording the type does not alter measured spectra. Corrections use the normal project invalidation rules; a physically different ink setup requires a new project and matching measurements. Export certificates again to include updated project information.

## v1.0.0 project settings

Project details also records dye/pigment ink type, printer coating and coating settings. Matte paper can activate configurable extra dark patch sampling and shadow table emphasis. Read [matte shadow profiling](matte-shadow-profiling.md), [the current workflow](workflow-v1.0.md) and [gamut surface](gamut-surface.md). Certificates distinguish the saved build recipe from requested future patch counts.
