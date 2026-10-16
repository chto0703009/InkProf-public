# Changelog

## v1.2.0 — released 2026-10-16

- Add optional native M0 CGATS measurement delivery for i1Profiler through a main-window checkbox in rows 14/19, with provenance JSON and verified delivery copies. Import/profile creation tested with 2,200 patches in i1Profiler 3.8.5; document RGB rounding and cross-engine comparison limits.

- Add an optional offline 3D measurement viewer with fitting and current verification groups.
- Summarise up to 100 largest ΔE00 deviations above 1 in ascending order, with paired desired/measured swatches; retain all points and traceability in the English PDF supplement.
- Add a Swedish certificate PDF alongside English PDF/HTML, and deliver both PDFs and the separate supplement at the bundle root, including when re-exporting older packages.
- Use local timestamps, clearer bilingual wording, L* 40–60 verification plots and headings kept with their content. Right-align approval-table numeric columns.

## v1.1.1 - 2026-10-14

- Prefer creating a new C2 target when no saved target exists for the current ICC.
- Update both handbooks, both presentations and the MATLAB workflow guide; clarify later OBA/FWA activation and measurement resume instructions.

- Enlarge separate RGB print-control squares by 0.5 mm on each edge, with recorded measurement rectangles and labels following the geometry.

- Save completed measurement rows as immutable checkpoints and resume the same session with its original chart and scan settings. Checkpoints retain only whole physical rows; a save requested during a scan waits for the next prompt and excludes the row in flight. A half-completed paired row is omitted and reread on resume. Checkpoints never count as complete workflow measurements.
- Reuse approved RGB controls only after confirming the same physical print and validating the matching target; allow retry after cancelled or failed control checks.
- Continue at the following scan after a manually selected row is reread successfully.

## Documentation — 2026-10-13

- Review Swedish and English handbooks against current app behaviour: correct B2 smoothing choices, row references, automatic smoothing conditions, certificate appendices and initial-target budgets; clarify Photoshop handling and terminology.

## v1.1.0 — 2026-10-12

- Preserve portable HTML evidence links for both single- and double-quoted attributes, including the measurement appendix in external delivery bundles.

- Create a separate measurement appendix for numerical-only step 19 too, retaining complete historical measurement records and technical evidence, with matching certificate ID, ICC hash and appendix checksum. Keep historical ColorChecker swatches and the current scope in the main certificate.

- Keep named ColorChecker/reference swatch pairs and Delta E00 in the main certificate. Numerical-only certificates label earlier reference measurements as historical evidence, never verification of the current ICC.

- Explain failed iteration numerical checks with the specific alert, roundtrip maximum and C1/Grid report paths; recommend reviewing a stopped build rather than blindly repeating it.

- Recommend the next workflow step from valid project evidence and add a Go to suggested next step button. Prioritise measuring registered refinements, building the next iteration, and current ICC checks; offer verification and numerical-only alternatives explicitly.

- Automatically register reviewed gamut/shell TIFF16 packages as completed step 15 before offering print copies, so step 16 becomes ready without a separate selection-registration action.

- Handle change events as well as input in HTML Lab viewers; auto-rotation enters 3D directly. Add vertical drag rotation and touch handling to the profile comparison.

- Move complete measured-colour lists, diagnostic cards and technical history into a separate measurement-appendix.pdf, preserving certificate/ICC identity and a checksummed appendix record. Keep summary results in the customer certificate.

- Require complete RGB control definitions on every page and explicitly confirm the physical sheet when advancing to a new page during spot measurement.

- Extend printed R/G/B spot-control squares by one pixel on every side and record the actual rendered bounds.

- Register completed gamut/shell print packages in step 15 without regenerating the target, preserving printed patch order and unlocking step 16 after integrity checks.

- Keep elapsed activity visible during external print-package copying and checksum verification, including the main workflow print-copy action.

- Show elapsed activity in the foreground gamut panel while calculating patches and creating TIFF16; pause the timer during patch review/save selection and clean it up on completion or error.

- Offer another save location after creating a gamut refinement print package; keep project originals and verify copied files. Add a visible Close button to the gamut viewer.

- Fix paper-preview JSON encoding by excluding the runtime progress-window handle from target manifest options.

- Plot proposed gamut points and shell depths during review; show actual n³ changes and matching source/candidate RGB and L* gradient curves for ICC-grid trials. Save curve values with source ICC hashes.

- Group image, manual gamut/shell, verification-error and higher ICC-grid trials in Refinement tools. Grid trials preserve the source recipe and measurements, build a separate High/Ultra candidate and report actual source/candidate n³ table sizes.

- Add inner gamut shell patch sampling with adjustable ΔE76 thickness, whole-surface coverage, optional selected areas, and forward RGB candidates chosen to fill Lab gaps. Preserve the existing review, print and measurement continuation.

## v1.0.1 — 2026-10-11
- Show elapsed activity on the foreground paper dialog during TIFF16 preview generation and while finalizing C2 verification files.
- Allow remeasuring a selected RGB control or restarting all controls in the same window, retaining previous evidence and clearing superseded check approval.
- Move page RGB spot controls into the upper-right header and restore 16 mm of chart height for measurement rows.
- Clarify extra reference-target repeat patches and validate their limit before C2 generation.
- Step 8 displays elapsed-time activity on the matching visible result window while Grid and C1 checks prepare the next report, so an always-on-top result cannot hide the main-window progress indicator.
- Import required Python packages before analysis; full setup checks exercise SciPy spatial and sparse linear-algebra imports. Failed imports show the selected environment and repair instructions. Standard-library-only measurement remains supported.
- Pin SciPy 1.16.3 instead of 1.15.3 following the reported M4/Python 3.13 compiled-library failure and successful 1.16.3 import test. Update dependency notices and document repair of existing environments.

## v1.0.0 — 2026-10-10

Stable source release.

- Include sRGB original and ICC soft-proof gradient JPGs, a portable comparison page and exact delivered-profile hash in external certificate bundles.
- Name certificates after the profile and last eight iteration UUID characters; save external ICC, PDF, HTML and supporting evidence together in a folder named after the PDF, preserving older bundles.
- Preserve all three XYZ components when approving RGB print references decoded as column vectors; reject malformed scalar references before colour-error calculation.
- Show an activity dialog with elapsed time and Fit/Grid/C1 phase labels while step 8 runs; close it automatically on completion or failure.
- Allow step 9 to reselect an already printed verification target for the current ICC; verify saved package integrity and confirm target name and patch count before step 10 measurement.
- Include the selected ColorChecker/reference target in measurement certificates, with named reference and measured swatches and per-patch Delta E00 in PDF, HTML and text; retain reference-set identity in certificate JSON.
- Keep reference-patch fields consistent with the extra FWA paper-white control so ColorChecker C2 targets decode and render correctly in MATLAB.
- Restore the verified historical branch for remeasuring an existing refinement target, without reprinting or rebuilding; preserve downstream results when the same measurement revision is reselected or a measurement rerun is cancelled.
- Allow a reasoned override of completed RGB print checks with flagged deviations, retaining measurements, thresholds, paper finish and decision evidence; missing readings cannot be overridden.
- Add separate raw device R/G/B print-control squares to each new TIFF16 page, with stationary per-square M0 checks before strip measurement, approved printer/paper reference comparison and Failed status for flagged controls. Legacy targets without declared controls remain compatible.
- Recognize chartread's communication-error retry prompt and alternate strip-start prompts so measurement controls do not stay disabled.
- Show printed row numbers, pages and paired scan directions in the measurement window's instrument log instead of internal chartread pass numbers, and count instrument-confirmed scans so unread final sweeps are visible.
- Document manual gamut-area measurement reinforcement in both handbooks, with a step-by-step guide on page 56.

- Add gamut-area selection with approximate forward device-RGB associations, reviewed local patch proposals, and step 15–17 measurement/refinement continuation.
- Show the blue-sky diagnostic in a readable table with aligned values and metric explanations.

## v1.0.0-rc.4 — 2026-10-09

- Add v2, v4.4 and Both delivery choices, version conversion evidence and portable multi-version delivery.
- Preserve supported original v4 ICCs for LittleCMS verification; disclose approximate Argyll compatibility conversion.
- Update handbooks, figures, workflow diagrams, status explanations and ICC version guidance; rename the Swedish PDF and correct release links and layout.
- See [RC4 release notes](docs/releases/v1.0.0-rc.4.md) and VALIDATION.txt for scope and checks.

## v1.0.0-rc.3 — 2026-10-08

- Fix early Save/Cancel/Approve responses in project details and profile approval
  dialogs so they do not enter a new modal wait after dismissal.
- Fix RGB-definition import with MATLAB character-vector paths, preserving the
  filename and extension.
- Add bounded dialog test interactions and teardown checks; update ICC, portable
  HTML report and configurable paper-size tests to the current workflow.
- Record post-RC2 full MATLAB and UI follow-up separately from the published
  release validation in `docs/validation/rc2-follow-up.md`.

## v1.0.0-rc.2 — 2026-10-08

Substantial update since RC1; see [full release notes](docs/releases/v1.0.0-rc.2.md).


- **Clearer profiling and refinement choices.** Manual B3 runs the saved B2 recipe; Automatic creates its own candidate recipes. Error-driven refinement offers Argyll only or InkProf Jacobian sampling. Both build ICCs with Argyll; their patch selection and continuation settings differ.
- **Smoothing and gradients.** First-pass measurement pre-smoothing and final colprof smoothing have separate controls. Photographic-gradient checks cover source colour space, intent, BPC and numerical precision. Comparisons help assess colour accuracy alongside smooth transitions. Experimental InkProf grid/Hessian regularisation was removed after evaluation; old recipes using it must be replaced with a new B2 recipe.
- **Optical-brightener correction.** New native-M0 FWA recipes average measured white references, record variation and can request blank-paper measurement or an approved saved reference when white is missing. Compensation is applied once before the supported Argyll two-pass build. Original spectra remain preserved. This estimates D50 response; it is not a physical M1 measurement or calibrated UV-excitation measurement.
- **Legacy measurement compatibility.** Measurement overview now tolerates older revisions without the optional measurement-condition field.
- **More reliable measurement workflow.** Saved revisions remain selectable. Whole rows can be remeasured with the recorded page and forward/reverse direction. Page prompts identify row and direction, activity feedback is clearer, and Save does not initiate remeasurement.
- **Consistent ICC import.** Supported RGB printer profiles use a shared compatibility route; v4 conversion to the supported v2 path is disclosed and can be cancelled. Converted copies retain source identity; unsupported profiles are not silently accepted.
- **Rendering and target preparation.** Dedicated perceptual mapping can be configured alongside relative colourimetric support and media-white validation for absolute colourimetric use. C2 prepares the selected conversion once. TIFF companion instructions distinguish RGB pixel conversion from identifying embedded ICC metadata and state the application/driver settings explicitly.
- **Measured approval and fair reports.** The review dialog opens for explicit intended-use assessment. Certificates identify ICC, iteration, measurement revision, smoothing and FWA evidence. All assessed colours are presented alongside challenge, model-reachable and unresolved groups. Measured print versus desired colour is distinguished from previous versus current profile predictions. Numerical convergence or an unresolved inverse does not prove a physical gamut limit or ISO conformity.
- **Gamut and comparison views.** Iterations are labelled, L*, a* and b* axes are explicit, and PDF gamut sections use L*=50. HTML offers 2D/3D gamut and measured-point views with disclosed measurement-slice selection. Fixed comparison-table cell types and made saved numerical comparisons reopenable.
- **Current documentation.** Matching Swedish/English handbooks include a complete-profiling appendix and decision points. Swedish/English presentations explain the user benefit and print-system limits. Best-practice Markdown compares Argyll, Torger and i1Profiler guidance and links Keith Cooper’s printer test images. The test image itself is not redistributed.


## v1.0.0RC1 — public release candidate (1.0.0-rc.1, 2026-10-03)

- External ICC verification: balanced photographic patch selection with reserved skin tones and shadows, distributed neutrals/challenges, and recorded selection quotas; existing targets remain unchanged.

- Separate existing-ICC verification projects: seven steps, editable 575-patch TIFF16 target, physical measurement, two error comparisons and portable measurement certificates; original ICC bytes preserved.
- Complete 19-row project workflow with persistent JSON state, prerequisite checks, measurement revisions, result logs and iteration history.
- Central editable project/material/print settings, portable folders, renaming checks, dye/pigment ink type, printer coating and drying time.
- TIFF16-only print delivery, editable cut-sheet/roll suggestions, JSON sled limits, row labels on both sides and compact-page footer spacing.
- Instrument identity capture, startup/reconnect feedback and clearer patch remeasurement review. Measurement startup is guarded against reentrant callbacks and duplicate session locks have an actionable message. Temporary PTY/controller read unavailability now waits for the next event instead of aborting measurement; unexpected chartread failures are recorded in the session JSON.
- ICC recipe/build/checks, physical C2/C3 verification, image-guided refinement and C2 training data in subsequent iterations.
- Matte shadow strategy: editable sampling emphasis, numerical grid emphasis and up to 48 additional dark fitting patches per iteration.
- Common-sample ICC comparisons, default 2D L*=50, 3D points and a separate ICC gamut surface.
- Measurement certificates for print-reviewed or explicitly numerical-only scope; signature, references/explanations in Appendix A and legal terms in Appendix B; portable HTML folders.
- Updated Swedish/English presentations and workflow PDFs, Swedish handbook, installation and current usage index.
- Licensing review: source notices, full dependency notices, preserved provenance, redistributable font and PDF notices. Minimal independently authored PXF scaffold replaces older vendor settings; PXF patch-set import/display, printing and physical measurement with the replacement were verified and accepted by the user on 2026-10-03 (tested round8 export).

This is a public release candidate, not the stable v1.0.0. See VALIDATION.txt and docs/releases/v1.0.0.md. No new physical accuracy claim follows from automated tests.

## 0.9 — historical public snapshot

Initial public source distribution, separated from private development history and private reference datasets. Subsequent development is summarized above. Historical validation records apply to their original source state only.

- Measurement certificates now include a whole-target error distribution and
  every unique measured colour in HTML/PDF, while retaining large-deviation
  cards as explicitly labelled diagnostic details. Descriptive ranges are not
  acceptance limits; the documentation distinguishes C2/C3 print verification
  from Torger's profiling-data fit check.

- Verification-error refinement now offers Argyll only or the current
  InkProf method. The Argyll route uses preconditioned targen without Jacobians,
  persists the choice through continuation, and builds with colprof -r1.0 and
  no InkProf pre-regularization.

- Withdraw full-Hessian preprocessing from new profiling recipes/builds and
  comparison dialogs. B2 defaults to raw measurements with final Argyll -r0.5;
  refinement defaults to Argyll only. Existing ICCs and evidence are preserved;
  legacy Hessian recipes require a new B2 recipe before rebuilding.

- Manual B3 profile jobs show a cancellable indeterminate wait window with
  elapsed time and Argyll white-point, input-curve and final-CLUT stage messages.

- C3 now separates inverse round-trip, saved-RGB/TIFF pixel identity and actual
  TIFF-based profile prediction versus measured print. Includes per-patch
  diagnostics, explicit missing-evidence status and hashed TIFF/layout sources.

- ICC v4 RGB printer imports now offer Create v2 copy / Cancel before an
  approximate v2 reconstruction. Preserve original, conversion evidence and
  hashes; verify relative/absolute A2B differences on separate probes. Existing
  v2 imports remain byte-identical.

- Harmonize ICC v4 printer compatibility across import, verification import and
  Argyll target pre-conditioning. Use one consent dialog, reconstruction and
  hash-validated cached v2 profile; remove the former 11³ pre-conditioning
  surrogate implementation. Original inspection remains read-only.

- Fix C3 chain-summary display treating character arrays as numeric operands,
  which prevented the ColorChecker analysis window from opening after a
  successful measurement analysis. Summary text now uses scalar strings.

- Clarify print-target companion text: device RGB, ignore/discard the embedded
  ICC in Photoshop without conversion, disable all further print conversion,
  and distinguish identifying profile tags from an already-applied transform.

- Generate measured-print and numerical-only certificates in English, with an explanation of ICC model predictions versus measured print accuracy and physical gamut limitations. Preserve user notes and historical evidence in their original language.

- Standardise report gamut PDF figures to exact L*=50 mesh slices and HTML to selectable 2D/3D. Add actual measured-colour point views, distinguish them from ICC predictions, and include an HTML companion and verified target ICC gamut in measurement exports.

- Support native M0 white-averaged FWA integration before Argyll pre-smoothing and final fitting, with explicit blank-paper acquisition fallback and shared analytical/certificate provenance. Original data are preserved.
