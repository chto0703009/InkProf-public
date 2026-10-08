# Three real MXF reference cases for measurement import

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25. Status: XML content reviewed; no finished InkProf import, TI3 export or re-import into i1Profiler has been tested.

Christer has selected three files from i1Profiler's local data folders. Unchanged reference copies are kept under `tests/fixtures/i1profiler/mxf-examples/`. They are used as example data, not as evidence of a new instrument measurement or as InkProf code. The files' origin and any external rights remain.

## Content

| File | Target | Measurement groups | Actual values |
|---|---|---|---|
| `TC1617-CRPC-1.mxf` | 1,617 CMYK patches | M1: 1,617 objects | CIELAB, no spectra. |
| `Hm_WTu_23-11-23.mxf` | 1,445 RGB patches | M0, M1, M2: 1,445 objects each | 4,335 spectra, 36 bands per spectrum. |
| `Chart 2040 Patches.mxf` | 2,040 RGB patches | M0, M1, M2: 2,040 objects each | 6,120 spectra, 36 bands per spectrum. |

The files use the namespace `http://colorexchangeformat.com/CxF3-core`. All observed `ColorSpecification` references can be resolved to a specification in the respective file.

The two RGB files state `StartWL="380"` and `Increment="10"` in the specification's `WavelengthRange`. Together with 36 values this gives **380–730 nm in 10 nm steps**. This is read from these files, not a general assumption for MXF.

Observed spectral value ranges are 0.016680–0.939419 for the Hm file and 0.016108–0.934610 for Chart 2040, across all three groups. The values are preserved in the source's reflectance-factor encoding. A future conversion to percent must be explicit and verified against the CxF/TI3 contracts; min/max alone must not determine the scale.

## Important difference: declaration is not content

The TC1617 file declares `MeasurementType=Spectrum_Reflectance`, but has **no `ReflectanceSpectrum` elements**. Its 1,617 measurement objects contain `ColorCIELab`.

The importer must therefore check the actual value elements. The file can be used as a colorimetric basis when the reference conditions are established, but not for spectral modelling. Spectra must not be constructed from Lab and designated as measurements.

No explicit elements for calculation illuminant, observer or `ColorimetricSpec` were found in these three files. For the CMYK file's Lab, the reference conditions therefore need to be established from a verified producer convention or other basis. M1 is a measurement condition and does not replace this check.

## How the patches can be linked

Each target and measurement object has location data in the following structure:

```text
Object
  @Id, @Name, @ObjectType
  TagCollection @Name="Location"
    Tag @Name="Page"       @Value="..."
    Tag @Name="Row"        @Value="..."
    Tag @Name="Column"     @Value="..."
    Tag @Name="SampleID"   @Value="..."
    Tag @Name="SampleName" @Value="..."
```

This is **not an element called `Location`**. An importer must also recognise location data in `TagCollection`, otherwise the actual link is missed.

A check of all objects showed:

- The combination `(Page, Row, Column)` is unique within each target group and measurement group in all three files.
- Each measurement group has exactly the same set of positions as its target. The positions are also in the same list order in these particular files.
- In TC1617, `SampleID` values are unique 1–1617 within each group.
- In both RGB files **all `SampleID=-1`**. The field is therefore unusable as a sole linking key.
- The XML objects' `Id` values differ between target and measurement. For example, the first target object in Chart 2040 is `c6121`, whereas the first M0, M1 and M2 objects are `c1`, `c2041` and `c4081` respectively.

**Proposed adapter rule for these reference cases:** link per file/target and measurement group using the verified position key. Preserve object ID and original order as separate data. In case of duplicates or missing positions, the linking must stop or require another verified contract; do not automatically use row number or RGB as a substitute.

## Measurement conditions and repeated values

The RGB files have separate specifications with `M0_Incandescent`, `M1_Daylight` and `M2_UVExcluded`. They state XRGA and angle data of 0° illumination/45° measurement. This is what the files declare, not a new qualification of the instrument.

The groups must not be collapsed into a single measurement series. Nor are they three identical copies:

| File | Exactly equal spectra M0/M1 | Exactly equal spectra M0/M2 | Largest channel-wise difference M0/M1 | M0/M2 |
|---|---:|---:|---:|---:|
| Hm_WTu | 682 of 1,445 | 690 of 1,445 | 0.017078 | 0.029789 |
| Chart 2040 | 621 of 2,040 | 625 of 2,040 | 0.028971 | 0.050535 |

The comparison concerns numerical spectral values for corresponding positions. That some are identical does not in itself say why they are equal. Preserve them together with their measurement conditions; do not deduplicate away their meaning.

## Special information in the optimisation file

The Hm file is located in `OptimizationMeasurements` and contains `OptimizeProfile` with the path `/Users/christer/Library/ColorSync/Profiles/Hm_WTu_23-11-23.icc`. This is a profile reference in metadata, not the content of the embedded ICC profile. InkProf must preserve the reference as provenance without requiring the local path to exist in order to read the spectra themselves.

The RGB files' metadata state i1Pro 2 and the measurement objects are dated 2023-11-23. TC1617 states i1Pro with serial number 0 and date 2019-11-25. Since the files may contain delivered or previously imported data, these fields must be preserved as information from the file, not assumed to prove how or by whom the measurement was performed.

## Proposed conversions

- **TC1617 → TI3:** CMYK + Lab, without spectral columns. Establish the Lab reference conditions before profiling. Metadata claiming spectral measurement must not be used to report spectra as available.
- **Hm_WTu and Chart 2040 → TI3:** separate, spectral TI3 files for M0/M1/M2 with a JSON manifest that holds together the original, position link and conditions. Preserve all bands and an explicit value scale.
- **XYZ/Lab from the RGB files' spectra:** calculate with InkProf's planned own colorimetry routines with an explicit illuminant and observer, in a separate version-labelled result. The measurement's original spectrum is not changed.

This extends the reference basis for the measurement import but does not change the scope of the first delivery: target generation and TIFF16 come before integrated measurement and analysis.

## Proposed regression tests

1. Correct number of targets and measurements for each condition.
2. Position-based linking must work even if the list order of the measurement objects is changed in a test copy.
3. `SampleID=-1` must not merge patches or cause mislinking.
4. TC1617 is reported as Lab-based, despite the spectral declaration.
5. All 36 bands of every RGB spectrum and all three conditions are preserved on export and re-read.
6. The loss report shows any rescaling, derived colorimetry and metadata not transferred.

Original sources:

```text
/Library/Application Support/X-Rite/i1Profiler/ColorSpaceCMYK/Measurements/TC1617-CRPC-1.mxf
/Library/Application Support/X-Rite/i1Profiler/ColorSpaceRGB/OptimizationMeasurements/Hm_WTu_23-11-23.mxf
/Library/Application Support/X-Rite/i1Profiler/ColorSpaceRGB/Measurements/Chart 2040 Patches.mxf
```

See also the [MXF contract](mxf.md) and [common interchange rules](README.md).
