# InkProf documentation — v1.0.0-rc.2

Source version **1.0.0-rc.2**, documentation updated 2026-10-08. Start with the [complete app workflow](usage/workflow-v1.0.md). The user handbook is maintained in matching Swedish and English editions, updated 2026-10-08. App labels and the other current usage guides remain English. Dated development records and original source citations are retained.

Current release: [v1.0.0-rc.2](releases/v1.0.0-rc.2.md). Earlier changes: [workflow update, 2026-10-07](releases/2026-10-07-workflow-update.md). The two user handbooks include the 2026-10-07 additions and a matching seven-page complete-profiling appendix (pages 38–44), added 2026-10-08. The presentation was aligned with the current handbook on 2026-10-08: smooth gradients, optional optical-brightener correction, measured final assessment and handbook support. It omits internal refinement-method choices. All five maintained PDFs are marked 1.0.0-rc.2; the MATLAB workflow guide remains a compact overview supplemented by the current handbook.

## PDF guides

- [Swedish user handbook](usage/InkProf-anvandarhandbok.pdf)
- [English user handbook](usage/InkProf-user-handbook-English.pdf)

- [Swedish presentation](usage/InkProf-presentation-svenska.pdf)
- [English presentation](usage/InkProf-presentation-English.pdf)
- [InkProf-profiling-workflow-MATLAB-guide-English](usage/InkProf-profiling-workflow-MATLAB-guide-English.pdf)

Release candidate notes: [v1.0.0-rc.2](releases/v1.0.0-rc.2.md). The current Markdown guides supplement the PDF handbooks, including the recently added external-profile verification workflow.

## Research notes

- [Pre-regularization, noise-matched smoothing and target placement methods (2026-10-06)](research/preregularization-and-target-methods-20261006.md)

## Detailed usage

- [Pre-regularisation of measurement data (experimental)](usage/pre-regularization.md)

- [Verify an existing printer ICC](usage/verify-existing-icc.md)
- [Profile test with a reference set (ColorChecker SG, Argyll, TI1)](usage/profile-test-reference-sets.md)

- [Abbreviations in InkProf](usage/abbreviations.md)
- [Automatic profile iteration from measurement](usage/automatic-profile-iteration.md)
- [CGATS import and export](usage/cgats-import-export.md)
- [Chart reading and interactive row measurement](usage/chart-measurement.md)
- [Remeasure one printed row](usage/row-remeasurement.md)
- [CxF3 import](usage/cxf-import.md)
- [Error-driven local refinement](usage/error-driven-refinement.md)
- [First implementation: verification report](usage/first-implementation-verification.md)
- [ICC gamut surface](usage/gamut-surface.md)
- [TXF export to i1Profiler: experimental implementation](usage/i1profiler-txf-export.md)
- [ICC reader A1](usage/icc-reader.md)
- [Image-guided refinement](usage/image-guided-refinement.md)
- [Instrument connection at startup](usage/instrument-startup.md)
- [Matte paper: additional shadow sampling](usage/matte-shadow-profiling.md)
- [InkProf - measurement certificate](usage/measurement-certificate.md)
- [Best practice for profiling and final print verification](usage/profiling-best-practice.md)
- [Importing a measurement file for analysis and profiling](usage/measurement-file-import.md)
- [Optical brighteners: OBA, FWA and OBC](usage/optical-brighteners.md)
- [C1 – supplementary numerical profile check](usage/profile-c1.md)
- [Compare successive profiles](usage/profile-comparison.md)
- [Profile check – fit error per patch](usage/profile-fit.md)
- [C1 – RGB grid, inverse, gray ramp and CMM comparison](usage/profile-grid.md)
- [B1 – select and lock the profiling input](usage/profile-input.md)
- [B3 – separate profiling job](usage/profile-job.md)
- [Accuracy and gradient quality](usage/profile-quality-tradeoffs.md)
- [B2 – profiling recipe](usage/profile-recipe.md)
- [Self-contained profiling project](usage/profiling-project.md)
- [Organizing local project data](usage/project-organization.md)
- [Local and optional Python environment](usage/python-runtime.md)
- [Continuing from a measured supplementary target to a new ICC and C2](usage/refinement-continuation.md)
- [RGB target: iterative refinement and the Argyll alternative](usage/rgb-target-designer.md)
- [Scan direction and row-order diagnostics](usage/row-direction-check.md)
- [Spectral analysis with Python](usage/spectral-analysis.md)
- [Creating a target with InkProf 0.1.4](usage/target-generation.md)
- [Shared target information in JSON and TIFF](usage/target-metadata.md)
- [Paper suggestions and measurement-sled limits](usage/target-paper-planning.md)
- [InkProf – target print standard](usage/target-print-standard.md)
- [Tested platforms](usage/tested-platforms.md)
- [TIFF16 dialog for patch definitions](usage/tiff16-dialog.md)
- [C3 – analysis of a measured verification print](usage/verification-check.md)
- [Verification analysis as feedback to the iteration](usage/verification-feedback.md)
- [Rotatable Lab view of a verification target](usage/verification-lab-3d.md)
- [C2 – independent verification target with the ICC applied](usage/verification-target.md)
- [InkProf v1.0.0 workflow guide](usage/workflow-v1.0.md)

## Release and licensing

- [Release notes](../CHANGELOG.md), [preparation checklist](releases/v1.0.0.md), [validation](../VALIDATION.txt).
- [Licence and third-party sources](../THIRD_PARTY_NOTICES.md), [licensing review](../licenses/review-v1.0.0.md).

## Historical records

The planning, decisions and research folders retain dated development evidence, not a claim of current feature status or repeated validation. Some private reference datasets are deliberately excluded from the public distribution. [ISSUE-001](issues/001-inverse-measurement-noise.md), inverse sensitivity to measurement noise, remains open.

Existing ICC profiles can be tested in the separate **Verify existing ICC** project mode. See [Verify an existing printer ICC](usage/verify-existing-icc.md).

Accuracy and gradient diagnostics: [candidate comparisons, photographic conversion and repeat weighting](usage/profile-quality-tradeoffs.md).

## Documentation scope and recent changes

Usage guides describe the current workflow; research, planning and dated release documents retain their historical/proposal scope. For changes made on 2026-10-07, use [profile quality tradeoffs](usage/profile-quality-tradeoffs.md), [B2 recipe](usage/profile-recipe.md), [TIFF ICC handling](usage/tiff16-dialog.md#icc-conversion-and-the-embedded-tag), and [certificate evidence](usage/verification-check.md#certificate-regularization-evidence). Historical proposals are not a list of implemented features.

- [Profiling paths, regularisation and refinement](usage/profiling-paths.md)

## Complete-profiling appendix and source guidance

The [best-practice guide](usage/profiling-best-practice.md) and both handbook appendices cover existing-ICC preconditioning, patch budgets, unmanaged target printing, measurement revisions, OBA decisions, B2/B3 settings, Argyll/Jacobian refinement, stopping and fresh final verification. Recommendations are distinguished from software defaults and standard requirements. The source comparison includes Torger’s printer tutorial, X-Rite’s i1Profiler RGB workflow, Argyll documentation and Fogra verification guidance. External workflows do not establish a measured superiority of one InkProf refinement method.

Photographic assessment resource: [Keith Cooper — Printer Test Images, Northlight Images](https://www.northlight-images.co.uk/printer-test-images/), including the Datacolor test image available courtesy of Datacolor. See the best-practice guide for sky-gradient checks and the distinction between source photographs and prepared device-RGB targets. The image itself is not included in this repository.

Presentation editions: [Swedish](usage/InkProf-presentation-svenska.pdf) and [English](usage/InkProf-presentation-English.pdf), updated 2026-10-08. Both explain the physical print-system limits, gradient considerations, optional optical-brightener correction and handbook support.
