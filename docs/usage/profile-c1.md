# C1 – supplementary numerical profile check

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

`inkprof.checkProfileC1` supplements `checkProfileFit` and `checkProfileGrid` with three checks: a floating-point comparison against LittleCMS, local tests of the inverse, and deliberately damaged test copies.

```matlab
[report, reportFile] = inkprof.checkProfileC1(jobFolder);
```

Without an argument, a dialog asks for the job folder. `ShowDialog=false` saves the report without a results window. JSON and Markdown are saved in the job's `checks` folder and the project manifest is updated. The approved profile file is never changed. A result does not automatically mean approved print quality.

## Floating-point comparison

The comparison uses 729 RGB points, relative colorimetric intent and no black point compensation. The public LittleCMS C API is called with double-precision buffers (`TYPE_RGB_DBL`, `TYPE_Lab_DBL`), RGB 0–1 and ordinary Lab. No 8-bit conversion is done. Optimization and the pixel cache are turned off, so that the table evaluation itself is compared. The internal computations and ICC tables still have finite precision, and xicclu prints six decimals.

The same RGB or Lab values are sent to both engines. The report gives:

- the forward ΔE00,
- the RGB difference of the inverse,
- the colour difference between the two inverse solutions, evaluated through the same Argyll A2B.

The last of these is a model comparison, not an independent print measurement.

The library is looked up via Pillow and then the system's LittleCMS. `INKPROF_LCMS2_LIBRARY` can give an explicit library path, which must have the same architecture as Python. The API and version are checked. A missing library gives a clear error; the check is never skipped. The library path and version are saved. No new binaries are distributed. Licences are listed in `THIRD_PARTY_NOTICES.md`.

## Local behaviour of the inverse

At each grid point, one Lab coordinate at a time is perturbed by ±0.1, ±0.01 and ±0.001. The difference between the inverse's RGB values is reported for each scale. As the step shrinks, a locally finite slope should give a smaller output change. This is a diagnostic, not a guarantee of global continuity. Perturbed PCS values can lie outside the gamut and be clipped.

In addition, 27 RGB ramps with 1,025 points each are followed through A2B→B2A. The report shows the RGB steps, the second differences and the colour step after A2B. A large gradient or a LUT knee is not in itself a discontinuity. The test does not show how measurement noise affects a refitted profile; that belongs to ISSUE-001.

## Deliberately faulty profiles

Temporary test copies get:

1. truncated content,
2. a wrong ICC signature,
3. a wrong colour space,
4. a zeroed B2A1 CLUT with a still valid outer structure.

The first three must be stopped before any computation. The fourth must give a gross numerical error.

The limit of 10 ΔE00 is used only as a gross-error indicator in this test, never as an acceptance limit for print quality. The numerical mutation currently supports mft2. For other LUT types, it is reported as a negative control that was not carried out. This must not be read as meaning that an arbitrary ICC is faulty.

## Status

Implemented and tested 2026-09-27 with the denser B2A candidate; see the [C1 result](../research/c1-verification-20260927.md). C1's defined numerical checks are complete for this candidate. Other profiles and rendering intents need their own checks. Independent print validation belongs to C2. ISSUE-001 is kept open per the user's decision.

API reference: [LittleCMS lcms2.h](https://github.com/mm2/Little-CMS/blob/master/include/lcms2.h).
