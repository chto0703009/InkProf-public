# C1 – verification 2026-09-27

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Status: **Technically completed for the current candidate; ready for the user's acceptance.**

Candidate: Epson 3880 / Glossy / 575 corrected measurement patches, A2B medium and B2A high. Job `63dfb8f4-034b-488e-82b0-341511343016`, SHA256 `90ac68bb407ceacc1b59edb0e838e76d0d54dcf1218d49ff8ee57d4cb8cc1258`. All checks below refer to relative colorimetric without BPC.

## Earlier checks

- Training fit, 575 patches: mean/max ΔE00 **0.4865 / 2.3387**.
- RGB round trip, 729 points: mean/max ΔE00 **0.4809 / 2.4055**.
- No RGB outside the cube. Forward grey ramp without L* reversals; no candidates above the previously defined second-difference limit.

## Remaining C1 tests, now completed

| Check | Result |
|---|---|
| Argyll–LittleCMS forward, floating-point input | mean ΔE00 0.001324; max 0.005197 |
| Inverse, RGB difference | mean 0.002908; max 0.023940 percentage points |
| Colour difference between the inverse solutions via the same A2B | mean ΔE00 0.001284; max 0.007035 |
| 27 inverse ramps × 1 025 samples | max RGB step 0.8585 percentage points; max colour step 0.2252 ΔE00 |
| Truncated ICC, wrong signature, wrong colour space | all rejected |
| Valid structure but corrupted B2A1 table | detected numerically; max round trip 94.59 ΔE00 |

LittleCMS 2.19 was run via the public C API with double-precision buffers and without the detour via 8-bit images. Internal precision is still limited by the engine and the ICC table. The comparison refers to this particular evaluation path; other optimisation choices and rendering intents have not been qualified.

The earlier large difference in the 8-bit comparison does not recur in this floating-point check. We therefore cannot use the 8-bit result as evidence of a corresponding error in a high-precision chain.

### Local behaviour

The perturbation is applied in one Lab coordinate at a time. The maximum RGB channel difference between the endpoints was:

| Half Lab step | Total Lab step | Max RGB difference, percentage points |
|---:|---:|---:|
| 0.1 | 0.2 | 3.0254 |
| 0.01 | 0.02 | 0.3005 |
| 0.001 | 0.002 | 0.0304 |

The change in output shrinks approximately in proportion to the step. This supports a finite local slope at the tested points and gives no evidence of a remaining jump there. It does not prove global smoothness and does not confirm that measurement noise caused errors.

## Conclusion and scope

The agreed remaining numerical C1 checks have been completed. The engines agree well in the floating-point test and the diagnostics detect the intentional faults. No new gross errors emerged in the candidate. Remaining round-trip errors are documented, not renamed as zero errors.

C1 is to be accepted as a numerical check of this candidate, not as approval of print quality. C2 is to verify actual prints. **ISSUE-001 remains open** until we have better evidence for linking real deviations to condition numbers and measurement noise. It is not a requirement to carry out the noise study now.

## Traceability

- `c1-verification-20260927.json` contains results and worst cases.
- The routine `inkprof.checkProfileC1(jobFolder)` saves new reports under the job's `checks` and updates the manifest.
- Seven new Python tests cover floating-point formats, input validation, missing library, wrong profile class and gross-error indicators. Negative checks on an actual ICC are also included in the run.
