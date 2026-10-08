# CGATS import and export

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

## Warning: external prints without contrast markers

**Targets printed without contrast markers between the patches can cause problems in row measurement with chartread**, especially when neighbouring patches have similar colours. This can, for example, give errors with too few or too many patches. A correctly imported patch definition does not guarantee that the existing sheet can be read reliably.

**Recommended workflow:** import the patch definitions as TI1/TI2 in the first place, or as generic CGATS from another program, and let InkProf generate a new TIFF16 print with contrast markers and a matching TI2/JSON. Then measure with exactly that new print package's TI2. Contrast markers reduce the risk of segmentation problems but do not guarantee error-free sweeps.

An import or reordering in the program does not change a sheet that has already been printed. If the existing sheet is measured in another program, its measurement file can be imported separately with the patch link preserved.

InkProf can read and write CGATS text for patch definitions and measurement data. All tables, columns, text values and metadata are preserved. Argyll CTI1/CTI2/CTI3 and i1Profiler's CGATS.17 use the same reader. The file extension does not determine the content.

## Recommended import formats for RGB patch definitions

1. **TI1/TI2 are the first choice.** TI1 describes patch definitions; TI2 is used when an existing target description with patch positions should come along.
2. **Generic CGATS is recommended from other programs** when TI1/TI2 is not offered. A text file with, for example, the extension `.txt` can contain CGATS. Give the RGB scale explicitly according to the source, for example `RGBScale=255` for the tested export from i1Profiler.
3. **CxF, PXF and TXF are complementary options** for the supported variants. CxF can be suitable when more structured colour and measurement metadata need to be preserved.

The priority applies to patch definitions. Measurement data are handled separately, among other ways via TI3 and positioned MXF. No format in itself guarantees a print layout: a patch list without positions can be used for a new InkProf target with contrast markers, but it does not automatically describe a sheet that has already been printed. The original IDs, RGB values and relevant metadata are to be preserved on import.

## Patch definition to and from CGATS

```matlab
paths = setupInkProf();
target = inkprof.importTarget('my-definition.ti1');
inkprof.exportCgats('patches.cgats', target);

% Give the source's RGB scale explicitly: 100 for percent, 255 for 8-bit values.
folder = fullfile(paths.Projects, 'cgats-target');
inkprof.createTarget(folder, Source='patches.cgats', RGBScale=100, ...
    Paper='A3-portrait', Randomize=true, Seed=42, DPI=300);
```

Exporting an `inkprof.target` writes CGATS.17 with SAMPLE_ID, SAMPLE_NAME and the original RGB values with 17 significant digits. RGB_SCALE is saved as a separately declared keyword. Other programs do not need to understand this keyword; the scale must be agreed on when exchanging files. ImportTarget still requires an explicit RGBScale for generic CGATS. This patch list contains no physical layout.

`createTiff16` therefore writes two complementary CGATS files:

- `*-patches.cgats` contains the source patches in source order.
- `*-layout.cgats` contains the print's physical order, `SAMPLE_LOC`, an explicit padding flag and RGB values on the 0–100 scale.

The package's TI2 is still used for measurement; the CGATS files are neutral exchange and mapping files.

## Measurement data, including spectra

```matlab
doc = inkprof.importCgats('measurement-M0.txt');
data = inkprof.cgatsData(doc, RGBScale=255, SpectralScale=1);

% Example: the verified i1Profiler export uses 0–255 RGB
% and reflectance fractions. Do not assume these scales for other files without checking.
rgb = data.rgbPercent;
wavelengths = data.wavelengthNm;
reflectance = data.spectralFraction;

inkprof.exportCgats('measurement-copy.txt', doc);
```

`cgatsData` also gives `ids`, `locations`, `rgb`, `cmyk`, `xyz` and `lab`. With `XYZScale=100` or `XYZScale=1` you get `xyz100`. Without an explicit scale, the respective normalized matrix is empty; the raw numeric values remain. SpectralScale is used for reflectance/transmittance, not for emission units. Values above 100 % and small negative spectral values are not clipped.

SPEC_380 and SPECTRAL_NM380 are recognized as spectral fields. The numeric view sorts wavelengths in ascending order and keeps the link to the right values; the original table is not changed. Declared SPECTRAL_BANDS/START_NM/END_NM are checked against the columns. No spectral interpolation or conversion to XYZ/Lab is done.

M0/M1/M2, instrument, XRGA, observer and illuminant are preserved where they exist in the source's metadata. Missing conditions are not filled in. Several measurement-condition files are kept separate; the import does not merge measurements or link them automatically to a target. Repeated IDs are preserved, and `idsUnique` shows whether an unambiguous ID link is possible. CTI1/CTI2 colour values are marked as target estimates, not measurements.

## Several tables and your own data

`doc.tables(k)` contains `signature`, `metadata` (an ordered cell list of string vectors), `fields` and `data` (a string matrix). Change these to export processed data; the numeric values from `cgatsData` are a separate view. Use `compose('%.17g', values)` for new floating-point values in the table's data. `Table=2` chooses the next table in `cgatsData`. Argyll's helper tables are preserved, as are unknown fields and repeated KEYWORD lines.

`rawText`, the source path and SHA256 are saved in the document object for traceability. The original file is not changed. Keep the original together with the project's data; a source path alone does not make the project self-contained. Export never overwrites an existing file. It regenerates the row and field counts, reads the file back and compares the tables before the file is published.

## Limitations

- This is table-based CGATS text, not a full implementation of every CGATS/ISO variant. A signature is required for each table; arbitrary BEGIN/END extensions are rejected.
- Comments and the original whitespace are in rawText but are not recreated in the normalized export. Metadata and the data cells' text values are preserved.
- Strings with embedded quotation marks or line breaks are rejected explicitly.
- Exporting a CGATS document keeps its signature and field names. Renaming a CGATS.17 file to `.ti3` does not convert it to Argyll's format. Automatic dialect conversion, including i1Profiler spectra to TI3, is not part of this API.
- Numeric checks are done with cgatsData; the general document reader can also carry text columns and unknown data types without interpreting them.
- This does not replace a matching TXF export for measuring the same print in i1Profiler. Physical measurement and import in the receiving program have not been verified with these exports.

## Tests

`runtests('tests/testCgats.m')` tests:

- the three real i1Profiler exports M0/M1/M2 (2040 × 36 spectral values each),
- patch import/export with 2033 patches,
- several tables, Lab, repeated IDs and keywords, empty strings, comments and unknown metadata,
- faulty tables and spectra.

The existing target suite also tests Argyll's CTI1/CTI2 files with helper tables.
