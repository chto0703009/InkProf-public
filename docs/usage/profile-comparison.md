# Compare successive profiles

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

**Compare with previous iteration** is available after the ICC profile for iteration 2 or later has been built. It is an optional branch; it does not approve the profile or block the normal verification workflow. Existing projects acquire the new step when opened.

The previous profile is taken from the archived preceding workflow cycle and checked against its recorded hash. Both profiles are sampled on the same 9 × 9 × 9 RGB grid using absolute colorimetric conversion with D50 and no black point compensation. Different original measurement meshes and internal ICC table sizes therefore need not match. Shared Lab targets from both profiles also show how their inverse RGB choices differ.

JSON, HTML and PDF reports are saved in the project's `comparisons` folder, together with copies of both profiles. The HTML view overlays the predicted Lab points: blue for the previous profile and orange for the new one. **2D a*/b* at selected L*** is selected initially: a* is horizontal and b* vertical, with equal units and a fixed scale across both profiles and all slices. Move the **L*** slider from 0 (dark) to 100 (light). Uncheck **2D** to display all lightness levels in the full 3D view; drag to rotate. The lightness controls are disabled in 3D. The half-width controls the thickness of the slice. A sparse slice is a sampling limitation, not proof of a hole in the physical gamut. No interpolated surface is presented as measurement evidence.

The largest differences receive local RGB probes at three progressively smaller intervals. Twenty-seven colour ramps provide additional transition diagnostics in JSON. Finite samples cannot prove continuity. Neither small profile differences nor smoother transitions prove that print accuracy improved. Shared Lab targets may be outside one profile's gamut.

The first comparison becomes available before the new control print has been measured, so it reports physical improvement as **not assessed**. Continue with new independent C2/C3 print verification before approving the new profile. Keep both numerical comparison and measured verification when deciding whether another iteration was useful.

## Practical use after an iteration

1. Measure the new refinement target, accept the saved measurement revision and build the next iteration's ICC.
2. Select **Compare with previous iteration** when it becomes Ready. The workflow obtains both profiles from the current and archived JSON state; it is not necessary to choose files by name.
3. Inspect the numerical differences and the 2D a*/b* view. Move the lightness slice through L* to inspect dark, middle and light regions separately.
4. Print and measure the new independent verification target. Compare the measured errors and important colours before deciding whether the iteration helped.

Different measurement meshes are expected when refinement adds colours. The comparison resamples the ICC transforms on common coordinates; it does not require equal patch counts or equate original patch positions. The comparison alone cannot establish which mesh produced more accurate physical output. Retained copies of both ICCs and their SHA-256 hashes identify exactly what was compared.

[Paper suggestions](target-paper-planning.md) adapt the next target's physical layout to its patch count. Changing the page layout does not change the shared sampling coordinates used for ICC comparison.

## End with a measurement certificate of numerical-only scope

After the current iteration's Fit, Grid and C1 checks (row 8), the optional row **Save ICC + report without print verification** becomes available. Run comparison (row 18) first if you want it included as decision support. Enter your intended use and reason for ending the iteration, confirm the scope, and choose project-only storage or additional external copies.

The PDF, HTML and JSON explicitly state:

> Numeriskt kontrollerad; denna iteration är inte verifierad genom separat utskrift och mätning.

The report includes current numerical evidence and, when available, the preceding iteration's hash-verified training-fit statistics and the current profile comparison. Mean, 95th percentile and maximum fitting error are shown side by side, with the change. The number of training patches is included because the two fitting errors may be calculated on different meshes. Differences between the ICC transforms on common RGB/Lab coordinates are separately labelled. These figures support the user's stated decision; they do not establish improved print accuracy.

This branch preserves the current ICC, saves the decision and scope in JSON and the results log, and generates a portable report bundle. It does not mark print verification or print approval complete, and it does not reuse a previous iteration's C3 measurement as evidence for the new ICC. The normal measurement-certificate route remains available through rows 9–14. Rebuilding the profile or its checks invalidates the numerical-only certificate in the workflow; previously saved copies remain historical records.

Both numerical-only and print-reviewed measurement certificates place liability, customer-printing responsibility and warranty wording in **Appendix B - Legal terms**, after the signature section and Appendix A (references and explanations). PDF, HTML and text follow this order; the structured JSON retains the wording. Technical scope and verification status remain beside the results.
