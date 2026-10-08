# Verification analysis as feedback to the iteration

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

`inkprof.analyseVerification` analyses a saved C3 `verification-check.json`. The computations are done in Python, and MATLAB Base provides the call. As of this change, new C3 runs also create `iteration-feedback.json`, `.md` and `feedback.log` automatically with default parameters, together with the C3 report.

```matlab
[feedback, feedbackFile] = inkprof.analyseVerification(reportFile, ...
    MeanLimit=2.5, PatchLimit=5, GrayLimit=2, ...
    ModelTolerance=1, RepeatLimit=1, GrayWeight=2, ...
    MaxPriorityPatches=20);
```

Without a file argument, a file chooser is shown. The parameters are given in the call; there is no parameter dialog yet. Each explicit analysis is saved in a new `feedback/<UUID>` under the C3 check, including the source report's SHA-256 and the parameters used. The original measurement is not changed.

## Three distances, three questions

- **Predicted error:** ΔE00 between the desired Lab and the profile's Lab at the printed RGB.
- **Measured error:** ΔE00 between the desired and the measured Lab.
- **Model deviation:** ΔE00 between the profile's Lab and the measured Lab.

All three are computed directly from Lab; the distances are not subtracted from each other. The model can correctly predict a large error against a difficult target colour. If, on the other hand, the model promises the right colour and the measurement deviates, the forward model or the print conditions need to be investigated.

## Diagnostic rules

The limits are configurable. Mean 2.5 and max 5 are comparison guide values from proof-print control; they do not give ISO approval of a custom RGB target. GrayLimit and ModelTolerance are InkProf choices, not ISO requirements. See [colour tolerances](../research/colour-difference-tolerances.md).

| Label | Condition |
|---|---|
| `model-or-print-chain-mismatch` | model deviation above ModelTolerance |
| `predicted-limitation` | model deviation within that level, but measured error above the patch limit; this does not prove a physical gamut limit |
| `within-diagnostic-limits` | all others |

Priority = max(model deviation − ModelTolerance, 0), times GrayWeight for grays, and times two when the measured error exceeds the patch limit. This is a transparent heuristic, not a forecast of gain or a statistical significance assessment. MaxPriorityPatches limits the number of reported priority source patches; it is not the number of new RGB samples.

Repeats are reported separately and do not get double weight in selection or main statistics. An exceeded RepeatLimit gives a recommendation to review repeatability before fitting. Missing repeats are reported as `unavailable`. Printed repeats contain both position and measurement variation; they are not an isolated measure of instrument noise.

## Link to the iteration log

```matlab
[iterationFolder, result] = inkprof.iterateProfile(measurementFile, ...
    VerificationReport=reportFile);
```

This saves a link, a hash and the priorities in the iteration, plus a `verification-feedback` step in the log. Existing BaseMeasurement/RoleFile and other parameters must still be given when needed. The feedback does not yet change the training selection, candidate selection or placement of new points automatically. For target production, the separate call `refineVerification` below is used, with the source patches' printed RGB. Review is required, especially when repeatability is poor.

If C2 is used for selection or fitting, it becomes development data, and the final verification needs a new independent target. A candidate must be evaluated at the same printed RGB to be comparable with the existing measurement; a new inverse gives different RGB and requires a later print for a physical check.

## Test case from 2026-09-29

116 unique patches and 12 repeats. K3 and F5 have large model deviations and are prioritized. S1/Q1 have large but mainly predicted errors. The result must never set `qualityApproved=true` or certify ISO conformance.

## Implemented link: Jacobian and the next target

`inkprof.refineVerification` now uses the C3 report to propose new RGB samples. With `RefinementMode="inkprof"`, MATLAB Base does the SVD, regularization, ranking and selection, and Python checks source hashes and identities and calls Argyll `xicclu` for absolute D50 Lab and derivatives. The default `RefinementMode="argyll"` instead lets the checked ICC precondition Argyll targen, without Jacobian sampling; see [error-driven refinement](error-driven-refinement.md#choosing-argyll-or-inkprof-in-the-app). The Jacobian method described below requires `RefinementMode="inkprof"`.

```matlab
[proposal, folder] = inkprof.refineVerification(reportFile, ...
    RefinementMode="inkprof", Name="Iteration 3 - C3 refinement", ...
    MaxNewPatches=100, NormTarget=1, ErrorThreshold=1, ...
    RadiusPercent=5, MinSpacingPercent=1, GrayWeight=2, ...
    CreatePrint=true);
```

Without a file argument, `verification-check.json` is chosen in a dialog. The settings are given as MATLAB parameters. The results window shows which source patches and directions motivated each proposal.

### Directions and samples

The residual is `measured Lab − model Lab`, and the Jacobian is Lab per RGB percentage point. For `J=U*S*V'`, a regularized direction `−V*diag(s/(s²+lambda²))*U'*residual` is computed, where lambda is at least `RegularizationFraction` times the largest singular value. It is used only as a sampling direction on both sides, not as a finished RGB correction. Three right singular vectors give further sampling directions.

Samples are created at half and full radius. The radius is shortened along the ray at the RGB cube boundary; no coordinate-wise clipping that distorts the direction is used. Candidates are quantized to RGB16 before the distance to training data, already measured points and other candidates is checked. MinSpacingPercent is Euclidean RGB distance in percentage points. MaxNewPatches is the upper limit for new unique RGB. Gray weight is decided from the target's gray role, not from equal device RGB, because neutral printing can require different channel values.

### Scoring and stopping

The selection score combines excess model error, gray weight, the sampling direction's Lab response relative to the residual, and the distance to existing samples. The condition number does not amplify the score without limit.

Derivatives are compared at steps h and h/2; groups above MaxJacobianChange (default 0.5 relative Frobenius norm) are stopped for review. The default h is 0.5 RGB percentage points. Repeated RGB count once, and disagreeing repeats above RepeatLimit are stopped. The stop conditions are a reached weighted RMS norm, the candidate budget, or no remaining allowed candidates. The limits are diagnostic choices, not ISO limits.

### Saved results

Proposals are saved in a new `refinement/<UUID>` under the C3 check, with `proposal.json`, `target.ti1` when there are points, `progress.log` and source copies. `CreatePrint=true` additionally creates `refinement-print/print/target.tif`, a matching TI2, and a frozen role plan with development samples and repeated controls. Controls come on top of the budget for new RGB. This is a new characterization target **without an applied ICC**, unlike C2. Print at 100 percent with the same settings and without colour conversion.

No profile is changed and no measurements are merged automatically. Compare the print conditions before use. A C2 that drives the refinement is development data, and a later verification must be independent. `iterateProfile(...,VerificationReport=...)` still only records the diagnostics; run `refineVerification` explicitly for this target production.

### Reopening a saved proposal

`inkprof.showRefinementProposal(folder)` shows the table from `proposal.json` without generating new patches or TIFF files. Without an argument, the folder is chosen in a dialog. Text cells are converted to `char` for compatibility with MATLAB's `uitable`.

After the supplementary target has been measured, the whole link to a new profile and a new C2 can be carried out with [`continueRefinement`](refinement-continuation.md).
