# InkProf documentation — v1.0.0 preparation

Source version **1.0.0-rc.1**, updated 2026-10-03. Start with the [complete app workflow](usage/workflow-v1.0.md). App labels are English; the handbook is Swedish and the presentations/workflow PDFs are available in both languages.

## PDF guides

- [InkProf-anvandarhandbok](usage/InkProf-anvandarhandbok.pdf)
- [InkProf-presentation-English](usage/InkProf-presentation-English.pdf)
- [InkProf-presentation](usage/InkProf-presentation.pdf)
- [InkProf-profileringskedja-MATLAB-guide](usage/InkProf-profileringskedja-MATLAB-guide.pdf)
- [InkProf-profiling-workflow-MATLAB-guide-English](usage/InkProf-profiling-workflow-MATLAB-guide-English.pdf)

## Detailed usage

- [Förkortningar i InkProf](usage/abbreviations.md)
- [Automatisk profiliteration från mätning](usage/automatic-profile-iteration.md)
- [CGATS-import och export](usage/cgats-import-export.md)
- [Chartinläsning och interaktiv radmätning](usage/chart-measurement.md)
- [CxF3-inläsning](usage/cxf-import.md)
- [Felstyrd lokal förtätning](usage/error-driven-refinement.md)
- [Första implementationen: verifieringsrapport](usage/first-implementation-verification.md)
- [ICC gamut surface](usage/gamut-surface.md)
- [TXF-export till i1Profiler: experimentell implementation](usage/i1profiler-txf-export.md)
- [ICC-läsare A1](usage/icc-reader.md)
- [Image-guided refinement](usage/image-guided-refinement.md)
- [Instrument connection at startup](usage/instrument-startup.md)
- [Matte paper: additional shadow sampling](usage/matte-shadow-profiling.md)
- [InkProf - mätcertifikat](usage/measurement-certificate.md)
- [Import av mätfil inför analys och profilering](usage/measurement-file-import.md)
- [Optiska vitmedel: OBA, FWA och OBC](usage/optical-brighteners.md)
- [C1 – kompletterande numerisk profilkontroll](usage/profile-c1.md)
- [Compare successive profiles](usage/profile-comparison.md)
- [Profilkontroll – anpassningsfel per patch](usage/profile-fit.md)
- [C1 – RGB-nät, invers, gråramp och CMM-jämförelse](usage/profile-grid.md)
- [B1 – välj och lås profileringsunderlag](usage/profile-input.md)
- [B3 – separat profileringsjobb](usage/profile-job.md)
- [B2 – profileringsrecept](usage/profile-recipe.md)
- [Sammanhållet profileringsprojekt](usage/profiling-project.md)
- [Organisering av lokala projektdata](usage/project-organization.md)
- [Lokal och valfri Python-miljö](usage/python-runtime.md)
- [Fortsätta från uppmätt kompletteringsmål till ny ICC och C2](usage/refinement-continuation.md)
- [RGB-target: iterativ förtätning och Argyll-alternativ](usage/rgb-target-designer.md)
- [Scan direction and row-order diagnostics](usage/row-direction-check.md)
- [Spektral analys med Python](usage/spectral-analysis.md)
- [Skapa ett target med InkProf 0.1.4](usage/target-generation.md)
- [Gemensam targetinformation i JSON och TIFF](usage/target-metadata.md)
- [Paper suggestions and measurement-sled limits](usage/target-paper-planning.md)
- [InkProf – standard för utskrift av mål](usage/target-print-standard.md)
- [Testade plattformar / Tested platforms](usage/tested-platforms.md)
- [TIFF16-dialog för patchdefinitioner](usage/tiff16-dialog.md)
- [C3 – analys av en uppmätt verifieringsutskrift](usage/verification-check.md)
- [Verifieringsanalys som återkoppling till iterationen](usage/verification-feedback.md)
- [Roterbar Lab-vy av verifieringsmål](usage/verification-lab-3d.md)
- [C2 – oberoende verifieringsmål med applicerad ICC](usage/verification-target.md)
- [InkProf v1.0.0 workflow guide](usage/workflow-v1.0.md)

## Release and licensing

- [Release notes](../CHANGELOG.md), [preparation checklist](releases/v1.0.0.md), [validation](../VALIDATION.txt).
- [Licence and third-party sources](../THIRD_PARTY_NOTICES.md), [licensing review](../licenses/review-v1.0.0.md).

## Historical records

The planning, decisions and research folders retain dated development evidence, not a claim of current feature status or repeated validation. Some private reference datasets are deliberately excluded from the public distribution. [ISSUE-001](issues/001-inverse-measurement-noise.md), inverse sensitivity to measurement noise, remains open.

Existing ICC profiles can be tested in the separate **Verify existing ICC** project mode. See [Verify an existing printer ICC](usage/verify-existing-icc.md).
