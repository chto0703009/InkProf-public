# Project rationale: continued use of the i1Pro and i1Pro 2

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Documented 2026-09-25 based on X-Rite's own support statements.

## Why this motivates InkProf

X-Rite has removed support for older spectrophotometers in later versions of i1Profiler. An instrument can therefore still be useful for measurement but lack support in the current manufacturer software. Keeping an older software version may in turn tie the user to older operating systems and drivers.

InkProf is intended to provide an alternative, documented route for measurement, analysis and ICC profiling using ArgyllCMS and InkProf's own routines. The aim is to extend the practical service life of working instruments, make use of existing investments and reduce dependence on a single vendor's software lifecycle. Open data formats and preserved original measurements make results easier to reuse when software or computers are replaced.

## Verified statements

| Instrument | X-Rite's statement | Source |
|---|---|---|
| First-generation i1Pro, revision A-D | Support was removed from i1Profiler 3.2.0. X-Rite refers to 3.1.1 for continued use in a compatible environment. | [X-Rite: i1Pro 1 Support Dropped in i1Profiler 3.2.0](https://www.xrite.com/de/service-support/i1pro1supportdroppedini1profiler320) |
| i1Pro 2 and i1iO 2 | The version information for i1Profiler 3.8.7 states that the instruments are no longer supported. | [X-Rite: i1Profiler 3.8.7](https://www.xrite.com/it-it/service-support/downloads/i/i1profiler-i1publish_v3_8_7) |
| i1Pro 2 / iO2 on macOS | X-Rite's compatibility note gives 3.8.6 as the last supported i1Profiler version. | [X-Rite: i1Pro 2 EOL Notes](https://www.xrite.com/pt-pt/service-support/i1pro-2-eol-notes-compatibility-issues-with-windows-11-macos) |

The statements concern different instrument generations and different software versions. They must not be described as a single date when all older instruments stopped working. Existing installations may still be usable in compatible environments.

## What InkProf needs to verify

ArgyllCMS documents handling of the Eye-One Pro and i1Pro 2 in its [instrument documentation](https://www.argyllcms.com/doc/instruments.html). That gives a technical basis for continued use, but it is not a completed compatibility test of InkProf.

For each supported combination, the instrument model/revision, operating system, Argyll version and measurement mode must be recorded and tested. Both spot measurement and strip (row) measurement must be verified where they are to be offered. The instrument's calibration, repeatability and condition must be assessed; alternative software does not replace physical servicing or prove measurement quality.

The connection between MATLAB, the Python bridge and Argyll is described in [architecture document 002](../decisions/002-matlab-python-chartread.md).
