# ISSUE-001 – Sensitivity of the inverse to measurement noise

Status: **Open**. Recorded 2026-09-27 at the user's request.
Affects C1/C2 (validation) and D4 (own inverse).

## Problem and evidence

The 575-patch profile's forward model shows weak directions and alternative RGB solutions, mainly in the green/cyan regions examined. One examined local Jacobian condition number is about 48; other points have higher values that depend more on the step size. This indicates possible sensitivity to measurement noise. The actual noise amplification through the whole chain, measurement → model → inverse, has not yet been quantified.

A denser B2A reduces the table's approximation error but does not close this issue. A large RGB deviation alone is not proof of a large colour error. See the [inverse investigation](../research/inverse-error-investigation.md).

## Remaining investigation

- Repeat measurements of the same patches under controlled conditions. Include the sensitive green/cyan regions, the gray scale and stable reference points. Separate instrument repeatability from print variation.
- Estimate measurement variation in spectra and Lab. Document measurement conditions, number of repeats and relevant correlations.
- Perturb the measurement data with an empirically motivated noise model and rebuild the profiles with unchanged settings. Keep seeds, input revisions, recipes and results in JSON. Perturbing only the PCS input to an already built profile is not enough for this check.
- Evaluate colour error, RGB spread and any jumps between nearby inverse solutions separately. Check different difference steps and scaling when assessing the Jacobian.
- Where needed, compare repetition/averaging, supplementary patches, model smoothing and a regularized inverse. Check the trade-off between stability and colour accuracy against independent measurements.

## Criteria for closing

1. Repeatability and noise amplification have been quantified with traceable data.
2. Tolerances for colour error and for the smoothness of the inverse have been set and justified for the intended use. No arbitrary condition number is used as the sole limit.
3. The candidate meets these tolerances on independent verification data, or has clearly bounded limitations that the user accepts.
4. The result, the action taken or the accepted residual risk is documented, and the issue is closed explicitly.

ICC development may continue while the issue is open. Robustness against measurement noise must not be considered verified on the basis of a low training error, a better roundtrip or a denser B2A alone.

## Decision 2026-09-27

The user wants the issue to remain open until deviations can be linked more clearly to condition numbers and noise. C1 may continue and be completed within its numerical scope without a full noise study now. Floating-point comparison and local PCS perturbation tests do not in themselves give evidence of errors caused by measurement noise. No such cause has been verified in this step.
