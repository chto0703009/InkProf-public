# 007 - Independent InkProf

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-26. Status: decided architecture. Replaces the dependency on SpectraLab in earlier plans and in decision 006.

InkProf must be installable and runnable without Camera-41 and SpectraLab. The project owns its chart model, its measurements, its colour computations and its history. No path to those projects may be needed in the MATLAB path, the Python environment or the local configuration.

## Responsibilities

- **InkProf / MATLAB Base:** import, validation, patch identity, layout, internal JSON, analysis, export and the user workflow. InkProf's own spectral colorimetry and patch re-reading are built within InkProf.
- **InkProf's Python bridge:** interactive process communication, logging and the lifecycle of Argyll processes. No parallel colour computations.
- **ArgyllCMS:** instrument access, row measurement with `chartread`, later spot measurement with `spotread`, and profile building with `colprof`.

MATLAB Base is the base platform, with no mandatory add-on toolboxes. Python is needed for the interactive bridge, not for target generation. The current bridge uses a POSIX PTY; Windows support for measurement remains. Paths are configured per computer according to the [Python guide](../usage/python-runtime.md).

## Data and re-reading

JSON is the authoritative internal model. Argyll's TI1/TI2/TI3 are the primary exchange formats. For measurement, JSON is exported to TI2; the chartread result TI3 is validated and read back into JSON. The original files are preserved.

A future InkProf re-reading function is to:

- identify the patch by stable ID and physical position,
- preserve earlier measurements,
- create a new revision recording measurement conditions, time, reason and origin.

The user must be able to approve or reject the replacement. Only approved revisions are selected for analysis and export. Row re-reading in chartread and separate spot re-reading are different workflows. Only one instrument process may be active at a time.

## Experience without runtime dependency

SpectraLab and Camera-41 are sources of knowledge. Any reused code is incorporated into and maintained in InkProf, with a checked licence, an origin notice and its own tests. InkProf keeps GPL-3.0-or-later. A shared licence does not mean a shared installation or synchronized versions. ChromIQ is an optional comparison path; its source code is not to be used for further implementation.

## Implemented and remaining

The target workflow and the new chartread prototype have their own implementations. The prototype covers chart JSON, TI2 export, the interactive bridge and TI3 import to separate JSON results. It has been tested with a simulated process and synthetic measurement data, not with physical measurement.

Still remaining: own spot re-reading with approval and revision selection, complete colorimetry, measurement export and the ICC workflow. A saved TI3 or a finished process is not enough as proof of a complete measurement.

## Acceptance of independence

1. Install in an environment without the other projects.
2. Test target, import, export and simulated measurement with only the declared dependencies.
3. Then verify physical calibration, row measurement, interruption, resumption and release of the instrument.

Numerical colour computations are to be tested against independent reference data, not only against the original code.

## Terminal path, 2026-09-26

Python owns the interactive measurement through `startMeasurement`; MATLAB takes back the result through `finishMeasurement`. Chartread handles row re-reading, while InkProf preserves the run results and the link to the chart JSON. This is separate from the later, InkProf-owned spot re-reading. See the [measurement guide](../usage/chart-measurement.md).
