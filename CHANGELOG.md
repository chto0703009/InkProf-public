# Changelog

## Unreleased

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
