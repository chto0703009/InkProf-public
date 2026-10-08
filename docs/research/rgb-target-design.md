# InkProf: number of patches and coverage of the RGB space

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-26. First investigation. The recommendations are trial proposals, not verified quality promises. No new prints or instrument measurements have been made for this analysis.

## Recommendation

Keep the existing 575 target as a first empirical basis. For a new standard trial, a budget of **882 measurement positions** is recommended, with a clear division between fitting, independent checks and repeats. Choose the final patch count according to measured model error, grey balance and variation — not merely according to an even distribution in RGB.

882 is a practical budget, not a mathematical optimum. The current A4 layout with contrast fields has 21 patches per row and 21 rows on a full page: 441 positions. Two pages hold 882. The recently created 575 targets occupy 28 rows on two pages, including 13 filler positions. A full 882 target requires 42 rows: about 50 percent more row sweeps, despite the same number of paper sheets. This is not the same layout as the older 29 × 20 template.

## What should be covered?

The control variable is u=(R,G,B) in [0,1]^3. We model the whole locked chain from RGB through print software, driver, media mode, ink and paper to spectrum or XYZ. The number of cartridges does not make this a twelve-dimensional control problem: InkProf can here only choose three input values.

Three goals must be kept apart:

1. Geometric coverage of the RGB cube, including corners, edges, faces and interior.
2. Sufficient resolution in the colour space actually printed.
3. Accuracy where the user sets priorities, for example grey balance, shadows and smooth tonal transitions.

Uniform RGB does not mean uniform Lab. R=G=B is a diagonal in the control-value space, not proof of a neutral print. The measured neutral path may lie at different channel values. Points near the diagonal are therefore also needed. Sampling the faces of the cube helps describe the boundary but is not sufficient proof of the real gamut boundary in a non-linear print chain.

Spectra can be integrated to XYZ and Lab without an ICC profile when illuminant, observer, scale and reference white are defined. For this study no such assumptions are used: the comparison below concerns device RGB only.

## What do Argyll and InkProf do today?

Argyll's printer guide gives 400–1000 patches as a general starting point for RGB, depending on behaviour and level of ambition. It is no guarantee for our printer. [1]

`targen` offers OFPS, regular cube points and a grey ramp. An earlier ICC/MPP can steer perceptual placement; without one, a general model is used. `-f` specifies the total budget including points already chosen. Profile-based neutral emphasis is relevant only when the neutral path can be estimated. [2]

The current `createTarget` uses `-d2`, white/black repeats, grey ramp and `-f`. InkProf's default values are 100 patches, 9 grey steps and 4 white and 4 black positions. This is a technical default, not an approved profiling recipe. Adaptation with an earlier profile, explicit cube distribution and role division for validation are not yet exposed as ready-made user options.

Do not mix the algorithm for choosing RGB points with randomisation of their position on the paper. Placement and contrast fields help the measurement; they add no new colour samples.

## Actual check of the 575 file

Checked source: `projects/Chart 575 Patches.pxf`.
SHA-256: `f54d05bb1c6b5898a3e30f8342a3361f166a4faa43aaad2d4ef9e67e32ad4fa3`.

Two comparison sets were created with the installed ArgyllCMS 3.5.0:

```sh
targen -d2 -e4 -B4 -g33 -m3 -f575 baseline-575
targen -d2 -e4 -B4 -g33 -m3 -f882 baseline-882
```

These are candidates for geometric comparison, not the final role-divided recipes. Both commands have been run and their actual patch counts checked. `-m3` places a sparse cube grid as anchors; it does not replace the spread between the anchors. The grey ramp and corners may overlap other choices, so the actual unique set must always be counted after generation.

| Property | Existing PXF 575 | Argyll candidate 575 | Argyll candidate 882 |
|---|---:|---:|---:|
| Measurement positions | 575 | 575 | 882 |
| Unique RGB | 569 | 569 | 876 |
| Extra positions with already occurring RGB | 6 | 6 | 6 |
| Cube corners | 8/8 | 8/8 | 8/8 |
| Unique R=G=B | 23 | 33 | 33 |
| Unique points on the cube boundary | 299 | 217 | 292 |
| p95 of distance to nearest RGB sample | 0.09672 | 0.09210 | 0.07761 |
| Largest distance in the probe grid | 0.11823 | 0.11644 | 0.10017 |

Distances are Euclidean in normalised RGB, not ΔE, percent colour error or profiling error. A regular grid of 33³=35,937 check points, including the cube boundaries, was used. For each point the nearest distance to the target set was computed. Duplicates were counted after rounding to eight decimals. The grid's largest distance is an estimate from below of the continuous worst-case distance; larger gaps may exist between grid points. Raw results, command output and reproduction scripts are in `rgb-target-study/`.

Conclusion: the 575 file has good basic properties and is not obviously unsuitable. About half of its unique points lie on the boundary. The Argyll candidate with the same count moves more points to other parts of the cube and has somewhat smaller gaps according to this measure. 882 gives a clearer improvement in coverage. None of this shows which target gives the lowest measured ΔE00.

## Proposed first standard recipe

The distribution below is InkProf's trial proposal, not an Argyll recommendation:

| Role | Positions | Use |
|---|---:|---|
| Fitting | 738 | Forward model and first profile |
| Locked check | 120 | Model selection and reported first check; never enters the fitting |
| Extra repeats | 24 | Two extra copies of 12 representative fitting patches |
| Total | 882 | Two full pages in the current layout |

The fitting set should contain all corners, about 33 diagonal levels and a sparse cube grid. Complement with well-spread points; the distribution near the neutral region should be tested rather than locked to an unproven percentage. The 12 base colours for the repeats should include white, black, several mid-greys and representative hues. Distribute the copies across pages and positions. Three copies per chosen colour give a rough picture of variation, not an exact uncertainty model.

The check set's 120 colours are chosen separately: tentatively 96 widely spread and 24 along or near the diagonal region. Avoid RGB that already exists in the fitting. These numbers and placements need pilot evaluation. If the check set is used to steer the next improvement, it becomes development data; a new untouched final test is needed for the final quality statement.

The roles must exist in the internal JSON and be respected on export to the profile builder. Writing all 882 to one TI3 and letting `colprof` use them all would destroy this division. Repeated RGB must have their own sample IDs, a common colour ID and a link to each other. Contrast fields and filler are separate layout objects.

For the already printed 575 chart: measure and use it, build a first basis and then create a separate check target. Save the cost of a new first print; there is as yet no evidence for discarding the 575 material.

## How is a sufficient number chosen?

A full regular grid costs n³ samples: 5³=125, 7³=343, 9³=729 and 11³=1331. Such grids are understandable comparison alternatives, but still require extra grey samples, repeats and checks. OFPS is a reasonable reference to compare with, not automatically the winner for all error measures.

Try growing, preferably nested fitting sets, for example about 400, 575, 750 and 1100 unique colours. Nested means that earlier samples are kept. Two separate targen runs with different `-f` do not automatically give nested sets. InkProf must own the completion list or choose documented subsets from a common measured set. The local 575 and 882 candidates above are not claimed to be nested.

In comparison, printer, paper, settings, drying time and measurement conditions must be equal. Repeated readings of the same print mainly measure reading variation; repeated prints are needed for print variation. Forward and return sweeps on the same row are useful but do not replace new prints.

Report median, p95 and max ΔE00 on the check set, as well as grey balance, lightness error and tonal transitions separately. Spectral error can complement, with an explicit scale. Report sample size: with 120 check colours, p95 is determined by only about the six largest errors. Small differences in p95 therefore require caution and repeated trials.

Stop the densification when the agreed quality requirements are met and the next extension gives no improvement that can be distinguished from print/measurement variation. Tolerances should be decided from the intended use; this investigation does not invent a generally approved ΔE00 figure.

## Adaptive continuation

When a first measured relationship exists, the next RGB points can be chosen with the support of a preliminary model. Consider geometric gaps, local check errors, changed slope/curvature and uncertainty. A large gradient alone does not mean a large interpolation error: a steep linear function can be interpolated exactly. Saturated areas with small response, on the other hand, can make the inverse unstable.

Mix targeted completion with continued broad exploration. Otherwise the model risks improving only areas where it can already detect its own errors. After the first measurement, neutrality should be steered by the measured neutral path, not only by R=G=B. Weighting in a fit cannot replace missing samples.

More patches do not increase the printer's physical gamut. They can improve the description of its boundary and enable a better inverse/gamut mapping. Using a preliminary profile for patch selection is not the same as colour-managing the test print: the control values must still be sent unchanged through the chosen print chain.

## Next implementation

1. A review command for targets: unique colours, corners, diagonal/boundary, gaps and roles.
2. Explicit generation recipe in JSON: algorithm, tool version, parameters, original patches and file hashes. The layout's random seed is not in itself a seed for the target's point generation.
3. Separate roles for fitting, check and repeat throughout the chain TI1 → TI2 → measurement JSON → profile basis.
4. Selectable base generation and later profile-based generation. Actual count and anchors are validated after the tool run, not only from the desired `PatchCount`.
5. Only then automatic completion and stopping criteria.

This document changes no production defaults and generates no new print targets. The existing 575 PXF and the two local Argyll candidates are analysis material.

## Sources and context

[1] [ArgyllCMS: Profiling Printers, Creating a print profile test chart](https://www.argyllcms.com/doc/Scenarios.html). Retrieved 2026-09-26.

[2] [ArgyllCMS: targen](https://www.argyllcms.com/doc/targen.html). Retrieved 2026-09-26; local tool version 3.5.0.

Earlier InkProf material: [model, inverse and adaptive measurement](InkProf-modell-inversion-och-adaptiv-matning.md), [print standard](../usage/target-print-standard.md). The mathematics, budget distribution and conclusions from the local data above are this investigation's own analyses.

After this investigation, a first [interactive geometric densification](../usage/rgb-target-designer.md) has been implemented. It is a comparison alternative to OFPS; there is not yet any control by measured colour error.
