# Shared target information in JSON and TIFF

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Introduced 2026-09-26. Import and generation use the same top-level field: **`targetInfo`**. This applies to imported PXF/TXF/CxF, TI1, TI2 and RGB CGATS, and to targets from Argyll and from InkProf's mesh refinement. Older files are not rewritten automatically.

## Shared structure

| Field | Content |
|---|---|
| `schemaVersion` | The version of the metadata format. |
| `source.fileName`, `source.path`, `source.format`, `source.sha256` | The source file's original name, full path, format and checksum. They are not replaced by the rendering step's temporary file names. Before your own target is saved for the first time there is no physical source file; on saving, the final TI1 file is recorded. |
| `source.declaredMetadata` | Information actually present in the source's CGATS header or XML attributes. It is kept apart from computed mesh measures. |
| `generation.method`, `generation.settings` | The known method and parameters. An ordinary import gets `unknown` as its method unless it can be substantiated; a file extension does not prove the generation algorithm. Own mesh attempts also save initial levels, the original mesh, parent relations, iteration history, gap conditions and stop reason. Argyll runs save their arguments and versions when available. |
| `patchCount`, `uniqueRGBCount` | Source patches and unique RGB. Layout padding is not included. The comparison of unique colours uses twelve decimals in normalized RGB. |
| `network` | Scope, number of points, unique points, affine dimension, number of channel levels, whether the full Cartesian product is present and whether the channel steps are uniform, number of cube corners and diagonal grays, and the number of Delaunay edges with the largest and mean edge length. A pure gray target is one-dimensional and gets no invented three-dimensional mesh measures. For own designs, the mesh measures are computed on the fitting points, without controls and repeats. |
| `footerText` | The short summary rendered in the TIFF. |
| `upstream` | Earlier metadata, when a re-import has an associated InkProf design JSON whose file hash matches. Method and roles from such a record are preserved; the mesh measures are computed for the RGB values actually imported. An identified but mismatched sidecar is rejected. |

Geometric RGB distances are not measured colour errors or ΔE. The default field says nothing about whether an unknown source file was actually generated with a regular grid.

## Where the same field appears

`targetInfo` is used in the import's target structure, `target.json`, the render package's layout JSON and manifest, the designer window's saved JSON and a newly created `chart.json`. The measurement import then carries the field forward if the session's chart JSON has it. A verification report does not need to duplicate this description.

The TI1/TI2 files keep their respective standard formats. On direct re-import of a saved designer TI1/TI2, the file hash is checked against the corresponding `<name>.json` before generation metadata is used. A standalone file without this sidecar is not an error: its actual RGB and declared metadata are used, but no unknown generation history is invented.

## TIFF footer

A centred summary is printed above the full TIFF path:

`Source: Chart 575 Patches.pxf | imported PXF | 575 patches / 569 unique | RGB edge max …`

For mesh refinement, the starting mesh and the number of additions are added, for example `start 5^3, +346`. For profile tests and verification targets, the line states the applied ICC (name and start of its hash), that it was applied absolute colorimetric without BPC, that the print is to be made with colour management off, and the reference set. Not every detail fits on paper; the rest is in `targetInfo`.

The information line is normally 7 points and is reduced to 6 if needed. If it still does not fit, only this supplementary line is shortened with an ellipsis; the full details remain in `targetInfo`. The TIFF path is never cut: a path that does not fit gives a clear error.

In current full-page Argyll targets the information line is centred about 17.3 mm and the path, date and page number about 12 mm from the bottom edge; the path can wrap to two lines. Targets narrower than 240 mm use 27 mm (information line), 19 mm (path, up to four lines) and 10 mm (date and page number). The fixed 263 × 195 mm page template keeps about 8.8 mm and 3.5 mm. Current Argyll rendering reserves 22 mm at the bottom, or 30 mm for widths below 240 mm. The native capacity is reduced accordingly; see [print geometry](target-print-standard.md). The fixed page template keeps its patch positions and image dimensions; the text must fit in its existing margin. All text is checked against existing image pixels before publication.

Both `createTarget` and `createTiff16` use the same metadata field and formatting routine. New prints must always be measured with their own TI2.

Separately saved mesh definitions use `definition.ti1SHA256` in the design JSON. Older combined packages with `print.ti1SHA256`/`print.ti2SHA256` can still be read. When rendering, the verified design JSON is also archived next to the source TI1, so that roles and the full mesh history remain in the print package.

## Planned feedback from measurement errors

Measurement-driven refinement is implemented as a separate workflow: [error-driven refinement](error-driven-refinement.md), [verification feedback](verification-feedback.md), and [automatic profile iteration](automatic-profile-iteration.md). These link observations to device RGB, preserve earlier measurements and propose additional patches. The geometric target generator itself does not acquire measurement-error feedback simply by generating a mesh; use the matching refinement API and role/identity checks.