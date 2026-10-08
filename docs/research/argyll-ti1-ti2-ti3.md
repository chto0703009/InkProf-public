# ArgyllCMS: the .ti1, .ti2 and .ti3 file formats

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25

`.ti1`, `.ti2` and `.ti3` are documented ArgyllCMS formats. The third file extension is `.ti3`, not `.t3`. The files are readable text files based on CGATS, with Argyll-specific fields and meanings.

## Content and roles

| Format | Content | Normally created by |
|---|---|---|
| `.ti1` | The patches' control values, for example RGB, and estimated CIE colour values. Describes what is to be tested. | `targen` |
| `.ti2` | The patches' control values, their placement in the finished target, and estimated CIE colour values for checking during reading. Links the measurement to the correct patch. | `printtarg` |
| `.ti3` | Control values together with XYZ/Lab values and, when saved, spectra. Serves as the measurement basis for profiling in the usual printing workflow. | `chartread` |

The colour values in `.ti1` and `.ti2` are estimates, not measured results from the actual print. In the normal measurement workflow, the measurement results are stored in `.ti3`. The format can also be created by conversion and simulation tools; the file extension alone therefore does not prove that the values are physically measured.

## Normal workflow for a printer

```text
targen    → .ti1
printtarg → .ti2 + printable target
chartread → .ti3
colprof   → ICC profile
```

`printtarg` reads `.ti1` and creates the layout information in `.ti2` together with a printable target. After printing, `chartread` uses `.ti2` to organise the measurement and saves the result in `.ti3`. `colprof` then uses `.ti3` as the basis for the ICC profile.

## Significance for InkProf

`.ti3` can link each patch's RGB control values to its measured spectrum. This is the basis needed for the proposed RGB forward model.

The format defines, among other things:

- `SAMPLE_ID`: the patch's identity.
- `RGB_R`, `RGB_G`, `RGB_B`: the device's RGB control values.
- `COLOR_REP`: which colour spaces are linked together.
- XYZ or Lab columns for colorimetric values.
- `SPECTRAL_BANDS`, `SPECTRAL_START_NM` and `SPECTRAL_END_NM` when spectral data are present.
- `SPEC_XXX`: spectral columns, where XXX denotes the wavelength rounded to an integer in nanometres.

The RGB control values in `.ti3` are given in **0–100 percent**. If InkProf uses 0–1 internally, they must be divided by 100. They must not be interpreted as 8-bit values in the range 0–255.

Spectral data are not guaranteed merely because the file has the extension `.ti3`. InkProf needs to check which fields are actually present before a spectral model is built.

InkProf can use these formats without creating its own replacements. Project metadata can add print settings, measurement conditions, tool versions and traceability. The original files should be preserved together with the target that was actually printed.

## Sources

- [ArgyllCMS: File formats](https://www.argyllcms.com/doc/File_Formats.html) – overview of `.ti1`, `.ti2` and `.ti3`.
- [ArgyllCMS: TI3 file format](https://www.argyllcms.com/doc/ti3_format.html) – fields, metadata and value scales for `.ti3`.
- [ArgyllCMS: Usage scenarios](https://www.argyllcms.com/doc/Scenarios.html) – the workflow from target to measurement and profile.
