# Image-guided refinement

> InkProf 1.0.0-rc.2, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Use **step 15 → From image** to propose additional patches from a photograph or other RGB image. All colours are eligible. The selection does not favour green or any other colour family. A current ICC profile and completed numerical checks are required. Error-driven refinement remains available as a separate choice and requires current verification feedback.

## Image profile and selection

InkProf reads the embedded RGB ICC profile and uses it to interpret the image colours. If no profile is embedded, a warning offers **Use sRGB** (the default), **Choose another image**, or **Cancel**. Choose another image if its RGB values belong to a different colour space. InkProf records the sRGB assumption and acknowledgment in the proposal JSON. An invalid or non-RGB embedded profile produces an error; it is not silently replaced.

Supported inputs are true-colour 8/16-bit TIFF and PNG, and RGB JPEG. Convert indexed, grayscale, CMYK and floating-point images to a tagged RGB image before import. Only fully opaque pixels are sampled. Pixel coordinates refer to stored image pixels without automatic EXIF rotation.

1. Select an image and review its profile description.
2. Use the whole image or enter an editable pixel rectangle.
3. Set the maximum number of new patches, minimum device-RGB spacing, and optionally a neighboring probe radius. A zero radius selects image colours only.
4. Review the proposed colour swatches, estimated local errors and measurement support. The default filter shows only **estimated local fit ΔE00 > 5**. Change the threshold or select **Model mapping ΔE00** explicitly to filter that different measure. Missing estimates are excluded. Only visible, checked patches are added; uncheck unwanted patches. If no rows qualify, lower the threshold or change the metric.
5. Review the editable paper-size proposal and save the TIFF16 target. Repeat controls are added separately, so the printed total can exceed the new-patch budget.
6. Print with colour management disabled and the project's printing settings. After drying, measure in step 16 and build the next iteration in step 17.

The image preview is a spatial selection aid. Candidate swatches are converted to sRGB for display; the printed target contains raw 16-bit **printer device RGB**, with no image ICC applied to the TIFF.

## What the method does

InkProf samples at most approximately 100,000 image pixels at their original channel precision. It selects representative occupied Lab cells using colour diversity and sampling frequency. Image RGB is transformed through its source ICC to relative D50 Lab with LittleCMS. The current printer ICC then maps these colours to device RGB using ArgyllCMS, relative colorimetric intent and no black-point compensation.

Candidates too close to existing training RGB or other proposed RGB are excluded using the largest channel difference in percentage points. This spacing test is not a test of complete colour-space coverage. Optional neighboring probes explore nearby device values. Their displayed source colour and mapping difference describe the originating image colour.

The displayed **Model mapping ΔE00** compares the image colour with the model's forward/reverse mapping. It is neither a measured print error nor proof that a colour is outside the printer gamut. Image selection guides additional sampling; improvement is established by measurement. Existing adaptive fitting, development and repeat-control roles are frozen before measurement. An independent verification print is still required to assess print accuracy.

## Estimated error in the latest profile

The review shows the latest profile's measured training-fit summary (mean, 95th percentile and maximum ΔE00). Each candidate also has **Est. local fit ΔE00**, a local estimate computed from up to four nearby training measurements. Measurements must be within 10 percentage points in every device-RGB channel. Their measured fitting residuals are averaged with inverse-distance weights; distances below 0.1 percentage points use that weight floor. The support column shows the number of measurements and distance to the closest one.

This is a local indication from the existing measurements, not a prediction with a known confidence interval or an independently verified print error. If nearby measurements are absent, InkProf displays **Unavailable** instead of inventing a value. The estimate is separate from **Model mapping ΔE00**, which describes image-to-profile mapping. The validated fit report, estimation method, support and values are saved in JSON with the proposal. The selected filter metric, strict greater-than threshold, visible count and selected count are also recorded. A report from another profile or measurement set is rejected.

## Portable project record

The project stores the selected image, source ICC, parent printer ICC, parent training measurements, sampling rectangle, parameters, all proposals, selected patch IDs, profile assumptions and hashes beneath `refinements/<id>/`. The workflow JSON identifies the method as `image`. No original image is edited. Keep the project folder together when moving it between computers.

For scripted use, `inkprof.refineFromImage(jobFile, Image="photo.tif", ShowDialog=false, SourceProfile="embedded")` requires a tagged image. For an untagged image, specify `SourceProfile="sRGB"` explicitly. Interactive use always offers the missing-profile warning before assuming sRGB.

## Calculation feedback

During image-profile inspection, colour conversion, patch selection and TIFF16 generation, the app stays visible and displays a busy dialog with the current operation and elapsed time. This is an activity indicator, not a predicted completion percentage. The busy dialog closes before the next input window, and on errors. The workflow also displays elapsed time for running steps. Large images and targets can take several minutes.

## Include C2 until measured

Step 15 automatically includes an existing C2 target for the **current ICC** until a current, valid saved C2 measurement exists. Saving or printing its TIFF does not count as measurement. An older iteration's measurement does not suppress the current C2 target. If you already selected image patches, choose **Use saved image patches** to rebuild the target without recalculating or reselecting the photograph.

The combined TIFF16 contains the selected image patches, repeat controls and the complete C2 set. The image ΔE00 filter does not remove C2 patches. C2's already converted device RGB16 values, desired Lab, IDs and repeat relationships are preserved; only their page positions change. Disable all print colour conversion as usual. Paper size is proposed again for the combined patch count and remains editable.

Measure the combined target once, in step 16 (or the linked C2 measurement step). InkProf computes the C3 report for the C2 subset and registers the same measurement for the refinement. Additional image/control rows are validated but excluded from the C2 colour-error statistics. C2 colour, gray and challenge patches are assigned `fit` roles and used to train the next ICC together with the selected image patches. Repeats and paper-white patches remain controls and do not add duplicate fitting weight. C2 results describe the parent ICC; once used for training, these measurements cannot independently validate the next ICC. Automatic measurement analysis does not approve a profile; review and approval remain explicit. A new ICC still needs its own verification.

The project preserves a snapshot of the original C2, the shared TIFF/TI2, new placement mapping, roles and workflow links. Rebuilding creates a new package; it does not overwrite the previous target.

## Activity feedback after step 15

- **16 — Measure refinement:** preparation, revision discovery, import, integrity checks and combined C2 analysis display activity. The instrument window keeps its scan/calibration status; saving and averaging readings has its own busy indicator.
- **17 — Build next iteration:** the busy dialog remains visible while training data, ICC candidates, numerical checks and the next verification target are generated.
- **18 — Compare profiles:** common-grid sampling and report generation display activity before opening the report.
- **19 — Save ICC and measurement certificate without print verification:** PDF/HTML/figure creation and copying delivery files display activity.

Indicators show the operation and elapsed time, without claiming a completion percentage. Nested calculation stages reuse one indicator and restore the outer stage afterward. Indicators close before interactive choices and on errors. Final output hashing and saving project JSON/logs also display activity.
