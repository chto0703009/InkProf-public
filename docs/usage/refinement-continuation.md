# Continuing from a measured supplementary target to a new ICC and C2

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

`inkprof.continueRefinement` connects `refineVerification` and `iterateProfile`. It is used **after** the new supplementary target has been printed without colour conversion and measured. It needs the proposal folder and the new measurement file, not a manual setting of BaseInputFolder and RoleFile.

```matlab
[iterationFolder, result] = inkprof.continueRefinement();
```

First choose the proposal folder that contains `proposal.json`, then the new measurement (JSON, TI3 or MXF). For a workflow that is already open:

```matlab
[iterationFolder, result] = inkprof.continueRefinement(folder, measurementFile, ...
    Name="Epson 3880 Glossy - iteration 3", ...
    MaxNewPatches=100, NormTarget=1, GrayWeight=2);
```

Give a **measurement file**, not a TI2 or a C3 report. `MaxNewPatches` refers to a possible future refinement proposal created by the new profile iteration; it does not change the target that has already been printed.

## Automatic linking and checks

- The parent profile and the training data are linked via source copies and SHA-256. The complete locked training package is found by input hash; a loose copy of metadata in the profiling job is not enough.
- The frozen role plan is checked against the proposal's RGB points. New role plans and TI2 files also get hash values when the print target is created. Older proposals are validated semantically against the candidates and the parent profile's training points.
- The measurement must be complete and match in ID, RGB, position and measurement conditions, and its TI3 hash must match. B1 and the existing combination routine do further checks before profiling, including schemas and spectral compatibility.
- Only `fit` is added to the earlier training. `adaptive_holdout` is used for candidate comparison. Repeated control patches and final holdout patches do not become training data.
- The existing profile iteration creates and compares ICC candidates, runs the numerical checks, and creates a new C2 with the profile applied once. Any supplementary target is separate and has no profile applied.

For the existing proposal `80903390-9ee5-43dc-8348-1302d1825ac1` this gives 911 old + 80 new training patches = **991**. Of the 100 new RGB samples, 20 are reserved for development control. In addition there are 20 printed control patches. In total 120 are measured, but not all are added to the training.

## Pre-check, traceability and interruption

```matlab
[checkFolder, check] = inkprof.continueRefinement(folder, measurementFile, ...
    PrepareOnly=true);
```

This checks the linking and saves a plan without starting profiling. A full run uses the same call without PrepareOnly.

Each call creates a new `continuations/<UUID>` with `continuation.json` and `progress.log`. The new profile iteration saves its own frozen copy, `continuation-source.json`, and logs the parent link. Failures are logged, and existing profiles are not replaced.

No measurement is invented if one is missing. Identity checks do not prove that paper, drying and printer settings were comparable. Automatic drift assessment between print sessions is not yet included; the repeated controls are kept for review. The candidate selection's existing regression limits are unchanged and can be given as MaxPatchRegression, MaxGrayRegression and MinImprovement.

Development measurements must not later be called independent final verification. The new C2 print and its measurement are the next physical check, and no automatic ISO or quality approval is made.

The same continuation also accepts [image-guided proposals](image-guided-refinement.md). Image colours are interpreted using their embedded ICC profile, or an explicitly accepted sRGB assumption. Step 16 measures the raw device-RGB target; step 17 retains the frozen fitting, adaptive-development and control roles.

A combined image/C2 target uses C2 colour, gray and challenge rows for fitting the next ICC. Repeats and paper-white rows remain controls. All roles and RGB are checked against the frozen C2 reference. These measurements cannot independently validate the next ICC after being used for fitting. See [combined target handling](image-guided-refinement.md#include-c2-until-measured).

## v1.0.0 project settings

Project details also records dye/pigment ink type, printer coating and coating settings. Matte paper can activate configurable extra dark patch sampling and shadow table emphasis. Read [matte shadow profiling](matte-shadow-profiling.md), [the current workflow](workflow-v1.0.md) and [gamut surface](gamut-surface.md). Certificates distinguish the saved build recipe from requested future patch counts.

## Choosing Argyll or InkProf in the app

**Choose the method in row 15**

Choose From verification errors, then 1. Argyll only or 2. Current InkProf (Jacobian sampling). Current C3 verification and feedback are required. Argyll only is the default. This selector is for additional patches, not B3.

**Argyll only**

The checked ICC preconditions Argyll targen to select new device-RGB patches, without InkProf Jacobian sampling or pre-regularization. The continuation builds a high-quality colprof candidate with -r 1.0.

**Current InkProf (Jacobian sampling)**

C3 residuals and Jacobian-guided patch selection are used, followed by comparison of ICC candidates using development measurements. Both methods build the ICC with Argyll colprof; they differ in patch selection and continuation settings.

**Saved choice and verification**

The method is saved in proposal.json as refinementMode and passed to row 17 after the new target is printed and measured. Choose another method when creating a later error-driven refinement; existing targets and measurements are not rewritten. Image-guided refinement uses a separate path. Numerical B3 fit checks are not independent print verification: print and measure the new C2 target to assess the new result.
