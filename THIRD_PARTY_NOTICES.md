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
Rechecked: 2026-10-03.
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

Bitstream Vera supplied by ReportLab is embedded in measurement reports. The full [Bitstream Vera copyright and license](licenses/Bitstream-Vera.txt) is preserved. Internal ReportLab aliases in existing code do not make these Microsoft Arial font files. Current certificate PDFs use the unmodified bundled DejaVu Sans font; documentation also uses ReportLab’s unmodified Vera and Vera Bold. Font licence texts are attached to newly generated PDFs. Review font permissions when adding or changing fonts or distributing generated documents.

## External runtimes and source provenance

MATLAB is proprietary software from MathWorks, installed/licensed separately. Python's standard library and interpreter retain Python's own terms. Neither runtime is relicensed as InkProf code. No interpreter or proprietary runtime is distributed. The separately licensed DejaVu font is the only newly bundled binary resource in this preparation.

`bridge/spotread_bridge.py` records workflow/parser knowledge from SpectraLab v1.2.1-dev (`spotread_manual_measure.py`, `Parser.m`); that source's local LICENSE_NOTE declares GPL v3. The existing origin note is retained. Earlier project inventories reference Camera-41 and ChromIQ; a reference is not itself a source-code import. No ChromIQ source was copied in the recent ICC implementation. The local SpectraLab LICENSE explicitly selects GPL-3.0-or-later; both its LICENSE and shorter LICENSE_NOTE are preserved in licenses/spectralab. The bridge provenance note remains intact. The v1.0.0 review covers the current release tree, not a claim of legal clearance for every historical private artifact.

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

## v1.0.0 source preparation review (2026-10-03)

- Own MATLAB/Python/JavaScript source files now carry copyright, GPL-3.0-or-later identifiers and warranty references. [Source coverage check](tools/check_release.py) prevents missing notices in the release tree.
- DejaVu Sans is redistributed unmodified at `resources/fonts/DejaVuSans.ttf`, with its [exact embedded copyright and licence notice](licenses/fonts/DejaVuSans.ttf.notices.txt) and hash in `licenses/fonts/provenance.json`. It supplies the real Greek Delta glyph. No Microsoft Arial font is required by the handbook builder. The former Vera glyph remapping is removed. Legacy Ubuntu/Inconsolata notices are retained for older documentation history.
- The bundled PXF scaffold was rewritten as minimal InkProf-authored XML. It contains format identifiers and no copied vendor profile recipe, device serial or private calibration settings. InkProf round-trip tests apply. On 2026-10-03 Christer Törnkvist verified and accepted patch-set import/display of the replacement in i1Profiler using a round8 export: test name, patch count and colour swatches appeared as expected. The user subsequently confirmed successful printing and physical measurement for this test. Receiver re-export and exact equivalence to an earlier InkProf layout have not been reported. Exact receiver version and patch count were not reported. Users may supply their own compatible template. See the dated record in docs/usage/i1profiler-txf-export.md.
- The CxF3 XSD remains byte-identical to its separately licensed source, with the complete licence supplied.
- Colour-science datasets, NumPy/SciPy native libraries and Pillow bundled codecs are installed dependencies, not copied into this source release. Their preserved distribution notices remain applicable when packaging those actual dependencies.
- Standards, ICC specifications and referenced manufacturer documents are citations, not relicensed source imports. User measurements and third-party ICC files are excluded from the public release.

See [licensing review](licenses/review-v1.0.0.md) and [release scope](RELEASE_SCOPE.md). A source/notice audit does not determine every possible legal question about future binaries, services or contributions.
