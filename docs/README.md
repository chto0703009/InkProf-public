# InkProf documentation — v1.0.0

Source version **1.0.0**, updated 2026-10-10. Released 2026-10-10. Start with the [complete app workflow](usage/workflow-v1.0.md) and [release notes](releases/v1.0.0.md).

The Swedish and English user handbooks contain 60 numbered pages plus a cover. Covers identify the handbook, program, language, author, date and version. Five maintained PDFs are rebuilt for v1.0.0: both handbooks, both presentations and the English MATLAB workflow guide. Their links point to the public repository for source and release information.

Current additions include explicit verification-target selection, RGB print controls and reasoned overrides, ColorChecker certificate swatches, portable ICC/PDF/HTML/JPG delivery, shorter iteration identifiers and improved dialog handling. Historical development records retain their original dates and version references. The current handbooks take precedence over earlier screenshots.

Last published candidate: [v1.0.0-rc.4](releases/v1.0.0-rc.4.md).

## PDF guides

PDF layout updated 2026-10-10: handbooks have an illustrated cover with the author, language, date and version. Handbooks and presentations display version 1.0.0 and link to the public repository, https://github.com/chto0703009/InkProf-public. The stable release is [v1.0.0](https://github.com/chto0703009/InkProf-public/releases/tag/v1.0.0).

- [Swedish user handbook](usage/InkProf-anvandarhandbok-svenska.pdf)
- [English user handbook](usage/InkProf-user-handbook-English.pdf)

- [Swedish presentation](usage/InkProf-presentation-svenska.pdf)
- [English presentation](usage/InkProf-presentation-English.pdf)
- [InkProf-profiling-workflow-MATLAB-guide-English](usage/InkProf-profiling-workflow-MATLAB-guide-English.pdf)

Earlier release candidate notes: [v1.0.0-rc.4](releases/v1.0.0-rc.4.md). The current Markdown guides supplement the PDF handbooks, including the recently added external-profile verification workflow.

## Research notes

- [Pre-regularization, noise-matched smoothing and target placement methods (2026-10-06)](research/preregularization-and-target-methods-20261006.md)
- [ICC v2 and v4.4 for RGB printer profiles: v4 → v2 copy accuracy and v4 output (2026-10-09)](research/icc-v2-v4-compatibility-20261009.md)

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

- [Release notes](../CHANGELOG.md), [v1.0.0 release notes](releases/v1.0.0.md), [validation](../VALIDATION.txt).
- [Post-RC2 MATLAB and UI follow-up](validation/rc2-follow-up.md) — local fixes and checks after the published release.
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

Presentation editions: [Swedish](usage/InkProf-presentation-svenska.pdf) and [English](usage/InkProf-presentation-English.pdf), updated 2026-10-10 for v1.0.0. Both explain the physical print-system limits, gradient considerations, optional optical-brightener correction and handbook support. Page 7 also describes continued use of older i1Pro instruments through ArgyllCMS after X-Rite support ends, and the goal of operating beyond Rosetta removal with compatible native runtimes; future macOS compatibility still requires verification.

Current handbooks: 61 physical pages in each language, including the cover and 60 numbered pages, updated 2026-10-10 for v1.0.0. They explain installation, project steps, measurement checks, manual refinement, verification and certificate delivery.

Six original example figures illustrate the actual app: main window (page 7), Project details (9), Profiling settings and ICC delivery choice (11), measurement (14), profiling recipe (17), and gamut (34). Values are fictional; the gamut uses an sRGB ICC example, not a measured printer. The gamut export includes top margin to prevent title clipping. Blue callouts have 4 mm of additional space before following text or links.

The complete example has its own flow diagram on page 48, followed by the detailed route and supporting guidance on pages 49–55. Appendix headings describe their content; page 55 is “Testbilder” / “Test images”, followed by the manual gamut-reinforcement walkthrough on page 56. Author/source attribution remains in body text and references.

ICC import supports suitable RGB printer profiles in v2 and v4, including v4.2; generated delivery offers v2, v4.4 and Both. Pages 10–11, 16, 20 and 40 explain selection, variants, filenames, certificate scope and original-profile verification. Page 46 discusses version choice and a limited numerical LittleCMS/BPC example; it does not claim new print validation. See [project output settings](usage/profiling-project.md#delivered-icc-versions).

Earlier RC4 fact-check corrections included page references, FWA terminology and appendix headings. The v1.0.0 editions include subsequent workflow and delivery updates.

Current PDF footers link to the public repository. The stable release is available at https://github.com/chto0703009/InkProf-public/releases/tag/v1.0.0. The ICC specification link points to https://www.color.org/specifications/.

Manual gamut reinforcement: page 56 in both handbooks explains selecting an area in View gamut, reviewing device-RGB neighbours, saving paper dimensions, registering the selection in step 15, and printing/measuring/rebuilding in steps 16–17. It distinguishes manually strengthening measurement coverage from automatic error detection and physical gamut expansion; pages 21 and 34 point to the walkthrough.

RGB print checks: page 57 in both handbooks explains the stationary per-page controls before strip measurement, explicit approval of a known-correct reference, the default 5 ΔE00 threshold and Failed status for large differences. It stresses checking active Adobe Photoshop and driver settings even with presets, keeping controls outside profiling data, and compatibility with older prints without control squares. Page 13 points to the walkthrough.

Verification approval: page 58 walks through C2 target selection, printing, matching measurement revisions, C3/feedback, explicit approval with intended use and limitations, and exporting that decision in the certificate. Page 20 points to this guide.
