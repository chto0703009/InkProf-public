# Public release scope — v1.0.0 preparation

This prepares a source-only stable release (planned tag v1.0.0, internal version 1.0.0; publication pending), based on the separate public repository. Private development history is neither merged into it nor rewritten.

Download: [v1.0.0-rc.4 prerelease](https://github.com/chto0703009/InkProf-public/releases/tag/v1.0.0-rc.4). As of 2026-10-09, GitHub’s latest stable release remains v0.9; RC4 is the current testing release.

Excluded: local projects/measurements/ICC profiles, imported i1Profiler reference packages and real MXF fixtures, vendor screenshots, private historical datasets, machine settings, virtual environments, caches and external runtime binaries. Synthetic fixtures and original explanatory documentation figures are included. Some historical research notes refer to excluded data; they are not reproducible release tests. This private development repository still contains some of the excluded material (for example the real MXF fixtures in `tests/fixtures/i1profiler/` and the Chart 575 `reference.tif`); it is not copied to the public repository.

Separately licensed resources: complete unmodified CxF3 schema with its licence and provenance; unmodified DejaVu Sans font with full notice and hash. ReportLab's separately installed fonts are embedded in PDFs with notices. MATLAB, Python and ArgyllCMS must be installed separately. The root GPL licence does not relicense these dependencies.

Five current documentation PDFs have reproducible sources: Swedish/English presentations, Swedish/English user handbooks and the English MATLAB workflow guide. Existing private measurement certificates are not regenerated or included as release assets.

Only reviewed current source patches are copied between repositories. Do not merge private Git history into the public tree. Consult LICENSE_SCOPE.md, THIRD_PARTY_NOTICES.md and licenses/review-v1.0.0.md before adding source or assets.
