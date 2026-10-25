# InkProf v1.0.1 workflow guide

Source build **1.0.1**, released 2026-10-11. Base MATLAB R2025b and Python 3.13 tested on macOS. Windows and Linux are untested; the measurement bridge uses POSIX. Install runtimes and ArgyllCMS separately. Start with `setupInkProf(CheckPython=true); startInkProfApp();` from the source folder.

## One project, one source of settings

Use New project once, then Open project to resume. Project details has Project and materials, Printing settings, Profiling and Target paper tabs. Record the user, printer, paper name/finish, ink and dye/pigment/mixed/unknown type, printer coating and its settings, print application, media/driver/quality/colour management, drying hours, profile name, D50 colour-data choices, FWA and paper/sled limits. Unknown values remain unknown. Recipe fields managed here are read-only in the recipe dialog. FWA changes made later are reflected in the project. Changing relevant inputs invalidates dependent results, preserving earlier evidence.

Rename through Project details to rename the project folder too. External folder renaming is detected for confirmation. Move the entire project folder between computers; locally discovered Python and Argyll paths belong to the computer, not the portable project. Verify project checks recorded file hashes. Close app after saving/completing the active operation; reopen the same project after drying.

## The 19 rows

| Row | Action | What it creates or decides |
| --- | --- | --- |
| 1 | Create/import RGB target | RGB definition and generation metadata |
| 2 | Save TIFF16 | Matching TIFF16, TI2, layout and manifest; print separately |
| 3 | Measure/select revision | Instrument readings and saved JSON/TI3 revision |
| 4 | Review and accept | Explicit acceptance of the selected revision |
| 5 | B1: lock inputs | Immutable, checked profiling input snapshot |
| 6 | B2: recipe | Manual build recipe; project settings are reused |
| 7 | B3: build ICC / automatic iteration | ICC candidate, build arguments and job log |
| 8 | Fit, Grid and C1 | Model fit, transformations and numerical checks |
| 9 | C2: save verification TIFF16 | Profile-applied verification target |
| 10 | Measure verification | Saved verification revision |
| 11 | C3: compare model and print | Desired vs measured and predicted vs measured errors |
| 12 | Review feedback | Recorded feedback/decision, not merely opening a window |
| 13 | Approve intended use | Selecting this available step opens the review dialog; enter scope and notes, then confirm explicitly |
| 14 | Save ICC and certificate | Delivery copies plus PDF/HTML measurement certificate |
| 15 | Save refinement TIFF16 | Added fitting patches, development checks and controls |
| 16 | Measure refinement | Reviewable additional measurements |
| 17 | Build next iteration | Combined training set and a new ICC candidate |
| 18 | Compare previous/current ICC | Shared RGB/Lab comparisons, independent of original meshes |
| 19 | Save without print verification | Numerically checked later iteration and explicitly limited certificate |

Ready: Required inputs are available. Select the step and Run selected step to start.

Complete: The step’s result or decision is saved and the app’s requirements for that step are met. This does not itself mean approved print quality.

Locked: The step cannot start yet. Read its description and first complete the prerequisite steps.

Stale: An earlier result needs updating because its inputs or settings have changed. Repeat the affected steps.

Use the dialog’s intended save or acceptance button. Simply opening and closing the dialog does not complete the step.

Refresh reloads saved status; it does not save edits still open in a dialog. Finish or cancel the active dialog before starting another operation.

## Targets, paper and measurement

TIFF16 files are saved, not sent to the printer. Copy TIFF16 for printing copies the selected target; retain matching TI2/layout data in the project. Use the documented colour-management path: base/refinement device RGB targets must not receive an unintended additional ICC conversion; C2 already contains the intended profile transform. Print under the recorded conditions and allow drying. Row labels are on both sides; compact layouts reserve a footer band.

Target paper suggests cut sheets A5 through A3+ or a roll/custom size according to patch count and equipment limits. Defaults 320 mm scan width and 370 mm length describe one sled, not a universal limit; edit the JSON-backed Project details values and review suggestions before saving. Smaller iterations can therefore use smaller sheets.

Measure through the app, review instrument prompts and allow calibration. Instrument model and serial are captured from output when available, otherwise remain unknown. A remeasured patch is a candidate until accepted/saved as a new revision. Select that revision and repeat the dependent review/checks. Absolute Lab and change in Lab are separate quantities. See instrument-startup and chart-measurement guides for reconnect/retry behaviour.

## Refinement and shadows

Use image colours or C3 feedback to propose more patches. An image's embedded ICC is used; if absent, a warning precedes the sRGB fallback so you can choose another image. Estimated-error filtering defaults to ΔE00 > 5. These are predictions, not measured errors.

Unmeasured C2 colours can be included with the new target. C2 colour/gray/challenge patches train the next iteration; repeated and paper-white patches retain control roles. Once used for fitting they are not independent validation of that next ICC.

For Matte paper, the configurable InkProf shadow strategy defaults to targen emphasis 2, colprof grid emphasis 1.3 and up to 48 additional dark fitting patches per iteration. Initial targets redistribute their selected budget; iteration targets add dark patches without removing selected image/C3 colours. Selection uses the current ICC's lower quarter of its black-to-white L* range and excludes RGB16 duplicates. Actual counts and the source ICC hash are saved. This is not an official Argyll matte preset, and improved print accuracy requires measurement. Existing targets are unchanged.

## Interpret and deliver

Fit error against training data, numerical consistency and physical print verification answer different questions. Large desired-colour errors with small model-vs-print errors may reflect gamut limits; this alone does not prove the cause. Shared-sample profile comparisons show change, not which profile is more accurate. Compare in 2D starting at L*=50, or switch to 3D. View gamut shows a separate ICC-derived surface; HTML can rotate it, PDF shows a still view.

The project already retains the ICC candidate. External saving creates a delivery copy with project name and date (YYMMDD); its ICC description is updated consistently, and original/delivery hashes distinguish the files. Export the complete HTML certificate folder with its supporting files. PDF can be handed over separately.

Certificates include project/material/coating/ink settings, instrument identity when available, FWA usage, ICC identity, scope, final measured colours, decision and dated signature space. Appendix A explains methods and ISO-related references; Appendix B contains legal terms. Selected ISO 12647-7:2016 comparison limits are referenced through MediaStandard Print 2018, published by Bundesverband Druck und Medien (bvdm, German printing and media industry association). This custom workflow is not ISO certification.

After row 17, run row 8. Then either perform current-iteration C2/C3 and approve for row 14, or use row 18 as decision support and row 19 for an explicitly numerical-only certificate. Earlier measurements remain historical evidence, not current-iteration verification. FWA models D50 effects from suitable M0 spectra; it does not turn an M0 instrument measurement into native M1. BPC (black point compensation) is not applied to the diagnostic absolute-colour comparison.

## Code, licensing and maintenance

InkProf code and authored documentation: GNU GPL v3 or later, without warranty; see LICENSE and THIRD_PARTY_NOTICES.md. Dependencies and schema/fonts have their own terms. This is a source-only preparation build: no MATLAB, Python or Argyll runtime is included. See docs/releases/v1.0.1.md and licenses/review-v1.0.0.md for the checked release boundary and remaining validation limits.

Existing ICC profiles can be tested in the separate **Verify existing ICC** project mode. See [Verify an existing printer ICC](verify-existing-icc.md).

## Final measured approval after refinement

When refinement no longer gives useful improvement, document the stopping decision using comparable evidence. Run rows 8 and 9, print C2 without further colour conversion, then run rows 10-12. Row 13 records intended use, limitations and explicit user approval; row 14 exports the ICC and certificate tied to current physical verification. Training fit or convergence alone does not establish print accuracy. Row 19 is the numerical-only route. See the handbook section “Finish with a measured and approved profile”.

For stopping decisions, system limitations and final measured approval, see [Best practice for profiling](profiling-best-practice.md). Failure to meet an applicable standard requirement must remain disclosed, even when a reviewer accepts the result for a different stated use.

See [Profiling paths, regularisation and refinement](profiling-paths.md) for the current B2/B3 choices, refinement defaults and settings that are not inherited.

## Complete profiling best practice

The [best-practice guide](profiling-best-practice.md) and matching handbook appendices (pages 38–44, updated 2026-10-09) follow the full job and decision points: existing-ICC target placement, measurement budget, printing, revisions and white references, smoothing, refinement selection, stopping, independent final print and reviewer approval. Source guidance from Torger and i1Profiler is compared with the actual InkProf route. Practical stopping recommendations are not automatic approval rules; row 19 does not replace measured final verification.

## Suggested next step

The main window displays **Suggested next step** with a reason. **Go to
suggested next step** selects that row; it does not execute it or approve
anything. Guidance uses current valid project evidence, including after
reopening a project. A registered refinement target leads to measurement
(step 16), then the next profile build (step 17). Profile comparison does not
replace up-to-date step-8 checks. After current checks, print verification is
the normal route; numerical-only delivery (step 19) and additional refinement
remain explicit alternatives. Creating or copying a TIFF cannot confirm that
it has been physically printed or dried.

## Optional CGATS measurement delivery to i1Profiler

In workflow row 14 or 19, tick **Include CGATS for i1Profiler when saving ICC/certificate** in the main window. No extra CGATS decision dialog is shown. The checkbox is initially unchecked. The delivery folder includes `i1profiler-measurement.txt` and its provenance JSON, also retained in the project export and supporting files.

This exports the selected original complete native M0 profiling measurement (XRGA, 36 spectral bands), without applying OBA compensation. It does not merge later refinements or export C2 verification data. External-ICC verification projects do not offer this option. In i1Profiler use RGB Printer → Profiling → Measurement → Load and select CGATS text; do not rename the file to MXF.

See the [export instructions and verified test](i1profiler-cgats-test.md) for precision, scope and recipient limitations.

## Local time in the app and readable logs

The close confirmation and iteration history display the computer's local time,
including the offset applicable on the recorded date (summer/winter time). New
readable workflow, iteration-progress and feedback log entries also use local
time. Certificate rendering converts UTC to local time when older source records
lack a local display timestamp.

Machine-readable UTC timestamps remain unchanged for traceability. Existing
registered reports/logs are not rewritten, and older readable log entries may
therefore retain their original UTC notation. Elapsed calculation times are
durations and do not need a time-zone conversion.

## Target editor window

The step-1 RGB target editor opens in front and stays above the workflow while
the step waits for Save or Cancel. Native file dialogs temporarily hide the
editor and restore it afterward. A running step awaiting this editor is not a
background profile calculation. The TIFF16 editor already uses this foreground
window behaviour.

## Updated target/print workflow (2026-10-24)

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

## Release 1.4.0 (2026-10-25)

The current gamut boundary/extended-target, measured Lab density, Select all/Recalculate and activity-timer instructions are in [workflow updates](workflow-updates-20261025.md). Targets remain unmanaged device RGB; new print versions use their own TI2 in step 16 and continue in step 17. Balanced density trials never replace the selected profile automatically.
