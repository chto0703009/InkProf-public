# ICC v2 and v4.4 for RGB printer profiles

> Historical planning/research/decision record. The dated findings are preserved; use [the documentation index](../README.md) for current usage and status.

Date: 2026-10-09. Status: historical findings and initial proposals.
Implementation update: the compatibility preparation, native existing-v4
verification and selectable v4.4 output have now been implemented. The measured
prototype results below are preserved and are not a certification of all profiles.
See [project output settings](../usage/profiling-project.md#delivered-icc-versions). Current behaviour is described in
[Verify an existing printer ICC](../usage/verify-existing-icc.md#icc-v4-import).

## Question and scope

InkProf builds RGB output profiles with ArgyllCMS `colprof`, which writes ICC
v2 only. Imported profiles from other software are often v4. This note records:

1. what differs between v2 and v4.4 for an RGB printer profile;
2. whether Argyll can read v4 directly;
3. how accurate the existing v4 → v2 compatibility copy is, and why;
4. where InkProf reads ICC profiles, and which path is safe;
5. a tested prototype for delivering InkProf profiles as v4.4.

Scope: printer class `prtr`, colour space RGB, PCS Lab, D50. CMYK, N-colour
and display profiles are out of scope.

## v2 and v4.4 for an RGB printer profile

The current specification is ICC.1:2022-05, version 4.4.0.0 (ISO 15076-1:2010
corresponds to v4.3). The tag layout used by `colprof` is legal in both
versions. The relevant differences:

| Area | v2 (colprof) | v4.4 |
| --- | --- | --- |
| Header | Version 2.2, no profile ID | Version 4.4.0.0; profile ID = MD5 with flags, rendering intent and ID zeroed (7.2.18) |
| Text tags | `desc` textDescriptionType, `cprt` textType | `mluc`; `targ` may stay textType |
| Media black | `bkpt` written | `bkpt` obsolete |
| Perceptual PCS | Not precisely defined | Reference medium, black L* 3.1373 (XYZ 0.003357 / 0.003479 / 0.002869) |
| Saturation intent | Vendor specific; colprof shares data with perceptual | Vendor specific; LittleCMS assumes the perceptual black |
| `lut16Type` | Legacy Lab encoding (L* 100 = 0xFF00) | Allowed, same legacy encoding |
| Chromatic adaptation | Argyll private `arts` | `chad` when not measured for D50; not needed for InkProf (always D50) |
| Floating point | None | Optional D2Bx/B2Dx (multiProcessElements), since v4.3 |

Because `lut16Type` keeps its encoding, the colorimetric tables (A2B1, B2A1)
can move between versions without any change. The real difference is the
black of the perceptual (and, in LittleCMS, saturation) tables.

### Perceptual black in InkProf profiles

Measured on four InkProf profiles (`3880_SP_Glossy` with and without
pre-regularization, `3880_HFAPR_Baryta_315`, `Canon-575-20260927`):

| Table | Black assumed by the v2 table |
| --- | --- |
| A2B0 (a copy of A2B1) | Paper black at RGB 0,0,0: L* 3.9–4.4 |
| B2A0 with `-s` (gamut mapping) | L* 0.5–0.8 |
| B2A0 without `-s` (same data as B2A1) | L* 3.8–3.9 |

For comparison, the i1Profiler v4.2 profile `3880 ScPh Glossy_opt.icm` gives
perceptual black L* 3.14 for RGB 0,0,0 through LittleCMS; the InkProf v2
profiles give 3.9–4.3.

LittleCMS treats the perceptual and saturation intents of a v4 profile as if
black point compensation were always on. In the recorded numerical example through LittleCMS, a v4 version of an
InkProf profile predicts output lightness within 1 L* of the v2 profile with BPC enabled,
regardless of the BPC flag. This is not a new physical print measurement or a
guarantee for every profile/application. Grey ramp from sRGB, perceptual,
predicted output L* via A2B1 (`Canon-575`, no `-s`):

| sRGB grey | v2 | v2 + BPC | v4 | v4 + BPC |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 4.3 | 4.8 | 4.4 | 4.4 |
| 8 | 4.9 | 6.9 | 6.8 | 6.8 |
| 32 | 12.1 | 14.9 | 14.5 | 14.5 |
| 128 | 53.6 | 54.1 | 53.9 | 53.9 |

Without BPC, v2 profiles built without `-s` merge the deepest shadows
(the numerical `3880_HFAPR_Baryta_315` example predicts sRGB 0 and 8 at the same L* 4.3).

## Argyll cannot read v4

A project log records:

```
Warning: ICC V4 not supported!
/usr/local/bin/xicclu: Error - 1, icc_get_luobj: Unable to locate usable conversion
```

[A1](icc-a1-reader-basis.md) noted the same warning from `iccdump`. Every path
through `xicclu`, `targen -c` and `profcheck` therefore needs a v2 profile.
LittleCMS reads v4 natively; `analysis/lcms_float.py` provides double-precision
transforms in both directions.

## Accuracy of the existing v4 → v2 copy

`profiles/convert_v4_to_v2.py` does not copy tables. It samples the original's
absolute A2B on a 17³ grid with LittleCMS, writes the samples as a TI3 and
rebuilds a new profile with `colprof -qh -al -bh -r 0.1 -s 20`. Inverse tables
and the perceptual mapping are colprof's, not the original's.

Measured on `3880 ScPh Glossy_opt.icm` (SHA-256
`ed2ee54cbac60faaf3ebbbca803674f689f8151e17712a0668dd84a7681fa405`) and its
cached copy, both read with `lcms_float.py`, 4 000 points per row. B2A rows
judge both printed results through the original's A2B1.

| Direction | Intent | Colours | ΔE00 mean | p95 | max |
| --- | --- | --- | ---: | ---: | ---: |
| A2B (RGB → Lab) | Perceptual | random RGB | 1.73 | 3.52 | 4.60 |
| A2B | Relative | random RGB | 0.51 | 1.34 | 2.69 |
| A2B | Absolute | random RGB | 0.50 | 1.30 | 2.55 |
| B2A (Lab → RGB) | Relative | printable | 0.54 | 1.30 | 2.16 |
| B2A | Relative | sRGB, incl. out of gamut | 1.05 | 3.38 | 7.36 |
| B2A | Perceptual | sRGB | 1.91 | 4.11 | 6.50 |
| B2A | Absolute | printable | 0.54 | 1.29 | 2.33 |

`conversion.json` reports relative 0.48 / 2.36 and absolute 0.13 / 0.48
(mean / max). It compares LittleCMS on the original with `xicclu` on the copy,
covers A2B only, and therefore misses both the error below and the B2A
direction used for printing.

### Cause: two definitions of absolute colorimetry

| Comparison | ΔE00 mean | max |
| --- | ---: | ---: |
| LittleCMS: original relative vs XYZ-scaled absolute | 0.000 | 0.000 |
| LittleCMS: original relative vs Bradford-adapted absolute | 0.474 | 2.689 |
| Copy relative vs Bradford(original absolute) | 0.136 | 0.932 |
| Copy relative vs original relative | 0.508 | 2.690 |

LittleCMS computes absolute = relative × media white / D50 (the ICC
definition). `colprof` converts the absolute samples back to relative with
Bradford. On this paper (white Lab 94.86 / 0.83 / −6.86) that mismatch explains
93 % of the copy's mean relative error and all of its maximum; the table
resolution accounts for 0.14 mean.

Proposed correction: sample the original's relative intent and convert it to
absolute with the inverse Bradford transform for the media white before writing
the TI3. Numerically, `colprof`'s Bradford step then returns the original
relative values exactly (0.000); the rebuild itself has not been run.

## Where InkProf reads ICC profiles

| Use | Code | Reads through | Assessment |
| --- | --- | --- | --- |
| Target pre-conditioning (`targen -c`) | `designRGBTarget.m` | Argyll | Safe with the v2 copy: it only steers patch placement |
| Inspection | `readICC`, `read_icc.py` | InkProf reader | Safe: reads the original unchanged |
| Verification of an existing v4 profile | `executeWorkflowStep.m` → `verification_target.py`, `verification_chain.py` | Argyll `xicclu`, absolute | Not safe for the original: target RGB, predictions and certificate describe the copy |
| Export / delivery in verification mode | `executeWorkflowStep.m` (`numericalExport`) → `saveICC` | file copy | Not safe: the copy is delivered as `profile.icc` with colprof's perceptual mapping |
| Import into a project | `importICC.m` | copy + original | Both kept; later Argyll steps use the copy |

Proposed: read v4 originals directly with LittleCMS wherever Argyll is not
required (verification target, predictions, chain analysis), using one engine
throughout the chain, and deliver the original, never the copy.

## Proposed: delivering InkProf profiles as v4.4

A prototype converter (`icc_v2_to_v4.py`, with a MATLAB wrapper
`iccOutputVersion.m`) exists outside the repository. It accepts only v2
`prtr`/RGB/Lab profiles and:

- sets the header to 4.4.0.0, exact D50 illuminant, zeroed reserved bytes and
  MD5 profile ID;
- converts `desc`, `cprt`, `dmnd` and `dmdd` to `mluc`, and removes `bkpt`;
- measures the black of each perceptual table and remaps it to L* 3.1373 with
  the linear map of ICC.1:2022 6.3.4.3 (white fixed); saturation tables shared
  with the perceptual ones follow;
- copies A2B1, B2A1, `gamt`, `wtpt`, `targ` and `arts` byte for byte;
- refines B2A0 from 33 to 65 grid nodes, keeping every original node
  (`--b2a-grid same` keeps the original size);
- writes a JSON report with input and output SHA-256, measured blacks and checks.

Results on the four profiles above:

| Profile | v2 black A2B0 / B2A0 (L*) | LittleCMS perceptual black v2 → v4 (L*) | B2A0 resampling ΔE00 mean / max |
| --- | --- | --- | --- |
| `3880_SP_Glossy`, `-s 20` | 4.4 / 0.8 | 4.31 → 3.14 | 0.025 / 0.70 |
| `3880_SP_Glossy`, pre-regularized, `-s` | 4.1 / 0.5 | 4.31 → 3.14 | 0.025 / 1.22 |
| `3880_HFAPR_Baryta_315`, no `-s` | 3.9 / 3.9 | 3.92 → 3.14 | 0.017 / 0.76 |
| `Canon-575-20260927`, no `-s` | 4.1 / 3.8 | 4.31 → 3.14 | 0.012 / 0.55 |

In all four, LittleCMS gives identical relative and absolute colorimetric
results for v2 and v4 (maximum difference 0 in 8 bits). With 33 nodes, isolated
out-of-gamut colours darker than the printer black reached 4.8 ΔE00; 65 nodes
keep the maximum at 1.2 ΔE00. Profiles grow by 1.5–1.7 MB to 2.2–3.3 MB.
Conversion takes about 0.5 s.

Proposed integration: keep the built v2 profile (job hashes and Argyll steps
refer to it) and write `<name>-v4.icc` beside it when the user selects v4 or
both. The MATLAB wrapper has not been run; the v4 files have not been checked
with ICC's reference tools.

## Open actions

1. Correct the Bradford mismatch in `convert_v4_to_v2.py`; check B2A and
   perceptual with one engine on both sides in `conversion.json`.
2. Verify v4 originals with LittleCMS, and deliver the original.
3. Decide whether to integrate v4.4 output (recipe option, `profile_job.py`
   step, dialog, tests).
4. Validate v4 output with RefIccMAX before release.

## Sources

- [ICC.1:2022-05, version 4.4.0.0](https://www.color.org/specifications/ICC.1-2022-05.pdf), especially 6.3.4 and 7.2.18
- [color.org: Version 4 ICC specification](https://color.org/v4spec.xalter)
- [color.org: Differences between v2 and v4](https://color.org/v2-v4.pdf)
- [color.org: Making v2 profiles](https://color.org/v2profiles.xalter)
- [LittleCMS](https://www.littlecms.com/)
- [ArgyllCMS](https://www.argyllcms.com/)
- [ChromIQ](https://github.com/itsab1989/ChromIQ): its experimental v4 output re-labels v2 tables without remapping the perceptual black
