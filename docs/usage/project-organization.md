# Organizing local project data

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

`projects/` is local and ignored by Git. Code and documentation belong in `src/`, `analysis/`, `profiles/`, `bridge/`, `tools/`, `tests/`, `examples/` and `docs/`.

## Categories

| Folder | Contents |
|---|---|
| `01-source-files/` | Original patch definitions and reference images. |
| `02-rgb-designs/` | Saved RGB grids with their TI1/JSON; older combined packages are kept together with their definition. |
| `03-print-targets/` | Print packages with TIFF, layout and the matching measurement files. |
| `04-measurements/` | Saved measurement sessions and imported measurements, including incomplete attempts. |
| `90-archive/` | Older grid and layout attempts, with no assumption that they are approved. |

A package that belongs together is moved as a unit. A source file, its design JSON and an older relatively referenced `*-files` package must not be spread across different folders. The page count and file names are not enough to decide which measurement files match a physical print.

## Local reorganization carried out 2026-09-26

- 79 entries were organized.
- All 903 content files were checked by size and SHA-256 before and after the move.
- No measurement or target content was deleted or changed.

Existing absolute paths are preserved by relative symbolic links in the old locations. The links are hidden in Finder but can be shown with Cmd+Shift+period. They are not extra copies of the content.

`projects/README.md` is the local table of contents, and `projects/organization-map.json` gives the previous and current location of each entry. The move plan and hash verification are in `work/cleanup-20260926/`. Files created later are not automatically included in this dated inventory.

Old metadata and TIFF footers keep their original paths. If a footer should show a new path, a new print must be generated; the old TIFF file must not be changed silently.

A backup needs the whole category content. If old commands are to keep working, the compatibility links must be preserved as well. How a sync tool handles symlinks is a separate local choice.

FreeFileSync jobs (`*.ffs_gui`, `*.ffs_batch`) and their database and lock files are ignored by Git. They are machine-specific and are not removed during code clean-up.

## Clean-up of the main folder 2026-10-03

Older local development material has been moved to a dated archive outside the code repository:

- the trial runs in `work/`,
- an older guide PDF in the root,
- the test image `MatrixLarge.jpg`,
- the reference file `CGATS Chart 575 Patches.txt`.

The archive contains a file list with SHA-256, and the content was verified after the move. The current guide is in `docs/usage/`.

References to `work/` in older research and testing notes refer to historical local working files, not to files needed to run the app. The archive is not distributed with the public repository. This clean-up did not touch the measurement projects in `projects/`, the current code, test data, local settings or the Python environment.

## Traceable external print copies

### Base target or C2 verification?

Step 3. Measure / select measurement revision reads the base target saved in step 2. A C2 print belongs to C2b. Measure verification print / select saved measurement. If its package is already selected, go directly to that measurement step; do not generate the target again. After all rows are read, choose Save and finish, then C3. Compare model and print and Review feedback.

### Target locked is intentional

A prepared measurement is bound to its TI2. The disabled Choose chart button now says Target locked. To change the target, close the measurement window and select the matching target in the workflow. Do not substitute a similar-looking chart while a session is prepared or partially measured.

### What the window shows

The summary shows patch count, target type when recorded, page count, saved local time and UTC. Target details shows the full path and offers a page preview. Missing historical metadata is not guessed. Compare these facts with the printed footer. Package creation time does not prove the physical print date or drying time.

### Folder naming

Example: My printer paper_iter-1_c2_20261024-123456. The prefix is the saved project name, followed by the workflow cycle at copy, step and local copy timestamp. A collision creates another numbered folder rather than overwriting a previous delivery. This is the project name, not an independently entered ICC/profile description.

### PROJECT_INFO.txt

The UTF-8 text file retains the exact project name and ID, original project path, workflow step, current cycle/iteration ID, target-origin cycle/iteration ID when found in history, UTC and local copy/creation times, target description when present, source TI2 and its SHA-256, project printing settings and copied filenames with SHA-256. Unknown origin metadata stays unknown.

### Copies versus originals

PRINTING.txt retains printing instructions. print-delivery.json carries the structured receipt; the workflow also records the copy in project reports/history. TIFF data is copied and checked byte for byte. The physical sheet is not identified merely by a hash: match its footer and documented settings. The TIFF-only delivery does not replace the original TI2/layout for measurement.

### A target can outlive an iteration

A base or C2 target may have been created in an earlier cycle. The folder names the workflow cycle at copy; PROJECT_INFO.txt separately records the target-origin cycle recovered from matching history. Package creation date and copy date are different events and neither proves when the sheet was physically printed.

### Complete target-package copy

The optional complete-package copy from refinement tools uses the same project-based naming and project identification when its source is inside a recognised project. Without project context it uses a generic readable print-copy name; missing project/iteration facts are not invented.


## Unicode paths in v1.2.5

Version 1.2.5 supports `åäö ÅÄÖ ü Ü` in project and folder names, including decomposed characters such as `u` followed by a combining diaeresis. These letters need no replacement or warning. Normal portable filename restrictions still apply.

The common relative-path helper uses canonical paths and consistent character indexing for project inventories, workflow outputs, target manifests, imports, refinement references, print-control results and complete-package copies. Path confinement and SHA-256 verification remain active. Transient lock files and the manifest itself must not enter the artifact inventory.

For an affected older manifest, do not bypass checks or refresh all hashes. Audit mismatches, preserve the old manifest, verify every retained artifact hash and repair only demonstrated path/control-entry errors. Measurements, profiles and registered certificates must remain unchanged.

Targeted validation: 17 MATLAB tests cover Unicode paths/JSON, project names, manifests, package copying, generated TIFF pixel/hash checks and print-copy identity. Three Python ICC-name tests cover exact Unicode naming and unchanged colour tags. This is not full-suite or physical-instrument qualification. These fixes are included in v1.2.5.


## Original project preservation safeguards

The original project and measurement data must remain intact. Print copying uses new destination folders, never a project rename or move. A print-copy destination is reserved exclusively; an existing folder is never reused. Complete target-package copying rejects the entire project as its source and destinations inside that project. The workflow verifies that the original manifest and TIFF files are still present and unchanged before registering a successful copy.

Print folders carry `PRINT_COPY_ONLY.txt`, even during copying. The app explains that a selected print-copy folder is not the project and displays the recorded original path. The success message lists both copy and original locations. A print copy does not replace or back up the full editable project.

An explicitly requested project rename stays within the same parent, rejects occupied and Trash paths, verifies identity metadata, and attempts rollback by rename if verification fails. It never deletes either project location. Measurement originals are not changed; corrections and remeasurements use separate revisions.

These additional safeguards are included in v1.2.6. Tests include simulated copy failure, destination collisions, source hash preservation and explicit rename checks. They do not establish what operation moved a historical project to Trash. Operating-system or Finder actions outside InkProf cannot be prevented by these application guards.


## Correcting project details without changing print conditions

Local addition after v1.2.6: after editing printing details in **Project details**, the app asks how to classify the change.

- **Correct recorded details** means the documentation was wrong but the actual printer, paper and print conditions were already the same. Enter a required explanation. Integrity checks must pass. Current profiling/verification validity is retained; a correction never restores previously stale results automatically.
- **Changed actual setup** uses the existing dependency invalidation rules. Measurements and profiles remain on disk, but affected steps must be repeated for the new conditions.
- **Cancel** saves nothing.

Only descriptive fields can be corrected this way, including media labels, quality text, coating descriptions and notes. FWA computation, shadow parameters, numerical input mode, ICC build quality and output-version selection cannot be reclassified as text corrections. The same current configuration value returned by a dialog does not count as a change merely because MATLAB represents text differently.

The project history and result logs record the correction kind, operator, reason and complete before/after printing details. A separate `reports/<UUID>/metadata-correction.json` preserves the audit. Existing RAW/TI3 measurements, ICC profiles, TIFF targets, model parameters and historical certificates are not rewritten. New exports use the corrected project metadata; historical packages retain their original snapshots. Changing project name or operator can still invalidate certificate delivery metadata without invalidating the measured profile.

### Activity while saving ICC and certificate

Step 14 displays the current activity and elapsed time during certificate evidence collection, figure and PDF rendering, ICC variant preparation, and external delivery. Delivery phases identify the destination folder and show when copies are being verified and saved. The activity dialog closes on completion or failure; command-line batch exports do not open a window.

### RGB control measurement cues

The C2b RGB control window plays a short cue immediately before each requested spot measurement, including remeasurements. Calibration does not play the measurement cue. Page changes appear as an inline instruction; change to the indicated printed sheet before measuring its RGB squares. No additional page-change confirmation dialog is required.

Spot start cues also apply to individual patch replacements and paper-white measurements. Both screen commands and the i1 Pro 2 physical switch are supported. Physical switch detection uses Argyll debug level 3; the acquisition trace remains in the attempt transcript. Calibration does not trigger the spot start cue.

### Workflow result windows

C1 workflow checks save their reports without automatically opening separate result windows. Use **Open selected step results** to inspect saved reports. C2 paper selection opens directly without a preliminary short-lived activity popup. When gamut points are added through **Refinement tools**, the gamut window closes after the print package is successfully saved and registered; cancelling or failing to save leaves the selection available for correction. The standalone gamut viewer remains open for inspection.

RGB control calibration can be cancelled with **Skip / close** or the window close button. Saved attempt requests, transcripts and readings remain in their attempt folder. Spot transport reads only available characters, retains partial JSON lines and bounds work per GUI polling tick so a partial line cannot block the close action.
