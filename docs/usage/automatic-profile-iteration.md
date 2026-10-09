# Automatic profile iteration from measurement

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

`inkprof.iterateProfile` links together validated import, frozen training basis,
Argyll profiling, model comparison, numerical checking and printable TIFF16 targets.
MATLAB Base controls the workflow; Python and Argyll perform the colour calculations. No connection
to Camera-41 or SpectraLab is required.

This version uses spectral measurement data and D50/2° with the same selectable FWA/D50 compensation as the project's profile recipe.
The routine takes **measurement data**, not just patch definitions. JSON, TI3 and MXF are supported
via the existing import. TI3 needs a matching TI2 (`TargetFile`); a positioned
MXF uses its own layout. A target without measurements cannot give an ICC.

## Simple run

```matlab
cd('/Users/christer/Desktop/InkProf')
setupInkProf();
[iterationFolder, result] = inkprof.iterateProfile();
```

Select the measurement file. It must belong to an InkProf project; for an external file,
`ProjectFolder` is specified explicitly. The result is an **ICC candidate**, not an
automatic approval of the print quality. Every result gets a new folder.
No physical print is sent to the printer.

## Supplementary measurement with earlier training data

```matlab
[iterationFolder, result] = inkprof.iterateProfile(measurementFile, ...
    BaseMeasurement=previousMeasurementFile, RoleFile=roleFile, ...
    Name="Glossy - iteration 2", MaxNewPatches=100, ...
    NormTarget=1, GrayWeight=2);
```

The variables must be file paths. `RoleFile` is a JSON with `patches`, where each
entry has `sampleId`, `rgbPercent` and `role`. ID and RGB are checked against the
loaded measurement. `placement-plan.json` is also discovered automatically next to,
or one level above, the target's original path in the measurement's `targetInfo`.
After a move the path may need to be specified explicitly.

- `fit` goes to training.
- `adaptive_holdout` and `adaptive_validation` are used for model selection and
  supplementation proposals. They are thereafter development data, not an untouched final check.
- `control`, `repeat` and `final_holdout` are not included in training or model selection.
  Their original values are preserved for separate drift/final checking.
- A development RGB that already exists in the training gives an error, so that a leaking
  check sample is not presented as independent of the training.

For the next iteration `BaseInputFolder=fullfile(previousIterationFolder,
"training")` can be used instead of `BaseMeasurement`. The previous run's composite,
frozen training basis is then reused. Specify only one of the
options. Combination requires an explicit or discovered role file.

A composite training folder preserves the source packages under `sources/input-N/`.
`measurement.json` and `chart.json` in **this folder** are documents of type
`inkprof.profile-training-set`, not a new physical measurement or a new sheet.
Training IDs get a source prefix; the mapping preserves the original ID, coordinate and
row in the measurement file. The files are used through B2/B3, not as measurement files in the re-measurement dialog.

## Profile selection and stopping

With development points and `RefinementMode="inkprof"`, candidates keep A2B and B2A quality high and vary final
Argyll `-r` (0.5, 1.0 and 1.5 by default). The default `RefinementMode="argyll"` builds one
high-quality candidate with final `-r 1.0`. Exact arguments and photographic-gradient
reports are saved for every candidate.

A candidate replaces the baseline when development weighted RMS improves by at least
`MinImprovement` (0.01), or mean relative gradient curvature improves by at least 5%
with a development RMS increase no greater than `MaxAccuracyTradeoff` (0.05).
`MaxPatchRegression` (0.5 dE00) and `MaxGrayRegression` (0.25) still apply.
Matching floating-point photographic paths must also satisfy curvature, lightness-reversal
and interior-coverage guardrails. Missing gradient evidence retains the baseline for review.
These are numerical heuristics, not visibility or print-approval criteria.
See [accuracy and gradient quality](profile-quality-tradeoffs.md) for details.

All raw development errors and regressions are preserved. Repeats are grouped per
RGB in the norm; groups with too large mutual deviation are excluded. If development
points are missing, a high candidate is built without automatic comparative model selection.
Training errors are not used as a substitute for development checking.

With `RefinementMode="inkprof"`, the next supplementary target follows the existing error-supported midpoint method
(in the default Argyll mode no refinement print is created here; request a new Argyll target from the refinement dialog):
error, local measurement support, distance, grey priority and directed Jacobian sensitivity. A large Jacobian alone or a poor
condition number does not start densification. The Jacobian is estimated with ±0.5 RGB percentage points (one-sided at the cube's edge).
A bounded factor between 1 and 2 prioritises directions with greater
forward change. Singular values and condition numbers are logged as diagnostics;
the condition number is not used as an unbounded weight. Curvature and uncertainty in
the derivative estimate remain to be developed. `MaxNewPatches` is a cap, not a requirement
to fill the budget. `NormTarget` can stop proposals; this does not mean that the
profile is validated across the whole colour gamut.

## Two different print packages

1. `verification/print/`: C2, normally 128 source patches, with the profile applied
   once using absolute colorimetric and without BPC. The accompanying `verification.json`
   contains the desired Lab and the link to the profile.
2. `refinement-print/print/`: created only if new points are proposed. Device RGB
   without an applied ICC. Every fifth candidate is reserved for development checking
   when at least ten new points exist. Up to ten old RGB values recur twice
   for drift/repeatability checking. These check occurrences are in
   addition to the cap on **new** RGB points; all counts are reported. Roles and layout
   are frozen in `refinement-print/placement-plan.json` before measurement.

Both have contrast markers and matching TI2/TIFF16, A4 landscape by default.
C2 TIFFs embed the printer ICC as an identifying tag; refinement TIFFs normally
have no embedded ICC. Embedding performs no pixel conversion. Print at 100% without further colour conversion. Preserve
paper, printer and settings from the measurement basis. Read each package's
`PRINTING.txt`. The targets cannot be swapped with each other during measurement or analysis.

## Log, errors and remaining review

The folder `profiles/iterations/<UUID>/` contains:

- `iteration.json`: status, parameters, roles, links, source hashes, candidates,
  decisions, norms, checks and next steps. Updated after each phase.
- `progress.log`: readable event log with UTC time.
- `progress.jsonl`: corresponding machine-readable events.
- `training/`, role copy and the print packages.

The profile jobs have their own `colprof.log`, status, arguments and ICC hashes. Relative
links in the iteration also point to these jobs within the project folder. Preserve the whole
project for portability. A build error is logged and stops the chain; already
saved artefacts remain. Ctrl+C cancels; `cancel.request` in the iteration folder
is checked between phases. With `ShowJobDialog=true` a running profile job can be
cancelled in its window. A new run creates a new iteration, no hidden restart.

No profile is installed or replaces the original. Status
`ready-for-print-review` means that the candidate and test files exist, not
that print settings, drift, historical re-measurements or measurement noise are
finally approved. The same M condition does not prove the same print/measurement chain.
The check points for drift are preserved but an automatic drift lock remains to be done.
Internal solver convergence is not claimed when Argyll only reports a successful run.
Colour and metamerism validation still requires physical measurement.

## Industry tolerances and own acceptance limits

See [colour difference and tolerances](../research/colour-difference-tolerances.md)
for ISO 12647-2/-7, the difference between ΔE*ab and ΔE00, and cautious visual
interpretation. `MaxPatchRegression` limits the increase of an error between candidates;
it is not an absolute print tolerance. Weighted RMS is not the same as the
arithmetic mean error. The current parameters are InkProf's project rules,
not ISO approval limits.

## Feedback from a verification print

C3 now gives a machine-readable diagnostic prioritisation, with configurable limits and separate predicted/measured errors. `VerificationReport=reportFile` registers it in the iteration log. It does not automatically change training selection or candidate selection. See [verification feedback](verification-feedback.md) for call, rules and limitations.

## Continue after supplementary measurement

[`continueRefinement`](refinement-continuation.md) finds the parent's locked training package and the target's role plan, validates the new measurement and calls the profile iteration with the correct links.

## v1.0.0 project settings

Project details also records dye/pigment ink type, printer coating and coating settings. Matte paper can activate configurable extra dark patch sampling and shadow table emphasis. Read [matte shadow profiling](matte-shadow-profiling.md), [the current workflow](workflow-v1.0.md) and [gamut surface](gamut-surface.md). Certificates distinguish the saved build recipe from requested future patch counts.

## Current accuracy and gradient selection

Automatic candidates now hold A2B quality constant at high. In Current InkProf mode they vary final `colprof -r` (0.5, 1.0, 1.5 by default); the default Argyll mode builds one candidate with final `-r 1.0`. With reserved development measurements, selection includes relative photographic-gradient guardrails and an explicit small accuracy trade-off. Without development measurements, one default candidate is built; no superiority claim is made. See [accuracy and gradient quality](profile-quality-tradeoffs.md) for the current parameters and saved evidence.

See [Profiling paths, regularisation and refinement](profiling-paths.md) for the current B2/B3 choices, refinement defaults and settings that are not inherited.
