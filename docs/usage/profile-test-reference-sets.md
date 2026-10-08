# Profile test with a reference set (ColorChecker SG, Argyll, TI1)

The C2 target ("Save verification TIFF16") can be built from a fixed reference set instead of InkProf's generated balanced colours. The workflow is otherwise unchanged:

1. create the target in the app,
2. print the TIFF16 pages,
3. let the print dry,
4. measure with the matching TI2,
5. analyse in C3.

It works both in **Verify existing ICC** projects and in profiling projects.

## Choosing the reference set

At the C2 step the app asks **Which colours should the profile test target contain?**

| Choice | What happens |
|---|---|
| **Default: …** | The file stored in `local-config/reference-sets/` on this computer. On first use you pick the file and may keep it as the default. |
| **Other file (Lab, Argyll .cie, TI1)…** | Any supported file (see below). |
| **Generated balanced set** | InkProf's own selection (previous behaviour; the default in profiling projects). |

You are then asked for **Extra repeat patches** (default 12). Repeats are spread over the set and measure print and measurement repeatability.

## Supported files

| Content | Format | Reference used for ΔE |
|---|---|---|
| Lab D50 | Tab/space table with a `Patch`, `SAMPLE_ID` or `SAMPLE_NAME` column and `LAB_L LAB_A LAB_B` (e.g. *digital_colorchecker_sg_l_a_b.txt*); note lines after the table are ignored | the given Lab |
| Lab or XYZ | CGATS, e.g. Argyll `ref/*.cie` (ColorChecker, Passport, SpyderChecker …) | the given Lab; XYZ 0–100 is converted against ICC D50 |
| Device RGB | TI1/TI2/CGATS with `RGB_R RGB_G RGB_B` (0–100) | the profile's A2B prediction |

CMYK sets are rejected.

**Lab sets** are reproduced through the profile: absolute colorimetric, no BPC, the ICC applied once. The ΔE therefore tests the inverse table, the print and the measurement together.

**Device RGB sets** are printed as given, without applying the ICC. The ΔE therefore tests the profile's forward model (A2B) against the print.

## What is stored

`verification.json` keeps every patch, including:

- `referenceName`, the code from the file such as `A1` or `N10`,
- role,
- reference Lab,
- device RGB16,
- predicted Lab,
- gamut screening (numerical inverse residual),
- page/coordinate placement after layout.

It also contains a `referenceSet` block with the file name, SHA-256, kind and basis. An exact copy of the source file is kept as `definition/reference-set.<ext>`. After measuring, C3 matches the measured patches back to these codes.

Roles are assigned automatically:

| Role | Rule |
|---|---|
| `gray` | reference C*ab ≤ 2.5 |
| `challenge` | numerical inverse residual > 3 ΔE00, i.e. probably outside the printer gamut; reported separately |
| `colour` | all others |
| `repeat` | the extra repeats |

The C3 report gives ΔE00 mean, median, p95 and maximum for:

- all unique patches,
- model-reachable patches,
- gray, colour, challenge, dark and high-chroma patches,

plus gray balance and repeatability. The patch list shows the reference code next to the ID.

## Print format

The target is rendered by the same TIFF16 package as other targets: row and column labels, TI2 for chartread, `PRINTING.txt`, and paper planning when enabled. Print at 100 % with all further colour management off.

## Licence of reference data

Reference values such as the X-Rite ColorChecker SG data are licensed by their owner. The X-Rite file allows personal and educational use only, without a licence. Such files are therefore **not** part of the InkProf repository: `local-config/` is git-ignored. Each user supplies their own file.

## From MATLAB

```matlab
[folder,ref] = inkprof.createVerificationTarget(jobFolder, ReferenceSet="local-config/reference-sets/ColorChecker-SG-D50-Lab.txt", Repeats=12);
% for an imported ICC (Verify existing ICC project): add ExternalProfile=true
```
