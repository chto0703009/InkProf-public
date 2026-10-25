# InkProf - Technical description

Christer Törnkvist

christer@borgasundsfotografiska.se

https://github.com/chto0703009/InkProf-public

Version 1.2.4 | 2026-10-24 | GPL-3.0-or-later

Implementation, calculation chain and data contracts

This description covers the released RGB printer profiling application. It follows the data from target definition through measurement, ICC construction, numerical diagnostics, physical verification and delivery. The handbook describes the operator's click sequence; this document explains what those steps mean and which files they depend on.

The technical baseline is source version 1.2.4. Older interface illustrations are explicitly identified as documentation examples. They show fictional projects, not measurements proving printer quality. File paths in the appendices are relative to the installation or project root; generated UUIDs and directory names vary.


| Reading order / page | Contents |
| --- | --- |
| 2 | 1. Architecture and scope |
| 3 | 2. RGB target definition and rendering |
| 4 | 3. Measurement and colour-data conditions |
| 5 | 4. B1-B3: from accepted data to ICC |
| 6 | 5. What the numerical checks establish |
| 7 | 6. C2/C3: physical verification |
| 8 | 7. Refinement and successive iterations |
| 9 | 8. Project state, integrity and delivery |
| 10 | Appendix A. Installation, dependencies and licence |
| 11 | Appendix B. Files: what is needed and where |
| 12 | Appendix C. Audit checklist and source references |
| 13 | Appendix D. Measurement-target identity and external print provenance |
| 14 | Appendix E. Feedback and verified ICC delivery |

---PAGE---
## 1. Architecture and scope

InkProf coordinates RGB output profiling for a specified printer, paper, ink and printing configuration. It does not control an analogue camera or profile a digital camera. Its printed RGB targets are distinct from a photographed ColorChecker. The Camera-41 SG140 restriction does not restrict InkProf's configurable printer patch sets.

MATLAB provides the app, project state, geometry, dialogs and orchestration. External Python workers perform measurement bridging, spectral/numerical analysis, ICC inspection and report generation. ArgyllCMS supplies target/layout tools, instrument communication, profile construction and colour lookups. LittleCMS is used through supported Python/Pillow routes for additional ICC processing and checks. InkProf is not an independent replacement ICC fitting engine.

[FLOW]

Project settings record the physical printing conditions. A target definition records device RGB values and roles. Layout maps those identities to printed positions. Measurement revisions associate readings with the same identities. A locked input snapshot and recipe bind the build to reviewed data. Later diagnostics and verification bind their results to the selected ICC and input hashes.

The main workflow has 19 rows. Rows 1-4 prepare and accept measurements; B1-B3 lock inputs, record a recipe and build; row 8 checks the result; C2/C3 produce and measure a verification print. Feedback, intended-use approval and delivery follow. Rows 15-19 provide refinement, subsequent iterations, profile comparison and a separately labelled numerical-only delivery route.

Source map: `src/+inkprof/app.m`, `ProjectWorkflow.m`, `+internal/executeWorkflowStep.m`, `bridge/`, `profiles/`, `analysis/`.

---PAGE---
## 2. RGB target definition and rendering

Target design works in normalised device RGB, with three values per patch. The mesh method begins with an RGB cube grid and optional unique neutral-axis values. Delaunay tetrahedra define interior candidates. The default editor placement is centroid; APIs also support circumcentres and contained circumcentres with centroid candidates. Candidates outside the open cube, duplicates and zero-distance candidates are removed.

For a candidate p, the score is its Euclidean distance to the nearest existing fitting point: d(p) = min ||p - RGB_i||. The highest-ranked candidate is added and the triangulation is rebuilt. This is geometric coverage, not a measured colour-error estimator or a finite-element physical model. The API also retains an edge-refinement alternative.

The total patch budget includes fitting samples, separate control samples and repetitions. Controls use a deterministic radical-inverse sequence; repeats reference existing fitting samples. Saved roles are `fit`, `control` and `repeat`. Grey-axis RGB is not proof that the printer produces a neutral grey. Coverage diagnostics sample a fixed 33 x 33 x 33 grid and distinguish boundary and interior; they do not prove a continuous maximum gap.

Argyll alternatives use targen and may use an existing RGB printer ICC for perceptual point placement. In v1.2.2 an ICC v4 input automatically receives a separate approximate v2 compatibility copy. The original and conversion evidence are preserved. A cached copy is addressed by the original hash. The reconstruction uses a 17-cubed relative forward grid and inverse Bradford media-white adaptation; inverse tables and perceptual mapping are rebuilt. It is an approximation, not a version-byte edit.

Saving the definition creates TI1 plus JSON, without printing layout. Rendering subsequently creates TIFF16, TI2 and matching layout metadata. Ideal floating-point RGB and RGB16 quantisation are different records. Runtime figure references and callbacks are excluded from JSON.

---PAGE---
## 3. Measurement and colour-data conditions

The matching TI2/layout is essential: a measurement is not merely a list of Lab values. Patch IDs, location, RGB commands, completeness and available spectra/XYZ must remain linked to the printed target. Instrument prompts, calibration and strip direction are handled through the measurement workflow and Argyll bridge. Imported CGATS/TI3 or supported MXF data require matching identity and layout evidence.

![Measurement interface](docs/usage/handbook-source/examples/measurement-window.png)

Figure 1. Documentation interface example captured 2026-10-09 before instrument start. It does not demonstrate an actual measurement. Labels may differ from v1.2.2.

A remeasurement creates a candidate and then an accepted revision; it must not silently replace registered readings. Paired scans, repeats and spot corrections answer different questions. Repeatability estimates only describe the repetitions actually acquired; they do not quantify every source of printer, instrument or environmental uncertainty.

Measurement condition must be recorded rather than inferred from a file extension. Spectral input is integrated under the selected supported conditions; the current profile worker requires D50 and the CIE 1931 2-degree observer for its spectral route. Stored XYZ is a separate route and depends on its original calculation conditions.

FWA/OBA compensation requires native M0 colour spectra, known compatible non-UV-filtered instrument evidence, wavelength coverage at or below 400 nm through at least 700 nm, and a suitable measured paper-white reference. White-reference instrument and wavelengths must match. M1, M2, unknown or already compensated data cannot simply be treated as native M0. A blank-paper reading cannot replace missing colour spectra. Simulated D50 FWA compensation is not a physical M1 measurement.

Source map: `startMeasurement.m`, `MeasurementDialog.m`, `importMeasurement.m`, `prepareProfileInput.m`, `createProfileRecipe.m`.

---PAGE---
## 4. B1-B3: from accepted data to ICC

B1 rechecks the actual measurement bytes, matching JSON/TI3 values, chart mapping and completeness. It creates a new locked package containing measurement JSON, chart JSON, source TI3, profiling TI3 and `profile-input.json`. Hashes bind the snapshot to its evidence. Opening a dialog is not acceptance.

B2 writes an explicit recipe rather than building a profile. It records colour-data mode, output table quality, smoothing, perceptual settings and relevant printing information. Current project settings can supply values, but the saved recipe is the build contract. FWA is checked before the recipe can proceed. The removed InkProf axial/Hessian grid regularisation is rejected by the current job runner; it is not an active profiling option.

![Recipe interface](docs/usage/handbook-source/examples/profiling-recipe.png)

Figure 2. Fictional recipe example from 2026-10-09, cancelled without building a profile. A recipe documents settings, not measured quality.

B3 validates the recipe/input hashes, copies the required input into a work area and launches the Python profile worker and Argyll colprof. Spectral data and stored XYZ follow explicitly different preparation routes. When FWA is enabled, spectral integration/compensation is performed once before fitting, with evidence retained. The working `engine.ti3` identifies the data actually passed to the engine.

The job stores status, command arguments, worker logs and result identity. Successful, failed and cancelled are separate outcomes; a worker exiting without a valid final record is treated as failure. A previous successful ICC is not overwritten by calling it the result of a failed new job. Timeouts and cancellation are operational safeguards, not colour-quality criteria.

Source map: `prepareProfileInput.m`, `createProfileRecipe.m`, `runProfileJob.m`, `profiles/profile_job.py`.

---PAGE---
## 5. What the numerical checks establish

Training fit, numerical transform consistency and independent print accuracy are separate tests. A small training error does not establish generalisation to unmeasured RGB values. Numerical round-trip error is affected by gamut boundaries, inverse ambiguity, intent and sampling; it is not a substitute for a measured print.

| Check | Input and comparison | Interpretation |
| --- | --- | --- |
| Fit | ICC forward predictions versus training patch Lab | Describes fit to the data used for construction; per-patch Delta E00 |
| Grid | Sampled ICC forward/inverse behaviour | Numerical and grid diagnostics over the examined samples |
| C1 | Float CMM comparisons, local inverse neighbourhoods and damaged-profile controls | Diagnostic consistency and gross failure detection |
| C3 | Measured verification print against desired colours and model predictions | Physical print result under the recorded conditions |
| ICC comparison | Previous/current profiles on shared samples | Shows model change; does not prove which profile is more accurate |

Fit reports retain patch identities, predicted/measured Lab, absolute-colourimetric context and summary statistics. Filters such as grey RGB, dark, high chroma or RGB boundary aid inspection; they do not change the measurements.

C1 also checks deliberately damaged profiles as negative controls. Detecting those controls supports the diagnostic mechanism, not a blanket validation of all possible ICC defects. ISSUE-001 was closed by user decision on 2026-10-25 after several measurements without observed problems; remaining uncertainty was accepted for current use. Measurement-noise propagation through refitting is not yet fully quantified.

Reports are stored in new diagnostic subfolders and registered with the project. Rebuilding a check creates evidence for the selected ICC and inputs; it must not silently rewrite a previously delivered certificate. Interpretation remains an operator/reviewer decision within the intended printing conditions.

Source map: `checkProfileFit.m`, `checkProfileGrid.m`, `checkProfileC1.m`, `analysis/profile_fit.py`, `analysis/profile_c1.py`.

---PAGE---
## 6. C2/C3: physical verification

C2 creates a verification target for a selected successful ICC job or a supported imported profile. Desired absolute D50 Lab values are transformed to device RGB and quantised for TIFF16 output. The reference package preserves desired colours, actual RGB values, patch identities, source ICC hash and transformation conditions. The current C3 route requires absolute colourimetric intent without black-point compensation.

The generated verification set can contain colour, grey, challenge and repeated patches. An external supported reference set is an explicit alternative. Defaults and random seeds are recorded, not universal optimum sampling claims. Where a training set exists, the generated set applies a minimum RGB-distance policy; this is a defined sampling exclusion, not proof of statistical independence in every sense.

Print the C2 TIFF through the documented path without an unintended second colour conversion. Record printer/driver/media settings, paper and drying. After measurement, C3 checks unique identities, expected locations/RGB, completeness and the link to the reference. A similar-looking TI3 from another target is not interchangeable.

Two useful error vectors are distinguished: measured Lab minus desired Lab, and measured Lab minus the ICC forward prediction at the actually printed RGB. Delta E00 summarises colour difference; component differences in L*, a* and b* retain direction. Summary count, mean, median, percentiles and maximum refer only to the examined patches.

Large desired-colour error with small model-to-print residual can be consistent with limited gamut, but does not by itself prove the cause. Repeatability and documented print-chain conditions must also be examined. C3 feedback ranks residuals for further work; thresholds in `analyseVerification` are configurable diagnostic policies, not ISO certification or automatic profile approval.

Source map: `createVerificationTarget.m`, `checkVerificationTarget.m`, `analyseVerification.m`, `analysis/verification_check.py`, `analysis/verification_feedback.py`.

---PAGE---
## 7. Refinement and successive iterations

Refinement proposes additional RGB samples from image colours, previous verification evidence or other supported selection routes. An image's embedded ICC is used where available; a missing-profile fallback must be disclosed. Predicted error used for sample selection is an estimate, not an instrument reading.

Each iteration keeps roles and source identities. Samples that become training data for the next ICC are no longer independent tests of that ICC. Repeats and controls retain their explicit role; matching layout/definition data is needed because a generic TI3 alone does not carry the full workflow policy.

The configurable matte-paper shadow strategy can emphasise dark sampling and the Argyll grid. Current project defaults include patch emphasis 2, grid emphasis 1.3 and up to 48 additional dark fitting patches per iteration. These are InkProf settings, not an official Argyll matte preset or evidence that every matte paper benefits. Generated targets and actual counts are recorded; old targets are not silently changed when defaults change.

The next profile build combines the approved training evidence and produces a new candidate. Shared-sample comparison of previous/current ICCs reveals numerical changes. Repeat the current profile's checks and preferably a new physical verification print to determine whether performance improved. Comparing two model surfaces cannot establish new measured print accuracy.

The numerical-only delivery route for a later iteration is explicitly different from print-verified delivery. It documents the available numerical evidence and limited scope. It does not invent missing verification or imply that an earlier print validates a changed ICC.

Source map: `proposeRefinement.m`, `continueRefinement.m`, `iterateProfile.m`, `refineVerification.m` and the workflow's row 15-19 handlers. Exact target-generation routes are recorded in each project's evidence.

---PAGE---
## 8. Project state, integrity and delivery

`inkprof-project.json` holds project identity, printing settings, file inventory and history. `workflow.json` holds workflow state and artifact links. Project settings are not machine runtime configuration: local Python/Argyll locations do not become portable printer-characterisation data.

Ready means prerequisites are available. Complete means a result or decision has been saved for that row. Locked means a prerequisite is missing. Stale means a dependency changed and the previous result requires updating. None of these labels alone means that a print meets an intended accuracy requirement.

SHA-256 links identify exact input/output bytes. They can reveal substitution or accidental modification; they do not establish that an instrument was positioned correctly, that the printer settings were truthful or that a measurement was scientifically suitable. Unknown physical information must remain unknown. A new revision must preserve earlier evidence rather than silently rehashing unrelated changed files.

Delivery makes an explicit ICC copy and records source/delivery hashes. Interactive naming may update internal ICC description metadata, so a delivery copy can legitimately differ from the build candidate. Supported v2/v4.4 choices and version-conversion evidence must remain visible. Printer-profile construction and conversion are distinct operations.

Certificates and supplements identify measured conditions, selected profile and approval scope. HTML deliveries can depend on supporting files; move the complete bundle. Previously registered reports must not be regenerated in place: create a new workflow export. A digital certificate documents InkProf's saved evidence and operator decisions; it is not an accreditation or automatic standards-compliance claim.

Long calculations use elapsed-time activity and phase messages. Native file dialogs and user decisions are distinct from computation. Target design in v1.2.2 uses a separate v2 compatibility copy automatically when needed; other import routes can still require confirmation.

---PAGE---
## Appendix A. Installation, dependencies and licence

| Component | Role and requirement |
| --- | --- |
| MATLAB | App, geometry and orchestration. Base MATLAB R2025b tested on macOS; do not infer Windows/Linux qualification. |
| Python | External worker process. Runtime check accepts Python 3.10+ in the 3.x family; analysis requirements describe tested/supported 3.11-3.13. Match packages to the chosen interpreter. |
| ArgyllCMS | Installed separately. targen, printtarg, chartread/spotread, colprof, xicclu, profcheck and related tools are used by relevant routes. |
| NumPy, SciPy, colour-science | Numerical and spectral analysis. Exact pins are in requirements-analysis.txt. |
| Pillow / LittleCMS | ICC processing and comparison routes; original ICC and transform conditions matter. |
| tifffile, imagecodecs | RGB16 TIFF diagnostics and compressed TIFF support where required. |
| ReportLab | Report PDF generation, included through requirements-report.txt. |

A project-local `.venv` is the recommended isolated Python location; an explicitly configured interpreter is also supported. Creating an environment and installing dependencies are setup actions, not required on every target calculation. `setupInkProf(CheckPython=true)` checks the configured Python; `startInkProfApp` opens the app. The chartread bridge itself uses the standard library, while full analysis/reporting requires the additional requirements files.

The measurement bridge contains POSIX-dependent routes. Tested instrument operation includes i1Pro 2 on macOS; other OS/instrument combinations require their own validation. Communication success does not prove correct instrument calibration or measurement conditions.

InkProf-authored code, tests and documentation are GPL-3.0-or-later, without warranty. MATLAB, Python, ArgyllCMS and third-party libraries retain their own terms. Bundled exceptions include the CxF3 schema, fonts and materials listed in `LICENSE_SCOPE.md`, `THIRD_PARTY_NOTICES.md` and `licenses/inventory.json`. User measurements and supplied profiles are not relicensed by exporting a project.

---PAGE---
## Appendix B. Files: what is needed and where

These paths describe a typical project. Keep complete generated packages. UUID/name subdirectories vary; use the app rather than manually constructing them.

| Project-relative location | Contents / responsibility |
| --- | --- |
| inkprof-project.json | Project identity, settings, inventory and history; created by app |
| workflow.json | Saved workflow/artifact state; created by app |
| sources/ | Imported source material; preserve source evidence |
| targets/ | TI1 definition + JSON, rendered TIFF16/TI2, chart/layout and package metadata |
| measurements/ | Measurement sessions and revisions; paired JSON/TI3 and matching chart evidence |
| profiles/inputs/<id>/ | B1 locked input: profile-input.json, measurement.json, chart.json, source.ti3, profiling.ti3 |
| profiles/... | B2 recipe and B3 jobs; actual subfolder is recorded in workflow |
| <job>/engine.ti3 | Data supplied to the profiling engine |
| <job>/status.json; worker.log | Job outcome and operational evidence |
| <job>/result/profile.icc | Successful ICC candidate |
| <job>/checks/<id>/ | Fit/grid/C1 diagnostic reports |
| verification/<name-id>/ | C2 reference, rendered target and matched verification evidence |
| analyses/; reports/ | Analyses, decisions and delivery/report artifacts |
| profiles/exports/ | ICC export receipts and source/delivery identities |

The installation contains `src/`, `bridge/`, `profiles/`, `analysis/`, `schemas/`, `resources/`, `config/` and requirements files. These are program resources, not substitutes for project files. The common `.icc-v2-cache` under the installation projects/ location is a conversion cache, not a complete project backup.

For a new measurement workflow, the user supplies physical printer/paper/ink/settings, an actual printed target and instrument readings. An optional preconditioning ICC steers sample placement; it is not measured training data. Matching TI1/JSON/TI2/layout and measurement revisions are produced or imported through the app. Do not import only TIFF or only Lab and assume the identity chain survives.

---PAGE---
## Appendix C. Audit checklist and source references

| Question | Evidence to retain |
| --- | --- |
| Which physical printing system? | Project printing/material settings, print path and drying information |
| Which target and RGB values? | Definition JSON/TI1, printed TI2/TIFF16, layout and hashes |
| Which measurements? | Selected accepted revision, condition/instrument record, chart mapping and source TI3 |
| Which fitting input and settings? | B1 locked snapshot, B2 recipe, B3 arguments/log/status |
| Which exact ICC was checked/delivered? | ICC hashes in checks, verification references and export receipts |
| What was physically verified? | C2 package, matching print measurement and C3 report |
| What was approved? | Explicit intended-use decision and delivery scope, not just a completed row |

Primary implementation references are the source files named in each chapter. Paths without a prefix in those source maps are under `src/+inkprof/`. Public source and release: https://github.com/chto0703009/InkProf-public and https://github.com/chto0703009/InkProf-public/releases/tag/v1.2.4.

Detailed companion documents in the repository: `docs/usage/rgb-target-designer.md`, `docs/usage/workflow-v1.0.md`, `docs/usage/profiling-paths.md`, `docs/usage/profiling-best-practice.md`, `docs/usage/verify-existing-icc.md`, `docs/usage/measurement-certificate.md`, `docs/releases/v1.2.4.md`, `VALIDATION.txt` and the licence files. Some older guide headings retain historical version numbers; this document uses the v1.2.4 implementation baseline.

For v1.2.2 the focused MATLAB release checks comprise 23 passing tests covering ICC compatibility, activity, RGB generation and definition saving. The automatic compatibility route was also checked with an existing cached v4 original: a v2 header was produced, source SHA-256 remained unchanged and activity was cleaned up. These checks do not represent a new full-suite qualification or physical print/instrument accuracy validation.

Known limits remain: sampled diagnostics do not cover every transform input; profile comparison is not measurement; unknown conditions cannot be recovered from a file name; FWA simulation is not measured M1; later use of verification colours as training changes their independence. Preserve the evidence needed to interpret a result rather than relying on the ICC file alone.

### Target and delivery implementation

Implementation: MeasurementDialog and measurementTargetInfo keep selection locked to the prepared session while exposing metadata and preview. ProjectWorkflow.savePrintCopy uses printDeliveryFolder and writePrintDeliveryInfo. Source TIFF hashes are checked after copying, receipt fields bind the original TI2/manifest and workflow identity, and the project history receives print-copy-saved. Folder naming uses project.name rather than printing.profileName.

---PAGE---
## Appendix D. Measurement-target identity and external print provenance

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


---PAGE---

## Appendix E Verification feedback and checked ICC delivery

### Read C3 feedback

Run Review feedback to open a readable feedback window. Reopen it with Open selected step results while feedback is selected. C3 files are verification-check.md and verification-check.json under targets/<target>/checks/<check>. Each check has its own folder. Compare reports with the same ICC and target; distinguish error against desired Lab from error against the ICC prediction.

### Approval and certificate are separate actions

Selecting a row navigates only. Run Open review and approval, review the results, tick the confirmation and save your assessment. Then select row 14, Save ICC and measurement certificate, and click Save ICC and certificate... Choose Also save copies elsewhere to select the bundle name and location. Save in project only keeps the delivery inside the project. A previous step-19 numerical-only export no longer hides this next step after print approval.

### The exact verified ICC is included

The external delivery folder contains <profile>-verified-original.icc, a byte-identical copy of the checked ICC. The normally named ICC has updated name metadata; an optional -v4.4.icc is a converted variant and is not the original verified file. delivery.json records verifiedOriginalICCFile and verifiedOriginalICCSHA256. Keep the whole bundle, including underlag.
