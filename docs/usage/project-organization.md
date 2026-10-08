# Organizing local project data

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

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
