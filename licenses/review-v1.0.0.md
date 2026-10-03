# Licensing review for v1.0.0 preparation

Date: 2026-10-03. Source: 1.0.0-rc.1. Owner/maintainer: Christer Törnkvist.

## Reviewed boundary

The current public source tree, dependency imports and locked requirements, first-party MATLAB/Python/JavaScript files, copied notices and hashes, CxF3 schema, PXF scaffold, embedded PDF fonts, documentation figures and excluded private data were inspected. GPL text is complete. Each first-party code file carries a licence notice; LICENSE_SCOPE.md covers authored non-code files.

## Corrections

Added source copyright/licence/warranty notices; preserved SpectraLab origin with its exact local licence declarations; replaced the system Arial requirement and modified Vera glyph maps with unmodified DejaVu; attached exact font notices to newly generated PDFs; replaced the vendor-derived PXF settings block with minimal independently authored exchange XML. Updated dependency inventory and added a source-release checker.

## Terms retained

InkProf: GPL-3.0-or-later. ArgyllCMS 3.5.0: external AGPLv3 programs, not bundled or relicensed. MATLAB: separately licensed proprietary runtime. Python and installed packages: their own terms. Pillow MIT-CMU; LittleCMS MIT; numerical/reporting libraries have their recorded distribution notices. CxF3 schema has its separate complete schema licence. DejaVu and Vera have their full font notices. Source-only distribution avoids pretending that these notices alone discharge obligations for redistributing external binaries.

## Limits and release follow-up

No declaration of universal legal clearance is made. Old private history is not part of the public source release. The public tree formerly contained a stripped vendor-derived PXF scaffold; the replacement removes that material from future source archives, but does not rewrite Git history. Do not infer redistribution permission for unrelated reference files. External i1Profiler receiver testing must be repeated for the new minimal PXF scaffold. Windows/Linux, all instrument modes and fresh dependency installation remain outside the demonstrated test scope.

## Verification

Run `python tools/check_release.py` for source notices, version, public file boundary and schema/font hashes. Run the analysis/report environment's `python tools/check_license_inventory.py` for installed versions and exact notice hashes. VALIDATION.txt records the actual test results.

Sources: [GNU GPL application guidance](https://www.gnu.org/licenses/gpl-howto.en.html), [GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html), [ArgyllCMS](https://www.argyllcms.com/). Licence statements are additionally checked against the preserved installed distribution texts; web references are not substitutes for those texts.
