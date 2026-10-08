# Profile check – fit error per patch

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Implemented 2026-09-27. This is the first part of C1, not all of its forward/inverse validation. B3 has been accepted by the user, so the generated ICC candidate can now be checked numerically against its training data.

```matlab
[report, reportFile] = inkprof.checkProfileFit(jobFolder);
```

Call `inkprof.checkProfileFit()` without an argument to choose the job folder.

## The window

The window lists the patches sorted by decreasing ΔE00, with coordinate, sample ID, RGB, computed Lab and reference Lab.

A dropdown selects which patches to show:

- all patches,
- equal RGB (gray),
- dark,
- high-chroma,
- the boundary of the RGB cube.

The groups overlap, and their definitions are saved in the report. Equal RGB does not mean that the measured Lab is neutral.

## How the check works

The check uses the job's actual `engine.ti3` and ICC result, with hash checks against the job status. `profcheck -v2 -k -I a` gives an absolute colorimetric comparison.

- **Spectral recipes** also use `-i D50 -o 1931_2`, with the same optional FWA/D50 compensation as the profile recipe.
- **XYZ recipes** use the already prepared file without spectral data.

The reference Lab therefore follows the chosen computation path. It is not silently replaced by InkProf's own spectral integration values.

Every printed line is checked against the expected sample ID, measurement position and RGB in the TI3. Missing, duplicated or unknown patches are rejected. Colour independently recomputes CIEDE2000 from the Lab values in the log, with a tolerance for their six decimals. A changed or unknown log syntax is rejected, not guessed.

## Results

Results are saved in the job's `checks/<UUID>` folder:

- `profile-fit.json`,
- `profile-fit.md` (all patches),
- `profcheck.log`.

The manifest is updated. The JSON contains provenance, tool version, arguments, hash values, group definitions, statistics and individual values. For scripts, use `ShowDialog=false`.

## Interpretation

This is training error. It is not:

- independent print validation,
- a convergence curve,
- proof of an optimal solution.

The inverse, a separate RGB grid, smooth transitions, an independent CMM comparison and new control prints remain for C1–C3. The check does not change the profile or the measurement data, and patches with large deviations are not removed automatically.

[Argyll profcheck](https://www.argyllcms.com/doc/profcheck.html) describes `-k` as CIEDE2000, `-v2` as per-patch output and `-I a` as absolute colorimetric comparison.

Verification: six parser and identity tests, plus a run through MATLAB and the results window on the current 575-patch profile. The report is only published when every patch is present.
