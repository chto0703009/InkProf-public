# Error-driven local refinement

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

First implementation: `inkprof.proposeRefinement` uses a successful InkProf profile and a separate, complete spectral measurement to propose the next supplementary target. MATLAB Base handles the call and the review; Python/NumPy/SciPy/Colour analyse errors and geometry. Argyll `profcheck` computes the forward predictions. No measurement values are merged, and no ICC is replaced.

```matlab
[proposal, refinementFolder] = inkprof.proposeRefinement( ...
    jobFolder, measurementFile, ...
    Name="Local refinement", Iteration=1, ...
    MaxNewPatches=24, NormTarget=1, ...
    ErrorThreshold=2, RadiusPercent=10, MinSpacingPercent=1);
```

`jobFolder` and `measurementFile` must be paths that are already defined. The dialog shows the ranked points and the norm. `ShowDialog=false` is supported. `ParentIterationId` can link to an earlier proposal's `iterationId`. Each run is saved separately under the job's `refinement/`.

## Norm and iteration

The norm is `sqrt(sum(w_i * deltaE00_i^2) / sum(w_i))`, over unique usable RGB groups. The same RGB repeated counts once; Lab is averaged before the error is computed. The default weight is 1. `GrayWeight` affects groups whose largest minus smallest RGB channel is at most 2 percentage points; the raw errors are kept.

| Parameter | Meaning |
|---|---|
| `NormTarget` | The desired RMS norm. Reaching it stops new candidate proposals on the analysed development data; it is not global profile approval. |
| `MaxNewPatches` | The maximum number of new RGB points **in this iteration**, not the total number in the profile. |
| `ErrorThreshold` | The local ΔE00 above which an observation can support refinement. |
| `RadiusPercent` | The neighbourhood radius in Euclidean RGB percentage points. |
| `MinSpacingPercent` | The minimum distance to earlier training points, all loaded measurement points and already chosen proposals. |
| `RepeatLimit` | The largest allowed ΔE00 between repeats of the same RGB (default 1). Groups that exceed the limit are shown for review and are not included in the norm; the number excluded is reported. |

The norm is computed before supplementation. If the budget is reached, we do not know that the norm will be met. A new measurement and profiling are needed for the outcome of the next iteration. No estimated convergence rate is given.

## How proposals are chosen

High-error points need support from at least one other unique usable high-error point within the radius. Isolated errors are flagged for review. Existing training RGB are not used as supplementation anchors. New colours that have already been measured are listed in `reuseObservationIndices`, so that the user can consider using them without a new print.

New candidates are midpoints between the error anchor and nearby error observations or training points. Priority:

`max(deltaE00 - threshold, 0) × min(trainingDistance/radius,1) × min(existingDistance/radius,1) × userWeight`

This is a documented heuristic, not a prediction of improvement. Candidates are quantized to TIFF16 levels, duplicates are removed, and the minimum distance is applied before the budget. The algorithm covers the whole RGB cube; no colour regions are hard-coded.

## Saved files and next step

| File | Content |
|---|---|
| `proposal.json` | Norm, iteration ID, limits, stop reason, errors, residuals, repeat variation, candidates, priority components and source hashes. Indices in `errorObservationIndices`, `reuseObservationIndices` and `review.index` are **zero-based JSON/Python indices**; add 1 for MATLAB indexing. |
| `target.ti1` | Only the newly proposed RGB points. Not created if there are no candidates. |
| `sources/` | Copies of the profile, the original training TI3, the recipe, and the control measurement's JSON and TI3. |
| `request.json`, `profcheck.log` | Run inputs and log. The original run paths are history; the source copies travel with the package. |

Open `target.ti1` in InkProf's TIFF16 rendering, which creates the physical layout and the TI2. The TI1 file is a proposal; the user reviews the points and the print recipe before printing. Existing raw measurements are never changed.

## Validity and remaining limitations

The first version supports only a spectral D50/2° forward comparison, with the same optional FWA/D50 compensation as the profile recipe, the same known M condition and known device RGB. Profile, recipe, training TI3 and measurement TI3 are checked by hash. Inverse/gamut errors from a desired Lab must not be used as forward-model errors here.

The chosen measurement is declared explicitly as `adaptive_validation` in the API contract. A locked final target must not be passed to the function. The role cannot be determined automatically from an older measurement file; the caller is responsible for this. Checking the printer, paper, driver settings, calibration standard and drift still requires review. The same M condition is not enough to prove identical measurement chains. No automatic merging is done.

No new locked final control is generated from the error-driven candidates, as that would not be independent; such a control must be kept separate. New measurement and the next profile revision are now handled by the app's steps 15–17, with comparison in step 18 and saved iteration history.

## Integrated iteration and Jacobian (2026-09-29)

See [automatic profile iteration](automatic-profile-iteration.md) for the now implemented chain with role-driven merging, recipe selection and prints. It replaces the earlier need to connect all steps manually.

- `DevelopmentSampleIds` restricts which IDs may drive the analysis.
- `UseJacobian=true` makes extra forward lookups in absolute colorimetric with `xicclu`. The Jacobian is estimated at ±0.5 RGB percentage points, one-sided at the cube boundary.

For the candidate's displacement from the error anchor, `norm(J * displacement)` is computed. The older priority is multiplied by `1 + min(norm(J * displacement) / (radius * median(sigma_max)), 1)`. The median gets a numerical floor of 1e-10. The factor therefore lies between 1 and 2, and no single condition number can dominate the budget. The values are Lab sensitivity, not an exact dE00 measure or an estimated improvement after re-profiling.

`localSensitivity` in the observations contains the Jacobian, singular values, condition number (null when numerically near-singular) and difference step. `evaluatedPatches` keeps the individual control errors for comparing recipes. Existing calls without `UseJacobian` keep the older weighting.

## Alternative: colours from an image

Step 15 also offers **From image** for general image-guided sampling, independently of current C3 feedback. See [Image-guided refinement](image-guided-refinement.md) for embedded ICC handling, the missing-profile sRGB warning, editable patch selection and the shared continuation workflow.

## Choosing Argyll or InkProf in the app

**Choose the method in row 15**

Choose From verification errors, then 1. Argyll only or 2. Current InkProf (Jacobian sampling). Current C3 verification and feedback are required. Argyll only is the default. This selector is for additional patches, not B3.

**Argyll only**

The checked ICC preconditions Argyll targen to select new device-RGB patches, without InkProf Jacobian sampling or pre-regularization. The continuation builds a high-quality colprof candidate with -r 1.0.

**Current InkProf (Jacobian sampling)**

C3 residuals and Jacobian-guided patch selection are used, followed by comparison of ICC candidates using development measurements. Both methods build the ICC with Argyll colprof; they differ in patch selection and continuation settings.

**Saved choice and verification**

The method is saved in proposal.json as refinementMode and passed to row 17 after the new target is printed and measured. Choose another method when creating a later error-driven refinement; existing targets and measurements are not rewritten. Image-guided refinement uses a separate path. Numerical B3 fit checks are not independent print verification: print and measure the new C2 target to assess the new result.
