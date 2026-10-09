# B1 – select and lock the profiling input

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

**MXF import:** complete measurement values do not mean that the print information is complete. Check the printer, paper product, driver settings, colour management and measurement conditions, and keep unconfirmed information as unknown. See the [warning and rules for completing information](measurement-file-import.md#warning-mxf-may-need-additional-information).

Implemented 2026-09-27; user acceptance remains. A1 and A2 have been accepted by the user.

```matlab
cd('/Users/christer/Desktop/InkProf')
setupInkProf();
[folder, input] = inkprof.prepareProfileInput();
```

Choose a measurement revision (measurement JSON) explicitly. The dialog shows:

- file name and hash,
- number of RGB patches,
- spectral bands and XYZ,
- measurement conditions with provenance,
- recorded print information,
- diagnostics.

Enter a name and choose **Lock profile input** or **Cancel**. The most recent file is never chosen automatically.

A TI3 or MXF can also be chosen; it is then normalized through the existing measurement import. A TI3 needs its matching target description; if it is not found in the same folder, give it with `TargetFile`. This import step saves a separate measurement session even if the subsequent locking is cancelled. MXF uses its own layout.

```matlab
[folder, input] = inkprof.prepareProfileInput(measurementFile, ...
    ProjectFolder=projectFolder, Name="Epson 3880 - corrected 575");
```

For scripts there is `ShowDialog=false`, which explicitly approves locking the given revision after the checks. It does not bypass the checks.

## Checks

B1 checks the measurement's completeness, the chart hash, the corresponding revision TI3, patch identities, RGB values, and agreement between JSON and TI3. The row-direction diagnostic is recomputed, and a suspected reversed row blocks locking.

If colour-based diagnostics are not available, a positioned MXF can be used as alternative identity evidence:

1. The preserved original file's hash is checked.
2. The file is imported again.
3. Its patch IDs, positions and RGB are compared with the chosen revision.

The original MXF goes into the locked folder. This is saved as `layoutEvidence`; `rowDirectionCheck.available` stays false, and the physical sweep direction is not considered verified. Without either kind of evidence, locking is blocked.

The diagnostic is heuristic and covers only the complete rows the method can test. It does not certify the colour correctness of all patches. Normal colour deviation from the target file's estimates is not in itself a profile error or a reason to block. Original forward/backward sweep warnings are reported as historical measurement quality and may predate accepted spot corrections.

## Result

A unique folder under `profiles/inputs` contains:

| File | Content |
|---|---|
| `measurement.json`, `chart.json`, `source.ti3` | Snapshots of the chosen input. |
| `profiling.ti3` | Source patches only, without padding; order and measured values kept. |
| `profile-input.json` | Name, relative file links, SHA-256, source revision, retained data rows, measurement conditions, print information and diagnostics. |

The manifest is updated. Locked means a separate, hash-identified revision that the routine does not overwrite; it is not file-system write protection. Later build steps must verify the hash values before use. The original absolute paths are provenance, while the snapshot files are kept together in the new folder.

This step creates no ICC profile. The choice of spectral versus XYZ-based computation, and the full print recipe, belong to B2. An unknown paper or other missing print information stays unknown.

The corrected 575 revision `measurement-20260927-154833490-rows22-23.json` has been tested in a temporary test project: 575 source patches and no suspected reversed rows. The test project was deleted after the check; no permanent profile run has been chosen for the user.

## Window and waiting

B1 shows status messages during checking and saving. The confirmation window is shown on top and gets focus before the function waits for **Lock profile input** or **Cancel**. It is not modal against the whole MATLAB desktop. The function returns only when a choice is made; the close button counts as Cancel.

If an older run is waiting behind other windows: cancel with Ctrl+C in MATLAB, close only the window `InkProf - Select profile input`, run `rehash` and start again. No profile input is published before locking is confirmed. The window's accept and cancel paths have separate automatic GUI tests.
