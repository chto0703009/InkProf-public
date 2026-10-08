# CGATS: exchange of colour and measurement data

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25

## What does CGATS mean?

CGATS stands for **Committee for Graphic Arts Technologies Standards**, a standardisation committee for graphic technology. In colour measurement contexts, the name is also used for text-based exchange formats for colour data. The committee and the file formats are thus not the same thing. [1]

A CGATS-based data file can describe patches, control values, colorimetric values and spectral measurements. It is a way of storing and exchanging data, not an ICC profile or an algorithm for colour conversion.

## Standards and variants

ArgyllCMS refers to the **CGATS.5 Data Exchange Format**, from Annex J of ANSI CGATS.5-1993. Argyll's `.ti1`, `.ti2` and `.ti3` use this basic structure with their own requirements on content. [2]

**CGATS.17** also appears as a designation for standardised text exchange of colour measurement data, among other places in X-Rite's documentation. [3] **ISO 28178:2022** defines the exchange of colour and process-control data and associated metadata in XML or ASCII text. It primarily covers spectral, colorimetric and densitometric data. [4]

These designations should not be treated as if all files were identical. Identifiers, field names, mandatory metadata and permitted extensions may differ. InkProf needs to state explicitly which variants are supported. This document is a practical overview, not a complete rendering of the standards.

## Structure of the text file

In Argyll's CGATS-based text files, the following main parts are used:

| Part | Meaning |
|---|---|
| File identifier | Indicates the variant, for example `CTI3` for Argyll's `.ti3`. |
| Keywords and values | Describe the file and how the data is to be interpreted. |
| `NUMBER_OF_FIELDS` | Number of columns in the table. |
| `BEGIN_DATA_FORMAT` / `END_DATA_FORMAT` | Delimit the list of column names. |
| `NUMBER_OF_SETS` | Number of data rows. |
| `BEGIN_DATA` / `END_DATA` | Delimit the table itself. |

Argyll uses, among others, `SAMPLE_ID`, `RGB_R`, `XYZ_X`, `LAB_L` and spectral fields such as `SPEC_500`. The column names indicate what the values mean; they must not be identified by position alone. [5]

### Illustrative example

The following is a small **synthetic example in Argyll's TI3 variant**. The values are invented and must not be used as calibration or profiling basis. The example contains XYZ, not spectra.

```text
CTI3
DESCRIPTOR "Synthetic RGB example - not measured"
ORIGINATOR "InkProf documentation"
DEVICE_CLASS "OUTPUT"
COLOR_REP "RGB_XYZ"

NUMBER_OF_FIELDS 7
BEGIN_DATA_FORMAT
SAMPLE_ID RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z
END_DATA_FORMAT

NUMBER_OF_SETS 2
BEGIN_DATA
1 100.0 100.0 100.0 90.0 93.0 76.0
2 50.0 50.0 50.0 20.0 21.0 17.0
END_DATA
```

Here the control values are percentages according to the TI3 convention. The value `50.0` must thus not be interpreted as 50 out of 255. For other variants and vendor exports, the value scales must be determined from their definitions. [5]

## Proposed import principles in InkProf

The following states the principles. A general table import/export is now implemented; see [API, tests and remaining limitations](../usage/cgats-import-export.md). Automatic format conversion and linking to the target remain:

1. **Identify the variant from the content.** The file extension alone is not sufficient.
2. **Read metadata and table structure.** Handle quotation marks, comments and any multiple tables according to the supported variant.
3. **Check field and row counts.** Deviations must be reported, not silently corrected.
4. **Preserve patch identities.** Link measurement to target through identifiers and documented layout, not merely row order. Repeated measurements must be distinguishable.
5. **Determine units and normalisation.** Distinguish, for example, between RGB 0–100 and 0–1, and between reflectance as a fraction and as a percentage. Do not guess from minimum and maximum values alone.
6. **Check spectral information.** Wavelengths, number of bands and values must be compatible before spectral calculations are made.
7. **Record measurement and calculation conditions.** Illumination and observer for XYZ/Lab must be distinguished from the instrument's measurement conditions. Missing information must be marked as unknown, or handled according to an explicitly documented format rule.
8. **Preserve the original and unknown metadata.** Save the source file unchanged. Document conversions to InkProf's internal representation.

An imported table must also distinguish between measured, estimated and simulated values. A well-formed file does not guarantee that its content is correct or physically measured.

## Connection to other documentation

CGATS describes the basis for data exchange. Argyll's `.ti1`, `.ti2` and `.ti3` give the files specific roles in the workflow: target values, target layout and measurement results. See the separate document **ArgyllCMS: the .ti1, .ti2 and .ti3 file formats** in the same documentation folder.

For InkProf, the main principle is to read established formats, normalise data in a controlled way, and preserve measurement conditions and traceability. The profiling itself takes place only after this interpretation and validation.

## Sources

1. [APTech: Committee for Graphic Arts Technologies Standards](https://printtechnologies.org/standards/) – the committee's name and role.
2. [ArgyllCMS: File formats](https://www.argyllcms.com/doc/File_Formats.html) – the CGATS basis and Argyll's formats.
3. [X-Rite: CxF Standard, Annex A](https://www.xrite.com/-/media/xrite/files/literature/misc/c/cxf_standard_en.pdf) – reference to ANSI CGATS.17-2005 as a text format for colour measurement data.
4. [ISO 28178:2022](https://www.iso.org/standard/82264.html) – the scope of the standard according to ISO's public description; the full standard text has not been reviewed here.
5. [ArgyllCMS: TI3 file format](https://www.argyllcms.com/doc/ti3_format.html) – structure, identifiers, fields and scales for TI3.

## Verified i1Profiler export

[The review of i1Profiler 3.8.5](i1profiler-interchange/ui-verification-3.8.5.md) shows a spectral CGATS.17 export with separate M0/M1/M2 files. RGB is 0–255, spectra are reflectance fractions with four decimals, and the field names are SPECTRAL_NM380 to SPECTRAL_NM730. This requires explicit scaling and field-name translation on TI3 export.
