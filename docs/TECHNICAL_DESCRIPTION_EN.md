# InkProf - Technical description

Christer Törnkvist

christer@borgasundsfotografiska.se

https://github.com/chto0703009/InkProf-public

Version 1.4.2 | 2026-10-27 | GPL-3.0-or-later

Implementation, calculation chain and data contracts

This description covers version 1.4.2, released 2026-10-27. It follows the data from target definition through measurement, ICC construction, numerical diagnostics, physical verification and delivery. The handbook describes the operator's click sequence; this document explains what those steps mean and which files they depend on.

Older interface illustrations are explicitly identified as documentation examples. They show fictional projects, not measurements proving printer quality. File paths in the appendices are relative to the installation or project root; generated UUIDs and directory names vary.


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
| 13 | Appendix D. Target identity and print-copy provenance |
| 14 | Appendix E. Feedback and checked ICC delivery |
| 15 | Appendix F. Review, locking and corrections |
| 16 | Appendix G. Acquisition, cancellation and delivery |
| 17 | Appendix H. Gamut boundaries and extended targets |
| 18 | Appendix I. Measured Lab density and separate candidate |
| 19 | Appendix J. Activity, provenance and runtime |
---PAGE---
## Portable Python preparation

Startup checks the isolated Python 3.13.6 .venv. On macOS, Prepare can obtain a private interpreter in .python with checksum-verified tooling; system Python is unchanged. First preparation requires internet. Identify/check are read-only. A failed dependency installation restores the prior environment. See PYTHON_ENVIRONMENT.md. Original measurements and ICC profiles are preserved.


## 1. Architecture and scope

InkProf coordinates RGB output profiling for a specified printer, paper, ink and printing configuration. It does not control an analogue camera or profile a digital camera. Its printed RGB targets are distinct from a photographed ColorChecker. InkProf supports configurable printer patch sets without restriction to a particular photographed ColorChecker model.

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

Argyll alternatives use targen and may use an existing RGB printer ICC for perceptual point placement. An ICC v4 input automatically receives a separate approximate v2 compatibility copy. The original and conversion evidence are preserved. A cached copy is addressed by the original hash. The reconstruction uses a 17-cubed relative forward grid and inverse Bradford media-white adaptation; inverse tables and perceptual mapping are rebuilt. It is an approximation, not a version-byte edit.

Saving the definition creates TI1 plus JSON, without printing layout. Rendering subsequently creates TIFF16, TI2 and matching layout metadata. Ideal floating-point RGB and RGB16 quantisation are different records. Runtime figure references and callbacks are excluded from JSON.



Source map: `designRGBTarget.m`, `createTarget.m`, `+internal/drawPrintControls.m`, `analysis/gamut_refinement.py`.
---PAGE---
## 3. Measurement and colour-data conditions

The matching TI2/layout is essential: a measurement is not merely a list of Lab values. Patch IDs, location, RGB commands, completeness and available spectra/XYZ must remain linked to the printed target. Instrument prompts, calibration and strip direction are handled through the measurement workflow and Argyll bridge. Imported CGATS/TI3 or supported MXF data require matching identity and layout evidence.

![Measurement interface](docs/usage/handbook-source/examples/measurement-window.png)

Figure 1. Documentation interface example captured 2026-10-09 before instrument start. It does not demonstrate an actual measurement. Interface labels may differ from version 1.4.2.

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

C1 also checks deliberately damaged profiles as negative controls. Detecting those controls supports the diagnostic mechanism, not a blanket validation of all possible ICC defects. Measurement-noise propagation through refitting is not yet fully quantified.

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

New refinement targets reserve about one third of the shadow budget for neutral patches and one third for weakly coloured shadows (predicted C*ab up to 10); remaining slots cover other dark colours. With 48 available patches this normally gives 16 per group. Dense device-gray probes and small channel offsets supplement Argyll sampling. Unavailable quota slots return to the dark pool. Existing RGB16 colours are excluded. The receipt records policy and source ICC hash. The new target package contains device RGB without ICC conversion; its TI2 binds subsequent measurement to the next iteration. The current ICC only predicts selection; it is not applied to this print. Original targets and profiles remain unchanged. A fresh physical verification print is required to assess the candidate; more patches cannot guarantee a darker physical black.

The next profile build combines the approved training evidence and produces a new candidate. Shared-sample comparison of previous/current ICCs reveals numerical changes. Repeat the current profile's checks and preferably a new physical verification print to determine whether performance improved. Comparing two model surfaces cannot establish new measured print accuracy.

The numerical-only delivery route for a later iteration is explicitly different from print-verified delivery. It documents the available numerical evidence and limited scope. It does not invent missing verification or imply that an earlier print validates a changed ICC.

Source map: `proposeRefinement.m`, `continueRefinement.m`, `iterateProfile.m`, `refineVerification.m`, `analysis/shadow_patches.py`, `+internal/createRefinementPrint.m`. Exact routes are recorded in project evidence.
---PAGE---
## 8. Project state, integrity and delivery

`inkprof-project.json` holds project identity, printing settings, file inventory and history. `workflow.json` holds workflow state and artifact links. Project settings are not machine runtime configuration: local Python/Argyll locations do not become portable printer-characterisation data.

Ready means prerequisites are available. Complete means a result or decision has been saved for that row. Locked means a prerequisite is missing. Stale means a dependency changed and the previous result requires updating. None of these labels alone means that a print meets an intended accuracy requirement.

SHA-256 links identify exact input/output bytes. They can reveal substitution or accidental modification; they do not establish that an instrument was positioned correctly, that the printer settings were truthful or that a measurement was scientifically suitable. Unknown physical information must remain unknown. A new revision must preserve earlier evidence rather than silently rehashing unrelated changed files.

Delivery makes an explicit ICC copy and records source/delivery hashes. Interactive naming may update internal ICC description metadata, so a delivery copy can legitimately differ from the build candidate. Supported v2/v4.4 choices and version-conversion evidence must remain visible. Printer-profile construction and conversion are distinct operations.

Certificates and supplements identify measured conditions, selected profile and approval scope. HTML deliveries can depend on supporting files; move the complete bundle. Previously registered reports must not be regenerated in place: create a new workflow export. A digital certificate documents InkProf's saved evidence and operator decisions; it is not an accreditation or automatic standards-compliance claim.

Long calculations use elapsed-time activity and phase messages. Native file dialogs and user decisions are distinct from computation. Target design uses a separate v2 compatibility copy automatically when needed; other import routes can still require confirmation.



Source map: `ProjectWorkflow.m`, `updateProject.m`, `verifyProject.m`, `+internal/writeWorkflowFinalReport.m`.
---PAGE---
## Appendix A. Installation, dependencies and licence

| Component | Role and requirement |
| --- | --- |
| MATLAB | App, geometry and orchestration. Base MATLAB R2025b tested on macOS; do not infer Windows/Linux qualification. |
| Python | External worker process. Release 1.4.2 uses Python 3.13.6 in its own isolated .venv with the full pinned requirements; check/sync/rebuild use setup_python_environment. |
| ArgyllCMS | Updated macOS folder includes separately licensed ArgyllCMS 3.5.0 for ARM/Intel, with native startup checks. Other platforms need a compatible installation. Tools include targen, printtarg, chartread/spotread, colprof, xicclu and profcheck. |
| NumPy, SciPy, colour-science | Numerical and spectral analysis. Exact pins are in requirements.txt; `requirements-analysis.txt` references the same list. |
| Pillow / LittleCMS | ICC processing and comparison routes; original ICC and transform conditions matter. |
| tifffile, imagecodecs | RGB16 TIFF diagnostics and compressed TIFF support where required. |
| ReportLab | Report PDF generation, pinned in requirements.txt; `requirements-report.txt` references the same list. |

The program uses its own isolated `.venv` with Python 3.13.6 and pinned `requirements.txt`; analysis/report requirement files reference the same list. `setup_python_environment` checks, synchronises or rebuilds it. `setupInkProf(CheckPython=true)` checks setup and `startInkProfApp` opens the app. Native Python is preferred on Apple Silicon.

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
| targets/<ID>/ | Main-workflow C2 package: verification.json, definition/ and print/ |
| verification/<name-ID>/ | C2 package when the API has no explicit OutputFolder |
| <C2-package>/checks/<ID>/ | C3: verification-check.json and verification-check.md |
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

Primary implementation references are the source files named in each chapter. Paths without a prefix in those source maps are under `src/+inkprof/`. Public source and release: https://github.com/chto0703009/InkProf-public and https://github.com/chto0703009/InkProf-public/releases/tag/v1.4.2.

Detailed companion documents in the repository: `docs/usage/rgb-target-designer.md`, `docs/usage/workflow-v1.0.md`, `docs/usage/profiling-paths.md`, `docs/usage/profiling-best-practice.md`, `docs/usage/verify-existing-icc.md`, `docs/usage/measurement-certificate.md`, `docs/releases/v1.4.2.md`, `VALIDATION.txt` and the licence files. Some older guide headings retain historical version numbers; this document uses the v1.4.2 implementation baseline.

Historical validation for release 1.4.1 covered 59 targeted MATLAB tests and 29 Python tests. Current 1.4.2 startup and documentation checks are recorded separately in VALIDATION.txt and docs/releases/v1.4.2.md.

Historical evidence: release 1.2.2 had 23 targeted MATLAB checks. This older record does not describe the 1.4.2 test scope.

Known limits remain: sampled diagnostics do not cover every transform input; profile comparison is not measurement; unknown conditions cannot be recovered from a file name; FWA simulation is not measured M1; later use of verification colours as training changes their independence. Preserve the evidence needed to interpret a result rather than relying on the ICC file alone.

### Target and delivery implementation

Implementation: MeasurementDialog and measurementTargetInfo keep selection locked to the prepared session while exposing metadata and preview. ProjectWorkflow.savePrintCopy uses printDeliveryFolder and writePrintDeliveryInfo. Source TIFF hashes are checked after copying, receipt fields bind the original TI2/manifest and workflow identity, and the project history receives print-copy-saved. Folder naming uses project.name rather than printing.profileName.
---PAGE---
## Appendix D. Target identity and print-copy provenance

### Measurement-to-target binding

Workflow row 3 uses the base target TI2; row 10 (C2b) uses the selected C2 package TI2 and verification reference. A prepared session locks target selection. `measurementTargetInfo` derives patch count, target type, page count, timestamps and preview from that package. Missing historical metadata remain unknown. A recorded timestamp does not establish when the physical sheet was printed.

### Identity in copied packages

`ProjectWorkflow.savePrintCopy` creates a separate destination through `printDeliveryFolder`. Its name uses project name, current iteration, internal workflow row ID and local copy time; collisions produce a numbered folder. Project `name` and profile `printing.profileName` are distinct identities.

`writePrintDeliveryInfo` writes UTF-8 `PROJECT_INFO.txt` and structured `print-delivery.json`. They bind the copy to project ID, source package, TI2/SHA-256, printing settings, current iteration and historically recoverable target origin. Copied TIFF files are checked byte for byte. History records the copy without moving the original project.

### Iteration origin and physical traceability

A target may predate the iteration active at copy time. The receipt distinguishes target origin from copying when supported by history. Unknown facts remain unknown. Hashes identify files, not physical sheets or actual driver settings. An external TIFF copy does not replace original TI2/layout and measurement revisions.

Source map: `MeasurementDialog.m`, `+internal/measurementTargetInfo.m`, `ProjectWorkflow.m`, `+internal/printDeliveryFolder.m`, `+internal/writePrintDeliveryInfo.m`.
---PAGE---
## Appendix E. Feedback and checked ICC delivery

### C3 result location

`checkVerificationTarget` creates each check under `<C2-package>/checks/<check-ID>/`; the package is the directory containing `verification.json`. Reports are `verification-check.json` and `verification-check.md`. Main-workflow C2 packages normally reside under `targets/<ID>/`; the API default is `verification/<name-ID>/`. The same relative rule applies to both and to combined refinement packages.

C3 separates measured print versus desired Lab from measured print versus ICC prediction. `analyseVerification` produces feedback evidence accessible from the current workflow row or its saved results. Every new check gets a new ID rather than overwriting earlier checks.

### Decision and delivery identity

Selecting a row is navigation. `approvalDialog` stores an explicit intended-use decision after review. Row 14 collects evidence and approval into a new delivery revision. External copying does not change the identity of the checked ICC; row 19 has a separate numerical scope.

Delivery includes `<name>-verified-original.icc`, byte-identical to the checked ICC. A named delivery variant may have revised name metadata; a v4.4 variant is a documented conversion. `delivery.json` stores `verifiedOriginalICCFile` and `verifiedOriginalICCSHA256`. Registered certificates are not regenerated in place.

Source map: `checkVerificationTarget.m`, `analyseVerification.m`, `+internal/approvalDialog.m`, `ProjectWorkflow.m`, `+internal/writeWorkflowFinalReport.m`.
---PAGE---
## Appendix F. Review, locking and corrections

### State transitions and review boundaries

Row 4 retains the measurement preview until assessment continues. B1 validates the selected revision and saves a verified input snapshot only after modal confirmation. The workflow distinguishes opening a dialog from accepting and registering a result. Suggested navigation is B1, B2, B3; automatic B3 generates its own recipes.

Extra-patch parameters belong to refinement and subsequent iterations. The initial B3 build uses locked base inputs. C1 stores reports without opening successive result windows automatically. Saved result viewing is separate from the calculation that produced them.

### Documentation correction versus physical setup change

`Project details` distinguishes `Correct recorded details` from `Changed actual setup`. A documentation correction requires a reason and unchanged physical conditions. Original files are verified and audit history retains before/after values. This exception does not apply to numerical processing changes or automatically restore already stale results.

A physical setup change invalidates affected dependencies. A recorded correction cannot prove the conditions of a physical print; it documents the operator's statement and decision.

Source map: `ProjectWorkflow.m`, `projectDetailsDialog.m`, `+internal/executeWorkflowStep.m`, `+internal/workflowSteps.m`.
---PAGE---
## Appendix G. Acquisition, cancellation and delivery

### Instrument process and feedback

RGB controls, spot replacements and paper-white measurements share the start-sound principle for screen and i1Pro 2 instrument triggers. Calibration is a separate process state. RGB rows show page, colour and progress; page changes appear inline without another modal confirmation.

`SpotReadSession` and `readSpotLines` distinguish partial process output from complete prompts and readings. GUI polling must not block on an incomplete text line. Cancellation restores activity state while retaining saved requests, transcripts and measurements. Resuming a partial measurement requires the same physical print.

### Window lifecycle and copies

After `gamutPicker` receives a completed, registered target from `refineFromGamut`, it closes the gamut figure, including standalone entry paths. Cancellation or failure before completion leaves the figure available. External copying is separate from the project's target package and uses project/iteration identity; the source project is not moved.

### Delivery activity

Row 14 reports phase and elapsed time for evidence collection, figures/PDFs, ICC variants and verified copying. A completed certificate is a registered artifact; revisions use a new export. Activity describes operational progress, not colour accuracy.

Source map: `SpotReadSession.m`, `+internal/readSpotLines.m`, `+internal/gamutPicker.m`, `refineFromGamut.m`, `ProjectWorkflow.m`.
---PAGE---
## Appendix H. Gamut boundaries and extended targets

### Candidates around a modelled surface

`gamut_refinement.py` selects valid device RGB near the current ICC model's gamut mesh. Sampling can cover an inner shell, a selected region or both sides of the surface. Signed Delta E76 distance distinguishes inside from modelled outside. A negative distance does not establish a larger physical printer gamut. Minimum RGB spacing and the maximum new-point count constrain the candidate pool.

### Extension with preserved provenance

`gamutTargetExtension` identifies the latest completed compatible print package for the same ICC hash. Proposals without completed TIFF output are skipped. Existing fitting/development and supplementary shadow patches are retained; controls are regenerated. Exact duplicates and RGB already in training are excluded. Saved confirmed passes, TI3 output or a measurement revision containing RGB data block extension. Opening a measurement window alone does not block it.

### New complete target-package revision

Extension creates a new complete TIFF16/TI2 package with frozen roles and source references. Earlier files and measurements remain unchanged. Row 16 binds new readings to the new layout; row 17 builds a new profile from previous approved training plus the supplement. External copying defaults to Downloads. Cancelling the copy selection leaves the saved project package intact.

Source map: `refineFromGamut.m`, `+internal/gamutTargetExtension.m`, `+internal/gamutPicker.m`, `analysis/gamut_refinement.py`, `+internal/createRefinementPrint.m`.
---PAGE---
## Appendix I. Measured Lab density and separate candidate

### Grouping original observations

`measurement_density.py` groups nearby measured Lab with a complete-link rule limiting the extent of the entire group. RGB16 repeats and their Delta E00 spread remain distinct from different RGB producing similar Lab. Similarity may be consistent with saturation but does not alone determine its cause. Original observations are not deleted, modified or averaged.

### Selection and protected observations

Review parameters are Lab distance (Delta E76), target count per group and repeatability threshold (Delta E00). Defaults 1 / 4 / 1 are provisional. Checked groups use automatic representatives; unchecked groups retain every row. Neutral RGB, lightness/RGB extrema and inconsistent repeats remain protected. The target count is therefore not an unconditional removal requirement. Parameter changes require recalculation before building.

### Comparison on common evidence

`buildDensityTrial` creates a separate candidate from a documented subset. Building is blocked when no observations would be omitted. Original and candidate are compared against all original fitting observations, including omitted rows, available reserved development patches and matching photographic gradients. The candidate never automatically replaces the active profile. These diagnostics are not new independent print verification.

Source map: `reviewMeasuredDensity.m`, `buildDensityTrial.m`, `+internal/showMeasuredDensity.m`, `+internal/densityGroupSelection.m`, `analysis/measurement_density.py`, `analysis/density_comparison.py`.
---PAGE---
## Appendix J. Activity, provenance and runtime

### Activity and audit contracts

Density review and candidate builds report input verification, original snapshots, ICC construction, all-patch comparison, gradients, available development checks and saving. Parameters, checked groups, source rows and SHA-256 remain in separate review/trial records. Phases describe actual processing and remain distinct from waiting for user decisions.

### Isolated environment per program

Each program has its own `.venv` with Python 3.13.6 and the common pinned `requirements.txt`. `setup_python_environment` invokes the manager for `check`, `sync` or `rebuild`. Rebuilding preserves the previous environment as a backup and restores it on failure. A copied environment is not treated as a portable replacement for rebuilding on another computer. Projects and measured originals are separate from runtime state.

### Architecture and third-party tools

The program folder includes separately licensed ArgyllCMS 3.5.0 for ARM and Intel macOS. Architecture and actual executability are checked; native tools are preferred. `provenance.json` and original licences/notices identify bundled distributions. Source code, environment settings and measured data have distinct lifecycles.

Source map: `+internal/calculationProgress.m`, `setup_python_environment.m`, `tools/manage_python_environment.py`, `requirements.txt`, `+internal/argyllUsable.m`, `third_party/argyll/provenance.json`.
