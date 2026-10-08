# C3 – first measured check, 2026-09-28

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

**Diagnostic result; the profile is not print-approved.**
The print chain is to be reviewed using screenshots. The user reports Photoshop
Printer Manages Colors, Absolute Colorimetric and greyed-out Off in the driver.
The target had already received the profile conversion in InkProf.

Profile: Epson 3880, Glossy, B2A High. ICC SHA256:
`90ac68bb407ceacc1b59edb0e838e76d0d54dcf1218d49ff8ee57d4cb8cc1258`.
The historical project name `Canon-575-20260927` does not indicate the actual printer model.
Measurement: `matning-dialog-20260928-090743-312/measurement-20260928-091102619.json`.
Target: `Epson3880-Glossy-C2-absolute-128-e0c7a41d-a244-4ce7-b634-169966ff44ee`.

All 128 source patches match ID, RGB and physical coordinate. Spectral analysis:
Argyll profcheck D50/1931_2 without FWA, ΔE00 against desired absolute Lab.

| Group | Count | Mean ΔE00 | P95 | Max |
|---|---:|---:|---:|---:|
| All unique, including challenge | 116 | 2.0593 | 10.0306 | 15.3044 |
| Model-assessed reachable, unique | 104 | 1.0732 | 2.1228 | 4.9045 |
| Greyscale | 24 | 0.8140 | 1.3094 | 1.3679 |
| Other ordinary colours | 80 | 1.1509 | 2.3058 | 4.9045 |
| Intentional challenge colours | 12 | 10.6054 | 15.0751 | 15.3044 |

Greyscale: mean ΔL*=+0.2375, Δa*=+0.3169, Δb*=−0.4134.
Mean measured C*ab=0.5686, max=1.2026. This suggests a small average
red/blue deviation; this is not a determined cause or an acceptance limit.

Largest error among model-assessed reachable: **L4**, ID43, ΔE00=4.9045.
Largest overall: **N5**, ID113, a challenge patch, ΔE00=15.3044.
The latter's deviation from the profile's prediction is 1.0527: the large error
against the desired colour should therefore not be interpreted without further ado as poor model fit.

Twelve repeated printed patches: mean ΔE00=0.3116, max=0.5082.
Forward/backward sweep: mean ΔE00=0.0777, max=0.2813 (stored XYZ-based check).
This supports good repeatability in this measurement, not verified print accuracy.

The analysis is implemented via `inkprof.checkVerificationTarget`. Four Python
tests cover reference selection, patch identity, coordinates/RGB, completeness,
repetitions and hash errors. An actual MATLAB run and the GUI filter have been checked.

The next decision requires a verified print chain and agreed acceptance limits.
The original measurement is preserved. No automatic profile optimisation
or re-profiling has been done; ISSUE-001 on inverse and measurement noise remains open.
