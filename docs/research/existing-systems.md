# Review of existing programs

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-24. Code reading and limited tests; no full product validation.

## SpectraLab v1.2.1-dev

Reviewed locally in `/Users/christer/Desktop/SpectraLab/SpectraLab_v1.2.1-dev`.

- Existing measurement path through Argyll `spotread`.
- Canonical spectral archives with identity and content hash.
- Patch sessions with a variable number of rows/columns; named target definition for ColorChecker Digital SG.
- Reflectance to XYZ/Lab with explicit illuminant and observer.
- The existing CGATS export lacks device RGB/CMYK and is not a complete profiling TI3.
- Historical knowledge base. InkProf is to have its own implementation without calls to SpectraLab's API; see [decision 007](../decisions/007-independent-inkprof.md).

## Camera-41 v0.9.0-dev

Reviewed locally in `/Users/christer/Desktop/Camera-41/Camera-41_v0.9.0-dev`.

- Model for verified, read-only import of SpectraLab data.
- Clear dependencies, measurement roles and origin references.
- OpenCV adapter and perspective geometry for SG140, not a general print map.
- The specific spectral range 400–730 nm is not to be copied as a general InkProf limitation.

## ChromIQ - commit 92e6ead0

Source: https://github.com/itsab1989/ChromIQ

- Graphical workflow around Argyll with its own additions, for example layout and a modified chart reader.
- The beta engine builds a device → Lab model, inverts the model and writes ICC tables.
- Fast uses its own implementation. Bit-exact in the RGB/CMYK interface goes to `colprof`. Maximum accuracy uses its own robust fitting and cross-validated smoothing.
- Options include a noise model, a spectral Yule–Nielsen/Neugebauer hybrid and alternative gamut mapping.
- The spectral hybrid is not activated for ordinary RGB data. At least 200 patches are required in the reviewed code.
- ICC v2/v4 can contain the same colour tables; the version number does not imply better colour precision.
- The documentation states that the multi-ink engine has not been verified on real multichannel hardware. A comparison test requires a measurement file on the developer's local computer.

### Limited check performed

In ChromIQ, the following was run:

```text
.venv/bin/python -m pytest -q tests/test_engine_accurate_mode.py -k 'delta_e_2000 or average_endpoints or project_tac or accurate_fit'
```

Result: **15 passed, 13 deselected**. The check covered ΔE00, endpoint averages, ink limiting and robust fitting. It does not show physical print quality and is not an InkProf test.

## ColorThink 4 and i1Profiler

ColorThink is used as a model for comprehensible profile inspection, colour lists and gamut comparison. i1Profiler is used as a model for a coherent profiling workflow and iterative improvement, and as a possible comparison engine. Functions vary with licence and version. No code or commercial algorithm from the products has been imported.

Sources and the full comparison are in the project plan.


## Addendum 2026-09-25: Mirage and Canon PRO-2600

Mirage shows `High Quality (600x600 dpi, 12-bit)` for the PRO-2600. See [source note, interpretation and original image](canon-pro-2600-mirage-12-bit.md). The stated print bit depth is to be kept separate from ICC table precision and the number of ink cartridges.
