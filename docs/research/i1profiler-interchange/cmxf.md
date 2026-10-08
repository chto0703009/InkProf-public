# CMXF: i1Profiler Chart Measurements

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25. Status: preliminary read/write contract for InkProf.

## Source-backed role

`.cmxf` files are CxF3-based target measurements with Lab and/or spectra, without the patches' RGB/CMYK control values. Layout and a colour-space label may nevertheless be present as extra information; the label does not replace the control values. [S4] See [common rules, sources and limitations](README.md).

## Proposed meaning in InkProf

CMXF is imported as a measurement package. It can be used for spectral or colorimetric analysis even if it is not yet linked to a target definition. To build a printer model, separate access is needed to which control values gave each measurement.

## Import requirements

- Preserve measurement identities, order, spectra, colorimetry and all available conditions.
- Read layout if present, but separate placement from the patch's identity.
- Link to a separate PXF/TXF/TI1/TI2 or a verified internal target before the data is used for profiling.
- Check that the link is unambiguous. The number of patches and a similar visual colour order are not sufficient proof.
- Allow analysis of unlinked measurements, but mark that the profiling basis lacks control values.

## Export requirements

Export the selected set of measurements and document its target link in the project or an accompanying manifest. If the target variant cannot carry all measurement conditions, these must be split or chosen explicitly, with a loss report.

Do not write RGB/CMYK control values into CMXF in an attempt to make the format into MXF. Use a verified MXF export instead when the recipient needs both control values and measurements. Exact layout resources and colour-specification requirements must be tested against the recipient version.

## What can and cannot be restored?

CMXF + a correct target link can provide the basis for TI3 or MXF. CMXF alone is normally not sufficient. A transformation from Lab to RGB with an ICC profile gives a possible colour reproduction, not proof of which RGB values were originally printed. Such calculated values must not be presented as original control values.

If MXF is exported to CMXF, the place of the control values in the measurement file itself disappears. Restorability then depends on the original or a separate target definition and ID map remaining available.

## Verification cases

Test the same measurement package with a correct, a missing and a deliberately incorrect target. Only the verified link should be usable for profiling. Also test several measurement conditions and a file in which only colorimetry is present; the absence of spectra must remain visible.

## Practical review of i1Profiler 3.8.5

See the [verification report](ui-verification-3.8.5.md) for observed menu choices, the performed MXF import, spectral CGATS export and TIFF export. The report distinguishes performed tests from remaining format and layout verification.
