# Third-party notices

InkProf's own code remains GPL-3.0-or-later; see [LICENSE](LICENSE). The following components retain their own copyrights and license terms.

## Pillow / Python Imaging Library

Used for image handling and the ImageCms interface. Installed version reviewed: Pillow 12.3.0.

- Copyright © 1997-2011 by Secret Labs AB
- Copyright © 1995-2011 by Fredrik Lundh and contributors
- Copyright © 2010 by Jeffrey 'Alex' Clark and contributors

License: MIT-CMU. Full copyright, permission, naming restriction and warranty disclaimer: [Pillow-MIT-CMU.txt](licenses/Pillow-MIT-CMU.txt).

Upstream: https://github.com/python-pillow/Pillow

## Little CMS (LCMS2)

Used through Pillow ImageCms for ICC profile reading and colour transforms. The installed runtime reports LittleCMS 2.19.

Copyright (c) 1998-2020 Marti Maria Saguer

License: MIT. Full notice from the installed Pillow distribution: [LittleCMS-MIT.txt](licenses/LittleCMS-MIT.txt). The copyright years above reproduce that bundled notice verbatim; they are not inferred from the installed runtime version.

Upstream: https://github.com/mm2/Little-CMS

InkProf does not explicitly activate LittleCMS's optional speed plug-ins. Their terms are separate from the core engine license.

## Bundled distribution notices and provenance

The complete, unmodified license file shipped with the reviewed Pillow installation is preserved as [Pillow-12.3.0-bundled-LICENSE.txt](licenses/Pillow-12.3.0-bundled-LICENSE.txt). It also contains notices for libraries included by that distribution; its inclusion does not mean InkProf directly uses every listed component.

Source within the installed package: `pillow-12.3.0.dist-info/licenses/LICENSE`.
Reviewed: 2026-09-27.
SHA-256: `dda12a98c1979cf3d94df1cff45d27a4cb3f04a60c76f76902ac54cac03ec0ce`.

When redistributing these dependencies, include their applicable notices and full license texts, including the bundled notices for the actual binaries distributed. Refresh these records when versions or packaging change. The inventory below extends this review to the installed Python runtime dependencies and selected external tools; it is not a complete legal clearance.

## Other installed Python dependencies

Complete notices copied without alteration from the installed distributions:

| Component | Reviewed version | Notice directory |
|---|---|---|
| Colour Science | 0.4.6 | [BSD notice](licenses/dependencies/colour-science-0.4.6/) |
| NumPy | 2.2.6 | [Core and bundled notices](licenses/dependencies/numpy-2.2.6/) |
| SciPy | 1.15.3 | [Core and bundled notices](licenses/dependencies/scipy-1.15.3/) |
| ReportLab | 4.4.3 | [BSD notice](licenses/dependencies/reportlab-4.4.3/) |
| ImageIO | 2.37.4 | [BSD notice](licenses/dependencies/imageio-2.37.4/) |
| typing_extensions | 4.16.0 | [PSF/history notices](licenses/dependencies/typing_extensions-4.16.0/) |
| charset-normalizer | 3.5.1 | [MIT notice](licenses/dependencies/charset-normalizer-3.5.1/) |

Pillow's full distribution notice is also inventoried under `licenses/dependencies`. Exact package versions, source paths and notice hashes are in [inventory.json](licenses/inventory.json). These full texts carry the respective copyright holder names and years; the table is not a replacement for them.

## ArgyllCMS – external programs

Author: Graeme W. Gill. The installed targen, printtarg, chartread, spotread, colprof, profcheck and xicclu report version 3.5.0 and AGPL Version 3. InkProf invokes these separately installed command-line programs; their binaries or source are not incorporated into InkProf by this notice.

Preserved from the installed distribution: [AGPL text](licenses/ArgyllCMS-3.5.0-AGPL.txt), [upstream ReadMe and author attribution](licenses/ArgyllCMS-3.5.0-ReadMe.txt), and [documentation terms](licenses/ArgyllCMS-documentation-license.txt). Upstream: https://www.argyllcms.com/ . Do not describe all Argyll versions/components as simply GPL. Redistributing Argyll binaries entails separate corresponding-source and notice obligations; notices alone do not fulfil them. A future combined distribution, modification, or hosted service needs review of its actual architecture and applicable terms.

## Fonts used by PDF reports

Bitstream Vera supplied by ReportLab is embedded in measurement reports. The full [Bitstream Vera copyright and license](licenses/Bitstream-Vera.txt) is preserved. Internal ReportLab aliases in existing code do not make these Microsoft Arial font files. Other ReportLab fonts are not selected by the current measurement-report routine. Review font permissions when adding or changing fonts or distributing generated documents.

## External runtimes and source provenance

MATLAB is proprietary software from MathWorks, installed/licensed separately. Python's standard library and interpreter retain Python's own terms. Neither runtime is relicensed as InkProf code. No runtime distribution is covered by this inventory.

`bridge/spotread_bridge.py` records workflow/parser knowledge from SpectraLab v1.2.1-dev (`spotread_manual_measure.py`, `Parser.m`); that source's local LICENSE_NOTE declares GPL v3. The existing origin note is retained. Earlier project inventories reference Camera-41 and ChromIQ; a reference is not itself a source-code import. No ChromIQ source was copied in the recent ICC implementation. This review is not an exhaustive line-by-line provenance determination of all historical code.

User-supplied ICC profiles, measurement data, vendor PDFs and screenshots retain their own rights. Local availability is not redistribution permission. They are not covered by InkProf's GPL declaration. Review each file's terms before including it in a release.

## Maintenance and remaining scope

Run `.venv/bin/python tools/check_license_inventory.py` to verify recorded versions and notice hashes. This check detects changes in recorded packages, not every new dependency, upstream dataset restriction, patent issue or license obligation. For new dependencies or copied/adapted routines, record source/version, preserve exact notices, check compatibility and update this inventory before redistribution.

Before distributing a packaged runtime, audit its actual wheel/native-library contents, dataset notices (including colour-science datasets), fonts and source obligations. MATLAB-linked/compiled distributions and any third-party GPL code adapted into MATLAB require review of the concrete combination; do not infer clearance from this document. InkProf's own GPL-3.0-or-later designation remains unchanged.

C1-flyttalskontrollen anropar LittleCMS offentliga C-API via Python ctypes. API-format och konstanter följer `lcms2.h` (https://github.com/mm2/Little-CMS/blob/master/include/lcms2.h); egen bryggkod ligger i `analysis/lcms_float.py`. Den använder installerat bibliotek, normalt det som följer med Pillow, och distribuerar ingen ny LittleCMS-binär. Befintliga LittleCMS-notiser gäller; vid annat systembibliotek måste dess version och licensmaterial granskas inför paketering.

## CxF3 XML schema

`schemas/cxf3/CxF3_Core.xsd` is X-Rite's CxF3 core schema, version 3.0.018,
redistributed **unmodified and in its entirety** with the
[CxF Schema Open License Agreement](licenses/cxf3/CxF_Schema_Open_License.pdf).
It is a separately licensed validation resource, not InkProf GPL code.
Its license requires preservation of the complete schema and delivery of the
license; do not modify or relicense the schema under GPL. Source revision and
SHA256 are recorded in `schemas/cxf3/provenance.json`. The distribution source
is the Colour Developers mirror; no Colour-CxF implementation or X-Rite SDK
code is included. InkProf's independently implemented reader remains GPL-3.0-or-later.
Validation of this schema is not a certification of every ISO 17972 workflow.

## Public v0.9 documentation fonts

The four presentation/workflow PDFs include embedded font subsets. Bitstream Vera notices are above. DejaVu Sans (Bitstream/Arev notices; DejaVu changes public domain), Ubuntu Bold (Canonical, Ubuntu Font Licence 1.0) and Inconsolata (SIL Open Font License 1.1) are used by the workflow guides. Exact embedded-font copyright/licence metadata, full licence texts and source/hash records are in [licenses/fonts](licenses/fonts/). These notices are also attached to the distributed PDFs. No standalone font binaries are included.

## Public snapshot exclusions

The private development fixtures and vendor screenshots with unresolved redistribution rights are excluded from v0.9 and from its public Git history. See [RELEASE_SCOPE.md](RELEASE_SCOPE.md). References in earlier research notes describe investigations, not bundled third-party data. Synthetic fixtures remain available for the public tests.
