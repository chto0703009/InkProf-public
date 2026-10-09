# Profiling paths, regularisation and refinement

Checked against the implementation on 2026-10-09. This is the common guide for the current app; archived experiments do not define its selectable options.

## Optical-brightener terminology

**OBA** (Optical Brightening Agents) and **FWA** (Fluorescent Whitening Agents) are two names for the same optical brighteners in paper. **OBC** (Optical Brightener Compensation) means compensation for their effect. All three terms concern the same phenomenon, but OBA/FWA name the substances and OBC names the compensation process. Argyll calls its process FWA compensation; X-Rite uses OBC. These names do not imply identical algorithms or results. See [optical brighteners](optical-brighteners.md) for the physical and measurement limitations.

## Choices and their consequences

| Choice | What happens | What to check |
|---|---|---|
| B2: Argyll only (raw measurements) | No separate measurement pre-smoothing. The final colprof build still fits and smooths the data. | Final `-r` and actual build arguments. |
| B2: Argyll colprof pre-smoothing (experimental) | An intermediate colprof model replaces the build basis with predicted XYZ, then the final ICC is built. Raw measurements remain retained. | First-pass noise setting and independent final-pass `-r`; FWA is integrated once before both passes in new recipes. |
| B3: Manual | Runs the saved B2 recipe. | Use this route when testing the explicit B2 smoothing/pre-smoothing settings. |
| B3: Automatic | Creates iteration candidate recipes; does not run the whole saved B2 recipe. The app carries over perceptual compression; candidate builds disable pre-smoothing. The approved B2 white reference is carried over when required. Default refinement mode is Argyll, high quality and final `-r 1.0`. | Read the selected candidate recipe and job log; do not assume B2 settings were inherited. |
| Row 15: Argyll only refinement | New preconditioned targen patches, without InkProf Jacobian sampling; continuation uses final `-r 1.0` without pre-smoothing. | The saved proposal's refinement mode and new measurement. |
| Row 15: Current InkProf (Jacobian sampling) | C3 residuals and Jacobian-guided new patches. Continuation builds Argyll ICC candidates with pre-smoothing off; by default final `-r` candidates are 0.5, 1.0 and 1.5 when development data exist. Without development data, the engine-default build is used. | Candidate selection evidence, gradients and actual recipe. |
| Rows 8-14 | Current numerical checks, new C2 print, measurement, review, explicit approval and measured delivery. | ICC identity, iteration and selected measurement revision. |
| Row 19 | Numerically checked delivery without current separate print verification. | Historical measurements stay labelled historical. |

Regularisation describes fitting/smoothing. Refinement describes adding measured training information and building a later profile. The two B2/row-15 labels containing “Argyll only” refer to different decisions. Raw measurements do not mean that colprof smoothing is disabled. Both refinement methods use Argyll for the ICC build.

## The two noise settings in a manual B2 recipe

**Measurement data smoothing / Assumed noise (%)** controls first-pass `colprof -r` only when Argyll pre-smoothing is selected; default 0.5%. **Smoothing at ICC build** controls the independent final-pass `-r`; an empty field uses the engine default, documented as 0.5%. The MATLAB recipe API defaults to 0.5 and uses NaN to omit the argument. These values describe assumed device/instrument deviation in percent, not a direct error limit or Tikhonov lambda. Two passes are not equivalent to a single build with a larger `-r`.

See [pre-regularisation](pre-regularization.md) for the two-pass Argyll route.

## First profiling run

Create and print the device-RGB fitting target (rows 1-2), measure and accept the selected revision (3-4), then lock B1 (5). Save B2 (6). Choose Manual in B3 (7) to execute that recipe, or Automatic for the candidate-building route above. Run checks (8). For a measured delivery, create and print C2 (9), measure (10), analyse (11), review (12), explicitly approve intended use and limitations (13), then export (14).

## Continue refining

Review current C3 evidence, then choose the refinement method in row 15. Print the new device-RGB fitting target and measure it in row 16. Row 17 follows the mode stored in the proposal and combines the specified earlier training with new fitting data. It does not simply reuse every setting in the earlier B2 recipe. Row 18 compares previous/current predictions at common samples; it is not a new print measurement.

To change refinement mode, create a new proposal through the refinement dialog and measure that proposal's target. To change a manual recipe, save a new B2 recipe and build it with Manual. Read the saved proposal, selected candidate recipe and status log rather than inferring settings from a previous dialog.

When useful improvement stops, document the reason and follow rows 8-14 for final measured approval. A changed ICC cannot inherit an earlier profile's physical verification or approval. Review Stale/Locked status and repeat dependent checks after changing inputs, recipe or project conditions. No automatic numerical stopping criterion establishes print approval.

## Read the result using the right evidence

Training fit, previous-vs-current prediction changes, and measured-print-vs-desired error answer different questions. Final verification applies to the exact ICC, print settings and measurement revision. System limitations may prevent meeting comparison references, but require evidence and do not waive an applicable standard. See [best practice](profiling-best-practice.md) and [measurement certificate](measurement-certificate.md).

Implementation references: `preRegularizationMethods.m`, `profileRecipeDialog.m`, `createProfileRecipe.m`, `executeWorkflowStep.m`, `iterateProfile.m`, `refineVerification.m`, `continueRefinement.m` and `runProfileJob.m` under `src/+inkprof` (`preRegularizationMethods.m`, `profileRecipeDialog.m` and `executeWorkflowStep.m` in `src/+inkprof/+internal`).

## Complete job planning and decision points

Use the [complete best-practice route](profiling-best-practice.md#complete-profiling-route-handbook-appendix), also in both handbooks on pages 38–44. For a careful, regularly used i1Pro2/paper setup, approximately 1,500–2,000 patches are a practical starting budget; 800–1,000 is a lower-budget start and 300–600 a pilot. These are recommendations, not app defaults or guaranteed quality thresholds. Keep comparable evidence when choosing raw fitting or pre-smoothing and Argyll only or Jacobian refinement. Stop based on useful improvement relative to repeatability, then verify the exact final ICC through rows 8–14. The appendix distinguishes Torger’s model-fit checks and i1Profiler’s recommendations from InkProf’s measured final-print assessment.
