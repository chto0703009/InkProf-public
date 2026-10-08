# Reference case: Chart 2033 Patches.txf

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Reviewed 2026-09-25. Supplements the [review of the PXF and TXT](chart-2033-inspection.md).

## Original and method

Christer provided `/Users/christer/Downloads/Chart 2033 Patches.txf`. An unchanged copy is kept in `tests/fixtures/i1profiler/chart-2033/` together with the PXF and TXT. The exact i1Profiler version has not yet been stated.

The file was read as XML and compared with the PXF at object level. This is file inspection, not XSD validation, re-import into i1Profiler or practical measurement verification.

## Patch content

- CxF3 namespace: `http://colorexchangeformat.com/CxF3-core`.
- Producer: `X-Rite - Prism`.
- Stated creation date: `2026-09-25T14:36:04+01:00`, preserved as written in the file.
- **2,033 target objects**.
- ID, name, object type, RGB values and object order are **exactly the same as in the PXF file**.
- The RGB values are thus integers on the 0–255 scale and have the same previously established truncation relationship to the TXT file.
- No `Location` elements and no `ReflectanceSpectrum` elements were found.

The TXF thus supplements the target with layout parameters but adds neither higher precision in the colour values nor any measurements.

## Concrete read paths in this reference case

```text
Namespaces:
  cc  = http://colorexchangeformat.com/CxF3-core
  xrp = http://www.xrite.com/products/prism

Patches:
  cc:CxF/cc:Resources/cc:ObjectCollection/cc:Object
    @Id, @Name, @ObjectType
    cc:DeviceColorValues/cc:ColorRGB
      @ColorSpecification
      cc:R, cc:G, cc:B

Layout parameters:
  cc:CxF/cc:CustomResources/xrp:Prism/xrp:CustomAttributes
    @NumberPatchColumns, @NumberPatchRows, @NumberPatchPages
    @PageWidth, @PageHeight, @PaperOrientation
    @PatchSizeWidthValue, @PatchSizeHeightValue
    @DimensionUnit, @ScramblePatches
```

The prefixes are examples; the implementation must match namespace and local name. The schema for private Prism resources has not been verified. The attribute names above are directly observed, not guessed.

## Layout metadata

| Attribute | TXF value | PXF value |
|---|---|---|
| `NumberPatchColumns` | 30 | 0 |
| `NumberPatchRows` | 23 | 0 |
| `NumberPatchPages` | 3 | 2 |
| `PageWidth` | 279.40 | 50.00 |
| `PageHeight` | 215.90 | 50.00 |
| `PatchSizeWidthValue` | 8.00 | 0.00 |
| `PatchSizeHeightValue` | 7.00 | 0.00 |

These are the seven changed attributes in `CustomAttributes`. Common values include `PaperOrientation="Landscape"`, `ScramblePatches="False"`, `DimensionUnit="2"` and `MeasurementDevice="i1Pro 3"`.

The page dimensions correspond to landscape US Letter if the unit is millimetres: 279.4 × 215.9 mm. The patch dimensions would then be 8 × 7 mm. This is a plausible interpretation of the size values, **not a verified general definition of unit code 2**. The unit must be confirmed against i1Profiler or a rendered original chart before physical reproduction.

The grid specifies 30 × 23 = 690 positions per page. Three full grids would have 2,070 positions, i.e. 37 more than the number of target patches. The file here does not give an explicit patch-by-patch map showing how these positions are used. They must not automatically be regarded as white patches or measurement patches.

## What we can now do

We have a real reference case for TXF reading as well: the patch list and the layout parameters above can be imported and preserved. This makes it possible to verify the reader against real PXF, TXT and TXF files from the same target.

We can create a **new** instrument-adapted layout and TIFF16 with the correct accompanying TI2. If the TXT is chosen as the source of control values, its higher numerical precision is used; if the TXF is chosen, the actual integer values are used. The files' values must not be silently mixed.

## What must still be verified for the same physical chart

- How the object order maps to row, column and page, including reading direction.
- How the last page is filled and whether extra control or padding patches are generated.
- Unit, actual start position, page header, gaps and identification marks. The stated zero margins do not prove that the target starts at the page's top-left corner.
- How i1Profiler uses defaults and instrument settings when the target is rendered.
- That a corresponding TI2 can describe a chart that chartread can measure with the chosen instrument.

A TIFF or PDF that i1Profiler generates from this TXF is a suitable next reference for the layout check. It is not needed to begin implementing the patch import, but is needed together with practical tests before we promise identical rendering and measurability in both programs.

## Conclusion for the implementation basis

The earlier statement that the TXF is missing no longer applies. What remains, however, is the difference between **import of observed layout parameters** and **verified reproduction of the original's complete print layout**. These must have separate status flags in InkProf.
