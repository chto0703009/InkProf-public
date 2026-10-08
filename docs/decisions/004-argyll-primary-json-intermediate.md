# 004 - Internal JSON and Argyll as primary exchange formats

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25. Updated: 2026-09-26. Status: data model decided. The target workflow and a measurement prototype exist; full measurement export remains.

## Decision

**JSON is InkProf's authoritative internal model for charts, measurements and derived results.** MATLAB uses structs and numeric arrays during computation. ArgyllCMS `.ti1`, `.ti2` and `.ti3` are the primary exchange formats. File adapters convert between these and the internal model, and imported originals are kept as provenance.

| Format | Primary role in InkProf |
|---|---|
| `.ti1` | Patch definition and device control values before layout. |
| `.ti2` | Final target definition with the patch placement, linked to the print image. |
| `.ti3` | Control values and measurement results, including spectra where available. |
| `.json` | Internal chart/measurement model, results, computation conditions, traceability and manifest. |
| TIFF16 | Printable image corresponding to the TI2. |
| Generic CGATS | Neutral exchange of source patches, physical layout and later measurement data; not the primary project truth. |
| TXF candidate | Optional compatibility file before measurement, when the values can be represented exactly; not approved until the recipient's layout has been verified. |

PXF/TXF/MXF/CMXF and other CGATS variants are handled through import/export adapters as these are implemented and verified; not all described formats are fully supported yet. They are not InkProf's primary working formats. The original files are nevertheless kept unchanged, for traceability and for information that the Argyll formats cannot represent.

## First delivery

```text
Argyll targen or imported patch definition
                  ↓
TI1 + JSON with import metadata and checks
                  ↓
Layout and optional randomization
                  ↓
TIFF16 + matching TI2 + CGATS exchange + JSON manifest
                  ↓
optional TXF candidate when precision and template allow
```

The measurement prototype reads the TI2 into `chart.json`, exports TI2 from JSON when chartread starts, and reads TI3 results into new JSON results. See the [measurement guide](../usage/chart-measurement.md). Full export of measurement results to other formats remains. Different measurement conditions are to be kept apart and, if needed, exported in separate files.

## Rules for JSON

The following are requirements for the schema to be defined during implementation:

- A versioned document type and schema.
- References to source files with content checksums, plus patch IDs and any order/position mapping.
- Stated channel names, units, value scales and wavelengths where needed.
- For colour computations: illuminant, observer, reference white, normalization and computation version.
- Numeric serialization that preserves MATLAB `double` on reload; this is to be tested. Export to another format's lower precision is reported separately.
- Missing values are represented by an explicit status and, if needed, `null`. JSON must not contain non-standard `NaN` or `Infinity` numbers.
- Derived results are kept separate from original measurements. A result does not replace its source.

Exported files must not become a competing project truth. Each export is bound to a specific JSON version, and imports are also bound to the original file's hash. A changed patch order, layout or quantization creates a new coherent set of files, and old computations must be identifiable as out of date.

## Information that must not be lost

TI2 and TIFF16 must have identical final patch placement, also after randomization. The JSON manifest additionally preserves the random seed, the tool version, and the actual mapping between logical patches and physical positions.

When measurements are converted, spectra are kept in the TI3 when the chosen export supports them. JSON and the original file can preserve further metadata, but an export that drops spectra must not be called lossless.

No conversion of coordinates, white point or RGB working space is to happen merely because the file format changes. Such computations are done separately and documented in JSON.

## Related documents

- [First delivery: TIFF16 and measurement files](../planning/first-delivery-target-tiff16.md)
- [Argyll's TI1, TI2 and TI3](../research/argyll-ti1-ti2-ti3.md)
- [Data exchange with i1Profiler and ChromIQ](../research/i1profiler-interchange/README.md)
- [Reuse of colour computations](../research/colorimetry-reuse-camera41-spectralab.md)
