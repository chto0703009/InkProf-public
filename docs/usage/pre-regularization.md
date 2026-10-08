# Pre-regularisation of measurement data (experimental)

Status: experimental, **Off** by default. The function has been tested with numerical tests and integration tests. It has not been physically verified with a print.

## Optical-brightener terminology

**OBA** (Optical Brightening Agents) and **FWA** (Fluorescent Whitening Agents) are two names for the same optical brighteners in paper. **OBC** (Optical Brightener Compensation) means compensation for their effect. All three terms concern the same phenomenon, but OBA/FWA name the substances and OBC names the compensation process. Argyll calls its process FWA compensation; X-Rite uses OBC. These names do not imply identical algorithms or results. See [optical brighteners](optical-brighteners.md) for the physical and measurement limitations.

## Current app scope

Only raw measurements and experimental Argyll pre-smoothing are selectable in B2. For an explicit B2 test use **Manual** in B3: automatic iteration creates its own recipes with pre-smoothing off. See [profiling paths](profiling-paths.md) for defaults, inheritance and refinement modes.

## Function

In the profiling recipe (B2), **Measurement data smoothing** (pre-regularization) selects whether the measurement data should be smoothed with a separate model before the ICC build:

| Option | Effect |
|---|---|
| Argyll only (raw measurements) | Unchanged behaviour. colprof profiles the locked B1 measurements. |
| Argyll colprof pre-smoothing (experimental) | Two-pass build, described below. |

With **Argyll colprof pre-smoothing (experimental)** the profiling job (B3) runs:

1. **Pass 1, model.** `colprof -qX -al [-i D50 -o 1931_2] -r <avgdev> [-V …] -bl -nc` is run on the raw `engine.ti3`. Without FWA, spectra are integrated here with the recipe's colour measurement conditions. With FWA, spec2cie already prepared simulated D50 XYZ before this pass.
2. **Evaluation.** `profcheck -v2 -k -I a` evaluates the model's A2B absolute colorimetrically at exactly the original device RGB values. Model Lab is converted to XYZ (ICC D50 PCS, scale 0–100).
3. **Derived build basis.** `preregularization/derived.ti3` retains patch ID, location and RGB. Measured XYZ, Lab and spectra are replaced with model XYZ. The file is marked with `INKPROF_DERIVED_DATA` and the avgdev value used.
4. **Pass 2, profile.** The recipe's ordinary arguments are run on the derived basis: A2B/B2A quality, `-r` from Smoothing and matte settings. Spectral arguments are not repeated, since the basis contains only XYZ.

## Traceability

- The raw `engine.ti3` is never changed. Its hash is retained as `engineTI3SHA256`. The fit report (`checkProfileFit`) therefore compares the final ICC against **raw** measurement data.
- `status.json` states `buildTI3` and `buildTI3SHA256` and a `preRegularization` block. The block contains arguments, profcheck's path and hash, hashes for the model and derived TI3, and a summary.
- The folder `preregularization/` contains `model.icc`, `derived.ti3`, `patch-comparison.json` and `patch-comparison.md`. ΔE00 there shows how much the model changed each patch compared with the measurement. It is not an accuracy measure.
- The logs are saved in `colprof-pre.log` and `profcheck-pre.log`. The job window shows the pass 1 log until the final build starts.

## Limitations

- Argyll's `-r` is the assumed average deviation of device and instrument in percent (default 0.5). It is an assumed deviation, not an acceptance threshold.
- The final build does colprof's own fitting and its own `-r` again. The result is therefore not the same as a single colprof build with a larger `-r`.
- New spectral FWA recipes first integrate and compensate native M0 spectra with Argyll spec2cie, then run both model and final builds on XYZ without further FWA correction. See [optical brighteners](optical-brighteners.md) for white averaging and blank-paper fallback.
- Model values are never saved as measurements. A numerically smoother profile still requires physical print verification.

## Sky gradient

`inkprof.checkSkyRamp(job)` (`analysis/sky_ramp.py`) sends a blue sky path through the profile's B2A, relative colorimetric and perceptual, and back through A2B. The path is based on the test image with the blue sky: L* 38–70, b* ≈ −40 to −23, plus two parallel paths with b* ±4.

The report shows:

- RGB second differences in total and in the banding window L* 40–55,
- channel reversals,
- the ratio between the largest and median colour step,
- the longest 8-bit plateau.

`comparePreRegularization` runs the check for each variant. It is a numerical check, not a print test.

## More methods

Selectable methods are listed in `src/+inkprof/+internal/preRegularizationMethods.m`. Each method is planned in `createProfileRecipe>preRegularizationPlan`. Validation and execution take place in `profiles/preregularize.py` and `profiles/profile_job.py`.

The former InkProf grid regularization (axial curvature and full Hessian, with λ chosen by cross-validation or noise level) has been removed. Recipes that still use it are rejected by B3; save a new B2 recipe. Existing ICC files and measurements are unchanged.

## Smoothing labels in B2

**Smoothing at ICC build** sets the assumed average deviation for the final ICC build. Leave it empty for the engine default (0.5 %). The saved value is `engine.smoothing`. This field applies to all pre-regularization choices and is separate from the first-pass colprof avgdev.

## Optional RGB gradient window

When pre-regularization is selected, B2 offers **Open RGB gradient test after profile build** (off by default). After a successful B3 build with dialogs enabled, this opens a separate, nonblocking window. **Run RGB check** samples nine device RGB paths at 1,025 points through the final ICC A2B, with relative colorimetric and perceptual intents. Select a path and intent to inspect input RGB, output Lab, adjacent ΔE00 steps and Lab second differences. Numerical reports and sampled curves are saved under the job’s `checks` folder. No automatic pass/fail threshold is applied: genuine printer curvature can also produce second differences.

**Check blue-sky inverse** runs the complementary B2A/A2B sky diagnostic. The window evaluates the final ICC, rather than the intermediate regularization model, and does not change the recipe. Physical gradient verification is still needed. Reopen it with `inkprof.checkRGBGradients(jobFolder)`; use `ShowDialog=false` to run and return a saved report from a script.

B2 labels the first stage **Measurement data smoothing**. For the Argyll model, **Assumed noise (%)** is its first-pass `-r`; **Smoothing at ICC build** is the independent final-pass `-r`. The final field shows that an empty value means the default 0.5 %.

## Joint accuracy and gradient evaluation

The app exposes photographic conversion diagnostics and a matrix comparison with final `colprof -r`. See [accuracy and gradient quality](profile-quality-tradeoffs.md) for usage, selection rules and limitations.

## Choosing smoothing in the full workflow

See the [complete best-practice appendix](profiling-best-practice.md). Estimate the need from repeated readings, correct acquisition errors first, and compare equivalent colour and photographic-gradient evidence. Torger’s example uses final colprof -r1.0, while Argyll documents 0.5% as its default assumed average deviation; neither is a universally optimal instrument setting. A lower training error is not proof of a better final print. B2 pre-smoothing and final ICC smoothing remain separate decisions, and a recipe comparison should hold FWA and the measurement basis constant.

## Keith Cooper: photographic printer test images

See [accuracy and gradient quality](profile-quality-tradeoffs.md#keith-cooper-photographic-printer-test-images).
