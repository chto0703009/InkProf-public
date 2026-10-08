# Reuse of colour calculations from SpectraLab and Camera-41

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25. Status: inventory and proposed integration contract; no InkProf integration is implemented here.

## Purpose

InkProf is to have its own, shared and verified colour calculations, without a runtime dependency on SpectraLab or Camera-41. The inventory is a knowledge base and a list of possible licence-checked code sources, not a list of necessary installations. File conversion and colour calculation are separate operations. An exported file should normally reproduce already interpreted data, not recalculate colours without an explicit calculation decision.

This inventory is based on reading local code in SpectraLab v1.2.1-dev and Camera-41 v0.9.0-dev. It shows which routines exist, but does not mean that their full dependencies or numerical correctness have been retested. In any code adaptation, the original version and licence are to be documented; routines and test data are to be included in InkProf.

## Identified routines

| Need | Existing routine | Contract and limitation in reviewed code |
|---|---|---|
| Reflectance and illumination to XYZ, xyY and Lab | `spectralab.analysis.colorimetry` | Takes spectral objects/collections/archives and an explicit illuminant SPD. A common reference white scale preserves the patches' relative lightness. `CIE1931_2` is now supported. |
| Spectral integration to XYZ | `spectralab.analysis.xyz` | Integrates with CIE 1931 2° functions. A lower level than the complete reflectance calculation. |
| XYZ to Lab | `spectralab.analysis.lab` | Requires sample XYZ and reference white XYZ in canonical structures with the same normalisation. |
| XYZ to xyY | `spectralab.analysis.xyY` | Preserves Y; zero or invalid tristimulus sum is rejected. |
| Chromatic adaptation | `camera41.profile.adaptXYZWhitePoint` | Bradford with explicit source white point and selectable target white point; the default target is D50. |
| Colour difference | `camera41.negative.deltaE00` | CIEDE2000 between corresponding finite Lab rows. This is an error measure, not a colour space conversion. |
| XYZ D50 to linear ACEScg | `camera41.negative.convertXYZD50ToACEScg` | Adapts to D60 and uses AP1 primaries. No clipping or tone curve. Exists for possible image workflows, not as a general printer inverse. |

The inventory is not a claim of support for all inverse conversions. Lab → XYZ, xyY → XYZ, arbitrary observers and arbitrary RGB working spaces need to be inventoried or implemented and verified separately when required.

## Critical normalisation rule

SpectraLab's reviewed reflectance path stores reflectance factor in percent and calculates with `r = R / 100`. It weights with the chosen illuminant and the colour-matching functions. The same scale factor, determined by the illuminant's reference white, is used for all patches:

```text
sample-SPD = r(lambda) * S(lambda)
white-SPD  = S(lambda)
k          = 100 / Y_white_raw
XYZ_sample = k * XYZ_sample_raw
XYZ_white  = k * XYZ_white_raw
```

**Do not normalise each patch separately to Y = 100.** The lower level's `xyz(..., Normalization="Y100")` does exactly a normalisation of the individual input and must therefore not be used directly for each reflectance patch. The lightness differences would then disappear. Use the collective reflectance path and an explicit illumination spectrum.

## Proposed calculation contract in InkProf

- Preserve the original spectrum, wavelengths, quantity and scale. Document any resampling and integration range.
- State illuminant SPD, observer, reference white and XYZ normalisation together with the result. The reviewed implementation does not automatically support, for example, 10° just because the format can describe it.
- Preserve imported XYZ/Lab as original data. New calculations create a separate, version-marked representation and do not overwrite the original.
- Separate instrument-reported colorimetry from the canonical calculation. SpectraLab's behaviour without an explicit illuminant is a special path; InkProf should provide an explicit SPD for reproducible reflectance calculations.
- Distinguish a recalculation of the same coordinates from chromatic adaptation. Calculation under a different illumination from spectra and Bradford adaptation are different operations.
- Use only comparable Lab values for ΔE00 and state the reference conditions. The function's mathematical input check does not replace this semantic check.
- Preserve device RGB as control values. Do not automatically treat them as sRGB, ACEScg or any other standardised image space.
- A colour calculation to standard RGB does not replace inversion of the printer's measured forward model or an ICC transform.
- Save calculation version, inputs used and function version. Exporters serialise the result; they must not have their own hidden colour calculations.

Measurement conditions such as M0/M1 and calculation illumination such as D50 are to be recorded separately. The reflectance calculation does not in itself mean that a measurement workflow is qualified according to a particular measurement condition.

## Integration and verification

According to [decision 007](../decisions/007-independent-inkprof.md), the calculation routines are to reside in InkProf. Knowledge or licence-compatible code from earlier projects may be reused with an origin notice, but their APIs must not become runtime dependencies. Own colorimetry is planned and not completed in this documentation task.

Proposed acceptance tests before implementation (also on an installation without the other projects):

1. An ideal reflectance of 100 percent gives the same XYZ as the reference white. A constant 50 percent reflectance gives half the XYZ under the same conditions.
2. The same sample gives the same colorimetry regardless of whether it comes from MXF, TI3 or a SpectraLab archive, when spectra and conditions are equal.
3. XYZ/Lab and adaptation are verified against independent reference values. Also check zero, neutral colours and relevant edge cases.
4. ΔE00 is verified against a published reference set; comparison with itself is not enough.
5. Read/write cycles preserve original data. Rounding and changes in derived coordinates have stated tolerances.

## Code basis for the inventory

Local source roots at the time of review:

- SpectraLab: `/Users/christer/Desktop/SpectraLab/SpectraLab_v1.2.1-dev`
- Camera-41: `/Users/christer/Desktop/Camera-41/Camera-41_v0.9.0-dev`

Files relative to each root:

```text
SpectraLab:
  docs/REFLECTANCE_COLORIMETRY.md
  spectralab/+spectralab/+analysis/colorimetry.m
  spectralab/+spectralab/+analysis/xyz.m
  spectralab/+spectralab/+analysis/lab.m
  spectralab/+spectralab/+analysis/xyY.m

Camera-41:
  src/+camera41/+profile/adaptXYZWhitePoint.m
  src/+camera41/+negative/deltaE00.m
  src/+camera41/+negative/convertXYZD50ToACEScg.m
```

The document complements the [data interchange contract for i1Profiler and ChromIQ](i1profiler-interchange/README.md). The format descriptions state how data is stored; this document states which existing calculations can be reused and under what conditions.
