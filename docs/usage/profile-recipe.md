# B2 – profiling recipe

> InkProf 1.0.0-rc.2, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

**MXF import:** complete measurement values do not mean that the print information is complete. Check the printer, paper product, driver settings, colour management and measurement conditions, and keep unconfirmed information as unknown. See the [warning and rules for completing information](measurement-file-import.md#warning-mxf-may-need-additional-information).

The B2 workflow was accepted by the user on 2026-09-27. A separate B2A quality was added the same day.

```matlab
[recipeFile, recipe] = inkprof.createProfileRecipe(folder);
```

`folder` is the folder that B1 returned. Without an argument, a file chooser for `profile-input.json` opens. The most recent revision is never chosen automatically.

The dialog shows:

- name and description,
- printer and paper product,
- Glossy/Matte/unknown,
- the driver's media setting, print quality, driver/version,
- printing application/path,
- colour management when printing.

The project's current shared information is filled in, and is changed in Project details. The locked B1 and earlier measurement data are not changed retroactively. Empty print fields become unknown.

## Computation choices

- **Spectra (D50 / 2 degrees):** Argyll integration during the profile build with `-i D50 -o 1931_2`. With the optional FWA/OBA compensation, Argyll spec2cie instead integrates and compensates once (`-i D50 -o 1931_2 -f D50`) before colprof. This is the default and requires spectra.
- **Stored XYZ:** the stored XYZ values are kept. The build step must create a separate input file without spectral/Lab columns and spectral metadata, to prevent the engine from choosing other colorimetry. B2 does not claim that stored XYZ has verified D50/2° provenance.

M0/M1/M2 describe the measurement condition, not the illuminant used for spectral integration.

Print quality is kept separate from the quality of the profile computation, which uses A2B medium and Lab cLUT. The dialog's **Inverse table (B2A)** chooses **High (denser)** or **Medium (baseline)**. High is the default for new recipes; `B2AQuality="medium"` chooses the comparison alternative. This does not change the measurement data or the forward model's quality choice.

The profile version is not chosen in this step; it is to be read from the engine's actual result. Glossy/Matte is a declared paper surface, not a paper name. Unknown remains in the recipe even if the engine has its own default attributes.

For the optional pre-regularization of the measured data before the build, see [pre-regularization](pre-regularization.md).

## Saving

**Save recipe** saves a new UUID folder under B1's `recipes`, closes the window and updates the project manifest. **Cancel**, or the close button, saves nothing. B2 generates no ICC.

The recipe contains a relative link to B1, SHA-256, measurement conditions, print declarations, computation choices and the planned engine arguments. The B1 files are checked before the dialog and before saving. B3 must verify these hash values again and carry out the chosen input preparation before the engine starts.

Script use:

```matlab
[recipeFile, recipe] = inkprof.createProfileRecipe(folder, ...
    Name="Epson 3880 Glossy", Description="Epson 3880 - 575 measured patches", ...
    DataMode="spectral", B2AQuality="high", ShowDialog=false);
```

The current project definition is used before B1's older snapshot of the information. `Printing` fields given explicitly in a script can replace the corresponding recipe fields. Saved recipes are read back with `jsondecode(fileread(recipeFile))`; editing or opening an existing recipe in the GUI is not yet implemented.

## Verification

Integration tests cover saving and reloading, the B1 link, and rejection of spectral mode when data are missing. GUI tests cover Save and Cancel. The B1 checks protect against a changed locked input.

The installed colprof 3.5.0 was tested separately with the corrected 575 data and explicit spectral integration. When a test copy got halved stored XYZ but unchanged spectra, the bytes of the A2B/B2A tables were identical. This confirms the spectral path's choice of data in this test. The experiment used low quality and is not an accepted user profile. The result is in `docs/research/colprof-b2-spectral-probe.json`, with temporary files in `work/b2-probe`.

Argyll describes `-i`/`-o` for spectral integration and `-f` for FWA; see the [official colprof documentation](https://www.argyllcms.com/doc/colprof.html). The file preparation of the stored-XYZ path and complete profile builds are verified in B3/B4.

The B2A choice is saved as `engine.b2aQuality` and as an explicit `-bh`/`-bm` in the engine arguments. Older recipes without the field run with their original arguments and are not changed automatically. A new recipe and job are needed for a denser B2A. A denser table reduces approximation error but does not guarantee a unique inverse or physical print quality.

FWA/OBA can be chosen directly in the recipe dialog. When a changed choice is saved, the project definition is updated too, and dependent results become out of date. The raw measurement and the locked B1 are preserved. See [FWA/OBA and later choices](optical-brighteners.md).

## v1.0.0 project settings

Project details also records dye/pigment ink type, printer coating and coating settings. Matte paper can activate configurable extra dark patch sampling and shadow table emphasis. Read [matte shadow profiling](matte-shadow-profiling.md), [the current workflow](workflow-v1.0.md) and [gamut surface](gamut-surface.md). Certificates distinguish the saved build recipe from requested future patch counts.

## Smoothing and optional gradient review

B2 separates **Measurement data smoothing** (optional pre-regularization) from **Smoothing at ICC build** (final `colprof -r`). Empty final smoothing uses 0.5%. Percentage display uses one decimal without rounding stored values. The optional RGB gradient window opens after a successful Manual B3 build with pre-regularization enabled; saving B2 does not open it, and Automatic B3 uses its own recipes. See [the workflow update](../releases/2026-10-07-workflow-update.md).

## Current rendering and weighting settings (2026-10-07)

**Perceptual compression (%)** requests a dedicated gamut-mapped perceptual B2A0 with `colprof -s`; 20% is a configurable starting value. Relative uses B2A1; absolute uses the relative table and media white. Automatic B3 carries forward this B2 compression setting, while pre-regularization and its gradient checkbox belong to Manual B3. Existing recipes are preserved; save a new B2 recipe and rebuild B3 for the new mapping.

See [quality tradeoffs](profile-quality-tradeoffs.md) for comparison tools, safeguards and diagnostic limitations.
