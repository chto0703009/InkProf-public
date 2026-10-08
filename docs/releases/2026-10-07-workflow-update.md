# Workflow update — 2026-10-07

These changes supplement the RC1 baseline. They do not change the release tag or establish physical print accuracy.

## B2: two separate smoothing stages

**Measurement data smoothing** selects the optional pre-regularization method: Off, Argyll colprof model, or an InkProf curvature/full-Hessian model. With Argyll, **Assumed noise (%)** controls the first model's `colprof -r`. Raw measurements remain preserved; the profiling job uses separately recorded derived data.

**Smoothing at ICC build** controls `colprof -r` for the final ICC. An empty field uses the engine default, 0.5%. This is independent of pre-regularization and Tikhonov lambda. The percentage fields display one decimal; display formatting does not round the stored calculation value. Lambda retains its precision because small values need more than one decimal.

The full-Hessian model penalizes axial and mixed second derivatives. Lambda can be chosen by grouped cross-validation or the noise-matched method, as documented in [pre-regularization](../usage/pre-regularization.md). These methods balance fit and smoothness; they do not guarantee absence of banding.

(Note 2026-10-08: the InkProf curvature/full-Hessian pre-regularization has since been removed entirely, including the API, the λ selection and the measurement weights. B2 now offers **Argyll only (raw measurements)** and **Argyll colprof pre-smoothing (experimental)**; legacy Hessian recipes require a new B2 recipe before rebuilding. See the changelog.)

Pre-regularization remains incompatible with FWA/OBA compensation. Final ICC smoothing alone can be used with compensation. Turning compensation off in Project details now preserves the locked B1 input and invalidates B2 and subsequent profile results. Changes to actual printing conditions still invalidate B1. A project invalidated by the earlier behaviour may require B1 to be locked again using the saved measurement.

## Optional RGB gradient check

The B2 checkbox opens a separate, nonblocking RGB gradient window after a successful **Manual B3** build with pre-regularization enabled. Saving B2 alone does not open it. Automatic B3 creates its own recipes and does not use this B2 checkbox.

Choose **Run RGB check** in that window to evaluate the final ICC. Nine device-RGB paths include neutral, primary, secondary and blue gradients. The check plots predicted Lab, adjacent Delta E00 and Lab second differences for relative and perceptual intents. JSON and Markdown results are saved in the job's checks folder. A separate blue-sky inverse check is available.

Large local changes and second differences identify places worth reviewing; these are numerical diagnostics without a universal pass/fail threshold. Physical prints are still needed to assess visible banding.

## Measurement and row remeasurement

A page-change instruction now includes the original page, row number and FORWARD/REVERSE direction, consistent with row instructions.

The measurement overview offers **Remeasure row** in addition to patch remeasurement. Select a page and printed row. The isolated session inherits the original scan mode and relevant measurement settings, including paired forward/reverse scans. Review differences before accepting or discarding. Acceptance replaces only that row in a new measurement revision; original measurements, candidate readings and the decision remain available. Historical paired-reading statistics are labelled as historical when a row has been replaced.

Saving a normal measurement opens the overview with all patches. This is the intended review step; it does not start a remeasurement session. See [row remeasurement](../usage/row-remeasurement.md).

## Paper planning and C2

Cut-sheet suggestions now explicitly say **1/2 A4 (2 pieces per sheet)**, **1/4 A3 (4 pieces per sheet)** or **whole sheet**. A fraction describes the measurement piece cut from the stock sheet, not a split TIFF. Numeric paper dimensions and areas display one decimal while retaining calculation precision. A fast acceptance timing issue in the paper dialog was corrected.

C2 shows an activity message and elapsed time while checking the profile and preparing test colours and paper options. Long summary text in the print footer is shortened with an ellipsis when necessary; the full TIFF filename and metadata are preserved.

C2 selects reference colours and applies the ICC once with absolute colorimetric intent and no black-point compensation. The resulting RGB16 TIFF contains device values for printing. Print it without an additional profile conversion. A TIFF without an embedded profile is therefore expected in this workflow; it does not mean the ICC was omitted. (Note 2026-10-08: new C2 TIFFs now embed the printer ICC as a tag only; the pixels remain unchanged device RGB. See [TIFF ICC handling](../usage/tiff16-dialog.md#icc-conversion-and-the-embedded-tag).) Patch count and page count depend on the selected target.

## Language and documentation

App labels and new interface text remain English. At the user's subsequent request, the user handbook is maintained in matching Swedish and English editions, both updated on 7 October 2026. The handbook builder supports both languages and defaults to English. The redundant Swedish README, presentation and separate workflow guide remain removed.

Dated development records, release history, original legal/source citations and existing project evidence are retained. Existing certificates are not rewritten. The presentation and MATLAB workflow PDFs retain their RC1 baseline; the updated bilingual handbooks and current Markdown guides document subsequent changes.

## Validation

Focused MATLAB checks covered recipe values, RGB dialog creation, FWA invalidation, row remeasurement and acceptance, measurement save behaviour, paper-dialog acceptance and footer layout. Python checks covered gradient calculations and row comparison; a real ICC was also used for a numerical gradient smoke check. These checks use numerical data and simulated instrument flows and do not qualify new physical measurement accuracy or visible gradient quality.
