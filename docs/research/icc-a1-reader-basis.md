# A1 – basis for InkProf's ICC reader

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-27. Status: implementation basis; A1 is now implemented. See [current usage](../usage/icc-reader.md).

## Recommendation and scope

Build a self-contained reader in Python using the standard library (`struct`, `pathlib`, `hashlib`, `json`). MATLAB Base handles file selection and presentation in English. No MATLAB toolbox or runtime dependency on ChromIQ is needed for this step.

A1 reads identity, profile header, tag table, descriptions and simple XYZ tags. LUT tags are identified but not used for colour conversion. That a profile can be read does not mean its colour reproduction is validated. Unmodified import and Save As belong to A2; profile generation comes later.

## Normative basis

ICC specifies a 128-byte header, followed by a tag count and 12-byte entries with signature, offset and size. Multi-byte values are read big-endian. Tag data starts are four-byte aligned; the size excludes trailing padding. Several tags may share an identical data range. Partial overlap and duplicate tag signatures must not be treated as such sharing. The order of the tags need not follow the order of the data. Text types include `mluc` among others; XYZ uses signed fixed-point. Requirements depend on profile class and version. The header's PCS illuminant must not be interpreted as the measured paper white. Source: [ICC.1:2022, especially chapters 4, 7–10](https://www.color.org/specifications/ICC.1-2022-05.pdf).

Older profiles also require [ICC's v2 specification](https://www.color.org/v2spec/). The additional requirements of v4.4 must not automatically be used to reject older v2.1/v4.2 profiles. The reader must distinguish supported version, structural error and interpretation not yet implemented.

## ArgyllCMS and ChromIQ

[Argyll iccdump](https://www.argyllcms.com/doc/iccdump.html) is used as an independent comparison where the installed version supports the profile. Locally, iccdump reports 3.2.0 and warns of missing v4 support. A further check with verified v4 support is therefore required for the v4 sample; the choice of such a checking tool remains open.

ChromIQ was reviewed locally at commit `92e6ead022fd57f4ecb80bf03670361b1b882247`:

- [workflow/icc_info.py](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/workflow/icc_info.py) shows a simple Python reader. It interprets the header, description and white/black point. Its mluc reading picks the first language record and does not check all internal ranges against the tag's declared size. Some text errors become empty text. InkProf needs clearer diagnostics and stricter bounds checks.
- [core/icc_text.py](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/core/icc_text.py) shows the importance of preserving Unicode in older descriptions.
- [workflow/icc_convert.py](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/workflow/icc_convert.py) is not a general solution for our LUT printer profiles: the conversion is limited to matrix/TRC RGB. No version conversion is included in A1.

No ChromIQ code has been copied. The material is used for an own implementation against the ICC specification.

## Real test profiles

The following information comes from local binary inspection, the user's statements and the manufacturer's instructions. The originals have been preserved as reference files in the local profiling project.

| Profile | Version | Class / device / PCS | Table types | Media setting |
|---|---|---|---|---|
| 3880 IGGFS Neutral.icm | 2.1.0 | prtr / RGB / Lab | mft2 | Premium Luster, according to the user |
| 3880 ScPh Glossy_opt.icm | 4.2.0 | prtr / RGB / Lab | mAB / mBA | Premium Glossy, according to the user |
| HFA_Eps3880_PK_FABaryta.icc | 2.4.0 | prtr / RGB / Lab | mft2, also private tags | Premium Luster, according to the accompanying Hahnemühle PDF |

None of these is specified for matte paper. The first two are the user's i1Profiler profiles for the Epson Stylus Pro 3880. The third concerns Hahnemühle FineArt Baryta with Photo Black. A media setting is not the same as the name of the paper product. The information does not prove which print recipe was used for the 575 target. The project folder's historical name Canon is not evidence of the printer model.

## Proposed JSON contract

A separate ICC metadata record is linked from the project manifest. The binary original file remains authoritative; JSON does not replace the profile.

- `source`: original path, project-relative copy where one exists, SHA-256, actual file size and import time.
- `header`: declared size, full version, class, device colour space, PCS, date, CMM, creator signature, flags, attributes, intent and profile ID where applicable. Preserve raw signatures alongside display names.
- `tags`: signature, type, offset, size, shared range, interpreted summary and diagnostics. Unknown tags remain in the original file and in the table of contents.
- `descriptions`: all available language records, including original encoding and the chosen display text.
- `diagnostics`: stable error code, severity, affected tag/byte position and a readable explanation.
- `capabilities`: what the reader has actually interpreted. Distinguish a readable profile from a compatible RGB output profile for a later profiling step.
- `declaredPrintSettings`: user/manufacturer statements with their source, kept separate from information read from the ICC.

The creator signature is a hint, not a reliable identification of the software version. Missing information must be unknown, not filled in from the file name. A1 must not estimate physical density or metamerism from the profile header.

## Small implementation steps and acceptance

1. **Binary base reader:** check the whole tag directory and every range before interpreting data. Limit resource use caused by unreasonable counters. Compare actual and declared file size and report differences.
2. **Text and simple values:** interpret description, localisations and XYZ; check internal lengths within each tag. Keep warnings visible if an individual tag cannot be interpreted.
3. **MATLAB dialog:** file selection, profile summary, tag table and diagnostics. No profile modification or colour conversion. Non-RGB can be identified but must not be accepted as RGB input data.
4. **Verification:** compare the three real profiles with external tools within their verified support. Check the original hash before/after. Complement with synthetic files for truncation, wrong size, broken mluc, Unicode, duplicate signature, permitted shared range and prohibited overlap. A missing optional black point must not by itself make a profile unreadable.

A1 is done when these checks pass and the limitations are displayed correctly. Full interpretation/evaluation of LUT tables and assessment of profile quality are outside this delivery.

## Addendum: Colour and LittleCMS

[Colour Science for Python](https://www.colour-science.org/) is installed as `colour-science` and imported as `colour`. InkProf already has version 0.4.6 and uses it in, among other things, spectral analysis and colour comparisons. It remains our tool for colorimetry.

For ICC reading and later profile-based transforms there is [Pillow ImageCms](https://pillow.readthedocs.io/en/stable/reference/ImageCms.html), built on LittleCMS. LittleCMS 2.19 is available locally. A read test on 2026-09-27 opened both user profiles and returned the correct description and version (2.1 and 4.2 respectively). This verifies basic reading, not the numerical results of the tables or full format conformance.

The recommendation is therefore supplemented: use ImageCms/LittleCMS for independent metadata comparison and evaluate its API before building more ICC functionality ourselves. A limited structure reader is still needed for the full tag table, raw ranges and InkProf's diagnostics. Colour handles the colorimetry. MATLAB Base presents the results.

## Fourth reference profile: matte paper, Canon

Added 2026-09-27: `HFA_CanonGP-2600S_MK_GermanEtching.icc` with the accompanying settings sheet, 05.2024 / Rev. 00. Local unmodified copies and hash are under `projects/icc-reference-profiles/canon-gp2600s-german-etching/` together with `inspection.json` and `reference.json`.

A1 reads the profile without structure warnings: ICC 4.3.0, prtr/RGB/Lab, 18 tags, mAB/mBA. The description matches LittleCMS. The tags CxF / ZXML and meta / dict are reported but not decoded by A1. The file's internal description is `HFA_Canon2600S_MK_GermanEtching.icc`, which differs from the file name.

The settings sheet states Canon iPF GP-2600S, Matte Black (MK), the medium Heavyweight Fine Art Paper, quality high and colour management turned off in the driver. Rendering intent and black point compensation are chosen according to the image. The user states matte paper and writes Canon pro 2660; compatibility with the intended printer has therefore not yet been established. The reference is not linked to the print recipe of the Epson measurement.

The profile header's attributes are zero even though the reference concerns matte paper. This shows why paper properties from a default value in the profile header should not alone be used to choose print settings.
