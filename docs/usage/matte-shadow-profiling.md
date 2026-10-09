# Matte paper: additional shadow sampling

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

InkProf can allocate more measurement patches and numerical table resolution to dark colours on matte paper. This is an InkProf strategy using documented ArgyllCMS options, not an official ArgyllCMS matte-paper preset. Additional samples help describe shadows; improvement must be established by printing and measuring.

In **Project details > Profiling**, choose **Extra shadow detail for Matte**. It activates only when **Paper finish = Matte**. The adjustable defaults are:

| Project JSON field | Default | Purpose |
| --- | --- | --- |
| `shadowMode` | `auto-matte` | Use the shadow strategy for Matte; `standard` disables it |
| `shadowPatchEmphasis` | 2 (range 1–4) | Argyll `targen -A1 -V2` dark sampling emphasis |
| `shadowGridEmphasis` | 1.3 (range 1–3) | Argyll `colprof -V1.3` denser shadow table sampling |
| `shadowExtraPatches` | 48 (range 0–256) | Maximum additional dark fitting patches per iteration |

A new initial target uses Argyll sampling and redistributes its selected patch budget toward shadows. It does not increase that initial budget. Existing target definitions and TIFFs are not changed.

A new refinement target adds up to the requested number of dark patches, in addition to selected image/C3 patches and unmeasured C2 patches. Argyll generates a pool preconditioned by the current ICC. InkProf evaluates it in absolute D50 Lab and selects diverse colours in the lower quarter of the model's black-to-white L* range. Thus a matte black above L*=20 is still covered. RGB16 duplicates already in training or the target are excluded. Fewer patches are possible if the eligible pool is exhausted.

These extra patches are fitting data for the next iteration, not independent verification. Existing development and control roles are preserved. `shadow-patches.json` records requested and actual counts, RGB, predicted Lab, source ICC hash and lightness limits; the proposal authenticates it by hash. The placement plan and target metadata record the added count. Numerical predictions are not measurements.

The build recipe records effective settings, and the profile worker validates the matching `colprof` arguments. Certificates report the saved recipe's applied shadow setting; older recipes remain explicitly undocumented. Project settings shown in certificates are configuration, not proof that a target has been printed or measured.

More shadow grid emphasis trades some lighter-region resolution for shadow resolution. Start with the defaults and compare iterations. Paper finish alone does not change smoothing, measurement condition, FWA, black point compensation, coating or instrument polarisation. Regenerate a target and measure it to obtain new shadow data; rebuilding an ICC alone cannot create measurements.

References:
- [ArgyllCMS targen options](https://www.argyllcms.com/doc/targen.html): `-V`, `-A`, `-c`.
- [ArgyllCMS colprof options](https://www.argyllcms.com/doc/colprof.html): `-V` and matte media attribute `-Zm`. The documented 1.3–1.6 starting range for grid emphasis is discussed mainly for display/video use; InkProf's matte default requires its own verification.
