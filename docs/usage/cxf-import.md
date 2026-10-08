# CxF3 import

> InkProf 1.0.0-rc.2, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

For RGB patch definitions, TI1/TI2 are recommended first, and generic CGATS from other programs. CxF is a complementary option, especially for structured metadata; see the [format priorities](cgats-import-export.md#recommended-import-formats-for-rgb-patch-definitions).

Implemented 2026-09-28. The reader is based on **ISO 17972-1:2015 / CxF3**. It validates with the unchanged CxF3 core schema 3.0.018 and checks values and references. This is not certification of all further CxF/X requirements or workflow parts in ISO 17972. CxF/X-4 for spot colours is not to be equated with general RGB target import.

```matlab
setupInkProf();
[data, jsonFile] = inkprof.readCxF( ...
    '/Users/christer/Desktop/InkProf-575-from-TI2-v2.cxf', ...
    OutputFile='/Users/christer/Desktop/InkProf-575-cxf.json');
```

OutputFile is optional; leave it out to read into memory only. Existing output is not overwritten. `inkprof.readCxF()` opens a file chooser. For a patch definition for target rendering:

```matlab
target = inkprof.importTarget('/Users/christer/Desktop/InkProf-575-from-TI2-v2.cxf');
inkprof.renderTarget(); % choose the same CxF as input
```

Rendering creates a **new** layout and matching measurement files. Do not use the new layout's TI2 for an older printed sheet.

## What is preserved and interpreted?

- **RGB** uses the CxF field MaxRange; if it is missing, CxF3's default of 255 is used. A contradicting RGBScale argument is rejected. Mixed MaxRange values are read in general, but require explicit normalization before target import.
- **Lab and XYZ** are kept as the file's values, linked to their ColorSpecification. No D50, observer, profile or measurement role is assumed when it is missing.
- **Reflectance spectra** are kept in the CxF scale: **1 = 100 %**. Values above 1 can occur, and no clipping is done; the schema allows the interval (-0.1; 3). Wavelengths come from the specification's StartWL/Increment, with any StartWL override on the spectrum. A missing wavelength definition is flagged, and no integration is done.
- **Object ID, name, ObjectType, colour specifications, profiles, metadata, custom resources and the original XML** are saved in JSON, together with the source file's SHA256. Colour types that are not interpreted numerically are kept, with a warning.
- **Rejected:** CMYK, per InkProf's RGB scope; DTDs and external entities; CxF1/CxF2. The semantic Python reader requires UTF-8.
- **Validation:** MATLAB Base validates the XSD with Java, and the Python standard library decodes the data. No extra Python package or X-Rite SDK is needed. A direct Python call explicitly marks `xsdValidated=false`; the public MATLAB routine validates first.

Generic CxF is read into a preserving JSON document, not automatically into a finished ICC measurement. Measurement conditions, RGB link and any physical layout must be sufficient before later export or profiling. The existing positioned MXF import keeps its own controlled workflow.

## Patch ID versus physical placement

The CxF object's ID is the colour's identity. The coordinate on the sheet is a separate link. To recreate a printed target unambiguously, you need the paper size, patch size, margins, number of rows and columns, placement order, any randomization, and empty positions. Dimensions alone are not enough.

The supplied `InkProf-575-from-TI2-v2.cxf` contains 575 RGB objects, no measurements and no individual patch coordinates. Its RGB values and order match the earlier PXF exactly. The Prism fields state, among other things, 0 rows/columns, 2 pages and i1Pro 3; they are kept as **source data, not verified information about the print or the instrument**. The actually known single-page layout comes from an earlier MXF. Its explicit positions may be linked to the CxF only after checking that the colour sequence is the same. Old spectra must not be copied into a new measurement.

A correct file adapter cannot improve the contrast of the printed sheet, or guarantee that chartread distinguishes similar neighbouring patches.

## PXF and standard sources

The PXF examples tested in InkProf so far are readable CxF3-based XML, not encrypted. The file extension does not determine the content, and other variants may exist. No decryption is included in InkProf.

- [ISO 17972-1:2015](https://www.iso.org/standard/61500.html)
- [X-Rite's CxF resources](https://www.xrite.com/page/cxf-color-exchange-format)
- [CxF3 schema and licence, Colour Developers mirror](https://github.com/colour-science/colour-cxf)
- Unchanged schema and exact origin: `schemas/cxf3/provenance.json`.
- Separate schema licence and attribution: `THIRD_PARTY_NOTICES.md`.

### Linking an existing print layout

`readCxF(..., LayoutFile=matchingMXF)` can link a CxF definition to explicit Target positions in a separate CxF3/MXF. The count, the RGB values and the whole order must match. No nearest-colour guesses, reorderings or old measurement values are used. Page numbers and coordinates are saved under `layout.mapping`, together with the source hash.

This is the user's choice of a matching print, not proof from RGB similarity alone. No empty fields become patches. This does not automatically create a chartread-compatible TI2 for irregular rows.

## Verified 2026-09-28

Six Python tests and four MATLAB tests passed. The user's 575 CxF passed XSD validation, and its RGB values and order match the PXF exactly. The explicit MXF layout gives 29 patches in rows 1–15 and 28 in rows 16–20. The whole flow CxF → target import → new TIFF/TI2 was tested in a working folder at 100 ppi. This is a software test, not a new print or physical measurement verification.

The source file and the JSON with the layout link are saved locally in `projects/Canon-575-20260927/sources/cxf-20260928/`.
