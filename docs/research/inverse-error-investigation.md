# Inverse error in the 575 profile – investigation 2026-09-27

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

## Conclusion

Two problems must be kept apart: the colour error from an approximate B2A table, and the fact that the forward model can give practically the same Lab for different RGB. A denser B2A table helps with the first but does not solve the second. The profile is still a candidate, not print-validated.

## Basis and method

Epson 3880, Scandinavian Photo Glossy, 575 corrected patches, spectral D50/1931 2°, no FWA. The project folder's historical name contains Canon, but here it refers to Epson. Original job: `45453c4b-b948-4183-96fd-103429a1c71c`.

Profile SHA256: `c0b096f157696eacfffef8f89df9e1b7469f531102707d859d04edfeeee035e0`.

729 RGB points (9³) with relative colorimetric, no BPC. For each RGB, Lab is computed with A2B, RGB with the inverse, and then Lab again. ΔE00 compares the two Lab values. The RGB deviation is the largest absolute channel difference in percentage points of the 0–1 range.

Three variants were compared with ArgyllCMS 3.5.0:

1. Original profile: `colprof -qm`, stored B2A via `xicclu -fb -ir -pl`.
2. Separate experiment: `colprof -qm -bh -al -i D50 -o 1931_2`, denser B2A. All three A2B tags are byte-identical to the original and the 729 forward values identical. This isolates the difference in the inverse.
3. Numerical inversion of the original's A2B via `xicclu -fif -ir -pl`.

Argyll documents [separate B2A quality](https://www.argyllcms.com/doc/colprof.html) and [stored versus numerically computed inverse](https://www.argyllcms.com/doc/xicclu.html).

## Results

| Method | Mean ΔE00 | 95th percentile | Max ΔE00 | Max RGB deviation, percentage points |
|---|---:|---:|---:|---:|
| Original B2A | 0.8819 | 2.5037 | 4.7791 | 52.5349 |
| Denser B2A, high | 0.4809 | 1.5168 | 2.4055 | 52.3058 |
| Numerical A2B inverse | 0.0507 | 0.3242 | 1.4351 | 51.9264 |

High reduces the mean error by about 45% and the maximum error by about 50%. The B2A tag grows from 41,818 to 240,250 bytes. This is a positive experiment, not an automatic replacement of the production recipe.

The 386 boundary points have a larger mean error (1.1222) than the 343 interior points (0.6114) with the original B2A. The largest RGB deviations are found among examined green/cyan points with high G.

## Concrete example: large RGB difference but small colour difference

For original RGB **(0; 1; 0.5)**, A2B gives Lab **(77.318312; −49.138420; 33.889605)**.

- The stored B2A chooses RGB **(0.525349; 0.919676; 0.499655)**. The colour error is only **0.4032 ΔE00**, despite a 52.53 percentage-point difference in R.
- Numerical inversion chooses **(0.506691; 0.988973; 0.501102)** with **0.000011 ΔE00**.

This shows that, within this numerical precision, the model permits practically the same colour at very different RGB. It does not prove that the printer actually reproduces both RGB equally. Interpolation, the density of the measurement data and measurement error may contribute to the model's behaviour.

The singular values of the Jacobian at the original point are approximately **103.27; 53.24; 2.15** Lab units per normalised RGB unit. The condition number is about **48**, stable for the tested difference steps 0.001–0.01. One RGB direction thus gives considerably less colour change than the others. At other green/cyan points the condition number is larger and more step-dependent. This is local diagnostics in Lab coordinates, not direct ΔE00 conditioning or proof of global uniqueness.

Along the straight line between the original RGB and the B2A solution, the colour deviation reaches 2.076 ΔE00. The region can therefore not be described as a completely flat valley merely because the endpoints resemble each other.

## What the figures do not say

All Lab targets in this particular check are created with A2B from known RGB. An exact preimage therefore already exists in the same model: the original RGB value. The remaining error with numerical inversion is not evidence that the target lies outside the gamut. It shows limitations in the inverse computation used, the solution selection and the numerics.

A small forward deviation from the training data does not guarantee a stable or unique inverse. A smooth forward model can still be weakly sensitive in one direction or have several possible solutions. Conversely, few recovered RGB values need not mean poor colour reproduction: colour error, RGB round trip and smoothness must be reported separately.

## Recommended small next steps

1. Expose separate B2A quality in the recipe and keep medium as a comparison. High is a clearly better candidate in this check.
2. Check grey ramp, colour ramps, the RGB of neighbouring PCS points and the CMM also for the high candidate before switching. Jumps between alternative solutions are particularly important.
3. Create a small verification target around the green/cyan cases: original RGB, alternative RGB and neighbouring points, plus repeats. Measure whether the model describes the actual printer there.
4. For an own inverse: use constrained optimisation with a continued starting value from the neighbouring solution, plus regularisation for smoothness. Grey priority must be defined separately. Do not choose only the RGB closest to the original; in a real PCS→RGB inversion the original is unknown.
5. Strengthen the measurement basis adaptively where verified errors or inverse sensitivity justify it; a denser table adds no new measurements.

## Saved results and reproduction

- `inverse-error-investigation.json`: numerical inverse, cases, Jacobians and line test.
- `inverse-high-b2a-experiment.json`: high result, tag sizes and A2B identity check.
- `analysis/investigate_inverse.py`: reusable analysis of a job and its grid check. Run with `--help` for arguments. Existing output is not overwritten.
- The high experiment's profile, unmodified TI3 and log are under `work/inverse-investigation/high/` (local experiment, not a published profile).

The original profile, recipe and measurements have not been changed. The results are synthetic profile tests, not independent print measurements or a convergence guarantee.

## Condition number and choice of inverse algorithm

A condition number around 48 is a warning signal of direction-dependent sensitivity, not in itself a reason to reject the profile or a sign of floating-point problems. Here it refers to the 2-norm condition number of the Jacobian in Lab per normalised RGB. The result depends on coordinate scaling and is not a general factor that can be multiplied by a ΔE00 error.

Locally, `δLab ≈ J δRGB` holds. A smallest singular value of about 2.15 means that a Lab perturbation of 0.1 in the most sensitive inverse direction can correspond to about 0.047 in the norm of the RGB vector in the linear model. Cube boundaries and nonlinearity can limit this. It is therefore absolute inverse sensitivity, measurement noise and desired colour tolerance together that determine the significance.

We are not switching Argyll's inverse algorithm solely because of this number. The stored B2A table is an approximation, whereas `xicclu -fif` is a different computation route; neither removes the fact that the model may allow several solutions. A denser B2A first addresses the measured table error.

For a later own inverse, an experiment with bounded trust-region minimisation (`0 ≤ RGB ≤ 1`), SVD/QR-based linear subproblems and controlled step length is recommended. Avoid explicit matrix inverses and undamped Newton steps near weak directions. Choose the previous neighbouring solution or B2A as the starting value, check alternative starting points and, where needed, introduce an explicit smoothness regularisation with a documented trade-off against colour error. Solving via the normal equations can square the condition number; that is no reason to choose that route here.

SciPy describes [least_squares with bounds and trust-region reflective](https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.least_squares.html). This is a proposed separate research route, not an already implemented replacement for Argyll. An algorithm can stabilise the choice of solution but cannot create missing measurement information or make an ambiguous model unique without extra criteria.

Following the user's decision, High is now the default in new recipes, with Medium selectable as a reference. Older recipes and profiles are preserved unchanged.

## Verified run with the new recipe

Job `63dfb8f4-034b-488e-82b0-341511343016` was built through MATLAB's ordinary recipe and job routines. The A2B tags are byte-identical to the baseline. Mean/max ΔE00 round trip was 0.4809/2.4055. The training fit is unchanged: 0.4865/2.3387. No RGB outside the cube or new forward-ramp candidates were noted.

The limited LittleCMS test gave at most a 10.11 percentage-point RGB difference compared with Argyll at the same quantised Lab input. This particular case corresponds to only 0.138 ΔE00 through the same A2B. Across all points this colour difference is on average 0.209 and at most 1.333 ΔE00. It is still an 8-bit comparison, not a full-precision comparison or physical validation. The results are in `high-b2a-build-20260927.json`.

Testing: five Python job tests (including older recipes, high/medium and an invalid quality choice), two MATLAB dialog tests, and a complete build, training check and grid check through MATLAB. The profile has not been installed as a system profile.
