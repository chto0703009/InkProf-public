# B3 – separate profiling job

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Implemented 2026-09-27; user acceptance remains. B2 has been accepted by the user.

```matlab
[jobFolder, status] = inkprof.runProfileJob(recipeFile);
```

`recipeFile` is the JSON file from B2. Without an argument, a file chooser for the recipe opens. This starts **colprof** and can create an ICC candidate. B3 covers technical job execution, not print validation or automatic approval of the profile.

The window shows the status, the job folder and the latest log output. **Cancel job**, or the window's close button, requests cancellation of this particular run only. MATLAB waits for the run to finish, but the GUI keeps processing events. Ctrl+C also requests cancellation, through the clean-up. If MATLAB is force-quit, automatic clean-up cannot be guaranteed.

## Job contents

Each run gets a unique folder under the project's `profiles/jobs`:

| File or folder | Content |
|---|---|
| `recipe.json`, `profile-input.json`, `source.ti3` | Snapshots of the chosen recipe and the profiling data. |
| `engine.ti3` | The exact input to the engine. Spectral mode keeps the spectra. storedXYZ removes spectral and Lab columns and spectral metadata, after checking that RGB/XYZ and patch identities are unchanged. |
| `request.json` | File hashes, engine path, time limit and preparation method. |
| `version.txt`, `colprof.log`, `worker.log` | Version, engine log and any errors from the Python job. |
| `status.json` | Atomically updated status, actual arguments, tool hash, exit code, result or error. |
| `work` | Isolated working folder; faulty or cancelled candidate files may be left here for troubleshooting. |
| `result/profile.icc`, `result/inspection.json` | Published only after exit code 0, an A1 check without warnings, the correct profile class and colour space, the expected A2B0/B2A0 tags, and unchanged inputs. New generic-compression recipes additionally require a distinct B2A1 and valid media white (wtpt), supporting perceptual, relative and absolute intents. Legacy recipes retain their original build settings. |

The final status is `succeeded`, `failed` or `cancelled`. `succeeded` means a technically created and structurally checked candidate, not approved colour quality. A normal finish updates the project manifest. Earlier profiles and locked measurements are never overwritten.

Python owns the colprof process and handles cancellation; MATLAB shows the status and writes a cancel file. Arguments are passed as separate process arguments, without a shell. The job accepts only implemented recipe settings, and compares the reconstructed arguments with B2's planned arguments.

The default time limit is 1,800 seconds for the engine build, and at most 15 seconds for the version query. The engine path comes from InkProf's Argyll configuration; `ColprofExecutable` can be given explicitly. `ShowDialog=false` is used for script tests. No instrument is used.

## Tests

Python tests with a fake engine cover a successful run, exit code 7, tampered input and cancellation. MATLAB integration tests cover storedXYZ preparation and tool errors. A separate temporary copy of the approved spectral 575-patch recipe is used for a test against the installed colprof; it does not choose a production profile for the user.

Limitations: checks of LUT quality, physical printing and independent colour validation belong to later steps. Unknown print settings in the recipe do not become known because the job succeeds. The profile is not installed into the system.

Test result 2026-09-27: the temporary run with 575 spectral patches, D50/1931_2, medium/Lab cLUT and colprof 3.5.0 finished with `succeeded`. A1 identified the result as ICC 2.2.0. The test project was removed after the check. This is technical verification of the execution path, not an accepted production profile. MATLAB's Cancel button is also covered by the integration test, using a waiting fake engine.
