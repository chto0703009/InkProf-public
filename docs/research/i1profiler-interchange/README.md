# Data interchange between i1Profiler, InkProf and ChromIQ

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25. Status: basis for implementation, not implemented format support.

## Purpose and scope

InkProf's [format decision 004](../../decisions/004-argyll-primary-json-intermediate.md) specifies JSON as the internal model and TI1/TI2/TI3 as the primary interchange formats. These i1Profiler contracts describe adapters to and from that workflow.

InkProf should be able to reuse targets and measurements from other programs and export data back. Import and export must distinguish between preserving measurement content and recreating a program's entire workflow. A file that can be opened is not automatically a lossless conversion.

This package contains four format descriptions:

- [PXF: patch set](pxf.md)
- [TXF: target and layout](txf.md)
- [MXF: control values and measurements](mxf.md)
- [CMXF: measurements of a target](cmxf.md)

They are practical read/write contracts for InkProf, not complete official X-Rite specifications. **Source-backed** means the statement is supported by the cited documentation; **code-observed** refers to the reviewed ChromIQ version; **proposed** states how InkProf should work. A first [practical verification in i1Profiler 3.8.5](ui-verification-3.8.5.md) has now been carried out: MXF import, spectral CGATS export and TIFF export. InkProf-generated files have not yet been compatibility-tested.

A real [reference case with 2,033 patches in PXF and CGATS-TXT](chart-2033-inspection.md) has been reviewed and shows a difference in precision between the files. The [corresponding TXF has now also been reviewed](chart-2033-txf-inspection.md): the same patch values as the PXF, supplemented with layout parameters. Full physical rendering and measurement compatibility remain to be verified.

## Common foundation: CxF3

The measurement import now also has [three reviewed MXF reference cases](mxf-examples-inspection.md). They show both spectral and colorimetric-only data, as well as the actual location information used for patch matching. Full export/re-import verification remains to be done.

X-Rite publishes the CxF3 XML schema and documentation. The core organises colour objects and their values in `Resources`. `CustomResources` use their own namespaces and can add application-specific meaning. The XML prefix, for example `cc`, is optional; the namespace URI and the element name identify the element. [S1, S2]

Examples of names that occur in the source material are `CxF`, `ObjectCollection`, `Object`, `DeviceColorValues`, `ColorRGB`, `ColorValues`, `ReflectanceSpectrum` and `ColorSpecification`. This is a reading guide, not a complete XSD. A reference to a colour specification must be resolved before scales, wavelengths or measurement conditions are interpreted. [S2, S3]

The open core of CxF3 does not mean that all i1Profiler extensions are fully publicly specified. BabelColor's AN-10 describes the four file roles, but is partly based on observations and applies to older i1Profiler versions. Full support must therefore be substantiated with version-labelled reference files. [S4]

## Proposed internal representation

Calculations between spectra, XYZ, Lab and other representations are described separately in [reuse of colour calculations from SpectraLab and Camera-41](../colorimetry-reuse-camera41-spectralab.md). The file adapters must not introduce their own parallel colour calculations. The calculation routines are to be part of InkProf, without a runtime dependency on the other projects.

The following names are InkProf's proposed internal concepts, not XML tags or external API contracts.

| Part | Information to preserve |
|---|---|
| Origin | Original file, checksum, producer, version, date and import log. |
| Patch | Internal identity, original ID, name and sequence number. |
| Control values | Channel names, channel order, original scale and normalised values. |
| Layout | Page, row, column, reading direction, dimensions and any randomisation. Unknown is recorded as unknown. |
| Measurement | Link to patch, own measurement ID, date, instrument and repetition number. |
| Spectrum | Wavelength vector in nm, values, quantity and scale. |
| Colorimetry | XYZ/Lab plus illuminant, observer, normalisation and measured/derived origin. |
| Measurement conditions | For example M0/M1/M2/M3, geometry and XRGA/GMDI where actually stated. |
| Extensions | Unrecognised metadata and XML resources, and their references to objects. |

Multiple measurement conditions and repetitions must be stored as separate measurements. The same RGB value can occur on several patches: the RGB triplet is therefore not a unique key.

## Proposed conversion paths

| From | To | Conditions and possible losses |
|---|---|---|
| PXF | TI1 | Preserve patches and control values. Any extra Argyll tables are generated by a verified tool flow. |
| TI1 | PXF | Encoding and rounding are chosen explicitly for the recipient. Estimated colorimetry must not become measurement data. |
| TXF | TI2 | Requires a verified translation of layout and instrument-related information. Otherwise a new target is created; the old one must not be used for strip measurement with the new layout. |
| TI2 | TXF | Requires more than a list of RGB values; the target program's layout must be verified. |
| MXF | TI3 | Pair control values and measurements reliably; export spectra when they exist. Separate measurement conditions where necessary. |
| TI3 | MXF | Requires known scales, metadata and a tested i1Profiler variant. Missing spectra cannot be recreated from XYZ/Lab. |
| CMXF + known target | TI3/MXF | Requires a verified link to the target's control values. |
| TI3/MXF | CMXF | A measurement-data export; the link to the control values must be stored separately if it is to be restorable. |

See also [the Argyll formats](../argyll-ti1-ti2-ti3.md) and [CGATS](../cgats-format.md). The table is InkProf's planned behaviour, not a guarantee for existing conversion tools.

## Common rules for reading and writing

1. Identify the XML variant, namespace and data content; do not rely on the file extension alone. The XML reader must not fetch external entities or arbitrary external schemas.
2. Preserve the original data. Normalisation is a traceable operation; the scale must not be derived solely from the largest observed value.
3. Check IDs, references, number of patches, channels and measurements. Order may be used for matching only when the ordering contract of the variant in question is documented and verified.
4. Missing metadata remains unknown. Do not state M0, an instrument name, a wavelength start or an interval merely because the recipient demands a value.
5. Separate the calculation illuminant/observer from the instrument's measurement condition. D50 and M1 mean different things. XRGA conversion is not a change of label.
6. Preserve all available spectra and measurement conditions in the project. When exporting to a more limited format, every omitted part must be reported.
7. Log every rounding, resampling, derived XYZ/Lab calculation and changed order. Do not introduce colour-space conversion of device RGB by mistake.
8. Unknown XML extensions are preserved in the original. They may accompany a modified export only if the object references are still valid; otherwise they are marked as not transferred.

## Loss report and verification

Each proposed conversion must produce a report of preserved data, derived data, rounding, losses, unresolved metadata and the chosen target variant. Distinguish between **byte-identical archiving**, **semantically equivalent measurement content** and **limited compatibility export**.

Minimum future test set:

- A small RGB set with different patch IDs, repeated RGB values and a controlled order.
- A layout with several rows/pages and a documented permutation.
- Measurement files with different measurement conditions, repetitions, Lab without spectra and spectra with explicit wavelength information.
- A file with incomplete metadata and one with unknown extensions: no silent guessing is allowed.
- Read → write → read: compare identities, values, scales, conditions and layout within a numerical tolerance stated in advance.
- Open the export in the actual i1Profiler/ChromIQ version. Check the patch count, selected values and physical reading order, not merely that the file is accepted.

Schema validation complements these tests but does not replace semantic checking or testing in the receiving program. The first version-bound UI review verifies certain original files and export paths, but not a finished InkProf adapter.

## Code observations in local ChromIQ

Reviewed revision: `92e6ead022fd57f4ecb80bf03670361b1b882247`, 2026-09-25. The observations apply to this code, not to all ChromIQ versions.

- `workflow/i1profiler_export.py`: the RGB export to PXF converts TI1's 0–100 to integers 0–255. This can change the control values and is not a lossless 16-bit path. CMYK and multichannel are handled by other branches and partly with estimated special values.
- `workflow/i1profiler_import.py`, `parse_pxf`: the reviewed patch import extracts RGB and proceeds to scaling; it is not a complete preserving import of XML resources, layout and measurements.
- `workflow/reference_convert.py`, `cxf_measurement_to_ti3`: links target and measurements by order, selects one measurement-condition group, assumes 10 nm intervals and 0–255 RGB. It calculates XYZ and writes TI3 without spectral columns.

**Consequence for InkProf:** a TI3 from the last-mentioned path is not sufficient to restore the original spectra. Preserve the original MXF/CxF and use a separate, verified spectral import. The assumptions above must not become general format rules in InkProf. No ChromIQ program was modified or run for conversion here.

Code references: [PXF export](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/workflow/i1profiler_export.py), [PXF import](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/workflow/i1profiler_import.py), [measurement conversion](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/workflow/reference_convert.py).

## Sources and open questions

- **S1:** [X-Rite: CxF resources and XML schema](https://www.xrite.com/page/cxf-color-exchange-format). A published schema exists; no local XSD validation has been done here.
- **S2:** [X-Rite: CxF3 Schema Overview](https://www.xrite.com/-/media/xrite/files/literature/misc/c/cxf3_schema_overview_en.pdf). Core resources and custom extensions. The indexed excerpt from the web search was available; direct PDF retrieval was denied during the review.
- **S3:** [X-Rite: CxF Standard 3.0](https://www.xrite.com/-/media/xrite/files/literature/misc/c/cxf_standard_en.pdf). Indexed examples and local ChromIQ code have been used for element names; a full normative field review remains to be done.
- **S4:** [BabelColor: AN-10, October 2013](https://babelcolor.com/index_htm_files/AN-10%20Exporting%20to%20the%20CxF3%20and%20i1Profiler%20file%20formats%20with%20PatchTool.pdf). Practical interoperability for older versions; no guarantee for current programs.
- **S5:** [X-Rite: i1Profiler release notes 1.6.3 and earlier](https://www.xrite.com/es/service-support/releasenotesfori1profiler163andprevious). Confirms file roles and import/export options.
- **S6:** [X-Rite: measurement data and CGATS export](https://www.xrite.com/es/service-support/measure_single_colors_with_i1profiler). Alternative path for interchange.

Before implementation, version-labelled original files are needed for all four roles, documented target programs and a decision on the first supported subset. The first target is proposed to be RGB reflectance; CMYK and multichannel are defined and tested separately. Specific XML requirements, defaults and private resources are then to be established from the XSD and reference files, not invented.
