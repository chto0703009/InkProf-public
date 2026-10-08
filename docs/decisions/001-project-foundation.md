# 001 - InkProf's foundation

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-24. Updated: 2026-09-26. Status: direction decided. The target workflow is implemented and the measurement prototype has been tried in simulation; physical verification remains.

## Decisions and direction

1. The package name is **InkProf**. A web search found no prominent ICC software with that name, but did find a Turkish company directory entry named İnkprof in printing solutions. Domain and trademark availability have not been verified.
2. InkProf is an independent MATLAB package with no runtime dependency on SpectraLab or Camera-41. See [decision 007](007-independent-inkprof.md).
3. **MATLAB Base** is the platform requirement. Extra toolboxes must not become mandatory through indirect dependencies.
4. **ArgyllCMS is the reference engine**, in particular `targen`, `printtarg`, `chartread` and `colprof`.
5. The first delivery covers target import/generation, TIFF16 and measurement files. Measurement, analysis and ICC generation follow, according to project plan v0.6.
6. The Canon PRO-2600 is treated as an RGB device in the chosen driver workflow. The number of ink cartridges does not determine the number of accessible profile channels.
7. Model error against training measurements and ΔE00 for a separate profiled print are different results and must be labelled clearly.
8. Patch count, patch distribution and profile builders are to be compared against independent control material and recorded print variation.
9. The ChromIQ beta's profile builder becomes an optional comparison engine. Better results are a hypothesis to be tested.
10. Yule–Nielsen/Neugebauer modelling belongs to a later stage, for investigating the print space. The RGB workflow first requires an empirical spectral model; physical separation of the inks cannot be assumed.
11. Internal computations use `double`. The goal is 16-bit LUT values and 16-bit RGB TIFF; the actual profile precision and print path are checked.
12. Mirage states `High Quality (600x600 dpi, 12-bit)` for the PRO-2600 in [Christer's documented screenshot](../research/canon-pro-2600-mirage-12-bit.md). This is verified as an interface statement for the chosen mode. The internal quantization and ink dosing remain unknown. The print recipe must record the full quality mode and the other settings. The goal of 16-bit export and 16-bit ICC table values remains.

## Still to be determined

- the exact compatibility matrix,
- instrument and measurement mode,
- the first paper and print recipe,
- the pace of development,
- tolerances for the comparison experiments.

None of these questions prevents the importers and data contracts from being developed with controlled sample files.

The licence has been set to GPL-3.0-or-later, per [decision 003](003-shared-gpl-license.md).
