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

Step 3. Measure / select measurement revision reads the base target saved in step 2. A C2 print belongs to C2. Measure / select verification revision. If its package is already selected, go directly to that measurement step; do not generate the target again. After all rows are read, choose Save and finish, then C3. Compare model and print and Review feedback.

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
