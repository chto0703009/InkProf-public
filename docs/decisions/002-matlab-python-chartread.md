# 002 - MATLAB, Python bridge and row measurement with ArgyllCMS

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25. Updated: 2026-09-26. Status: own measurement prototype tested in simulation; physical verification remains. Supplements project plan v0.6 and [decision 007](007-independent-inkprof.md).

## Updated decision: terminal-owned measurement session

The recommended implementation is now `startMeasurement` / `finishMeasurement`. Python starts chartread with direct terminal contact and owns the whole measurement session. MATLAB prepares the chart JSON and validates and imports the result afterwards. No ongoing polling or key forwarding from MATLAB is needed. The older JSON-lines/PTY bridge below is kept for troubleshooting and is no longer the recommended user workflow.

Chartread's row re-reading and `-r` are reused. Python saves the earlier TI3 before Resume, and a separate result snapshot after saving. Run metadata is logged, but the new direct terminal path does not yet save the raw dialogue text. See the [current run guide](../usage/chart-measurement.md).

## Direction

InkProf keeps MATLAB Base as its main platform and owns its spectral data and computations itself, without a runtime dependency on SpectraLab or Camera-41. For interactive row measurement, a small separate Python process that controls ArgyllCMS `chartread` is recommended. The bridge is limited to process communication and the state of the measurement session. It must not become a second implementation of colour computations or of the project model.

Python becomes a declared dependency for this integrated measurement path. Import of already measured files and analysis in MATLAB must be usable without the bridge. No ChromIQ adapter is needed.

## Row measurement in ArgyllCMS

`chartread` supports row-by-row measurement for instruments with the corresponding support. The user moves the spectrometer over a row of patches; Argyll handles instrument communication and patch identification. The target's geometry must suit the instrument and the measurement mode.

The input is a `.ti2` file describing the chart. The result is saved as `.ti3`, with spectral data when the instrument provides them. The tool supports re-reading and resuming a partly measured chart with `-r`. The exact instrument model, Argyll version, operating system and measurement mode must be verified in practice.

Continuous capture during the sweep does not automatically mean that MATLAB receives each patch value in real time. The first goal is status feedback after an accepted row, and correct import of the saved measurement data. Live transfer of spectra or patch values is a separate requirement that must be tested; console messages are not a guaranteed streaming data API.

## Division of responsibility

| Part | Responsibility |
|---|---|
| InkProf in MATLAB | Project, target definition, patch identities, print recipe, user interface and profile experiments |
| InkProf's own computation routines (planned) | Spectral colorimetry, XYZ/Lab, ΔE00 and analysis with traceable inputs |
| Python bridge | Start and monitor `chartread`, handle its dialogue, commands, logs and session state |
| ArgyllCMS | Instrument communication, row measurement, patch identification and ICC generation through the respective tools |

Only the Argyll process may own the instrument connection in this measurement path. InkProf must not at the same time open a separate spotread session against the same instrument.

## Why a bridge?

MATLAB can start external programs, but an ordinary `system` call waits for the program to finish. On its own, that does not give a complete solution for ongoing, two-way communication and a responsive user interface during measurement.

Direct process handling from MATLAB is worth investigating. The assessment is nevertheless that a bounded Python process will be easier to maintain, given earlier work in SpectraLab. The choice of language is not decided by the colour mathematics or the speed of measurement, but by robust handling of the interactive process.

The bridge needs to handle calibration requests, the requested row, an accepted or failed sweep, re-reading, interruption and a controlled exit. An interruption must not be reported as a successful save without checking the result file. Measurements that exist only in the process's memory must not be assumed to be secured on disk.

For `targen`, `printtarg` and `colprof` the need for an interactive bridge is smaller. Ordinary process calls can be enough, with separate handling of progress and cancellation if the interface requires it.

## Interface between MATLAB and the bridge

The prototype uses JSON messages over the standard streams, and a POSIX PTY towards chartread. The events are `started`, `output`, `exited` and `error`. Raw console text and result files are preserved. Windows measurement is not yet supported.

Possible future semantic events are "calibration required", "row B requested", "row accepted", "re-reading needed", "result saved" and "session failed". These events are the bridge's contract, not existing standard messages from Argyll.

The original `.ti2` and `.ti3` files, tool version, arguments, session log and link to the target's identity are to be preserved. InkProf in MATLAB is responsible for validating and incorporating measurement data. If console text has to be interpreted, the adapter must be tested against stated Argyll versions, and unknown messages must be reviewable in the raw log.

## Experience from existing programs

SpectraLab's `SpotreadInstrument.m` already uses `ManualSafeBridge.m` and Python for an interactive Argyll workflow. Experience of process lifetime, calibration, errors and diagnostics can be reused, but no calls to SpectraLab may be required. `chartread`, on the other hand, needs its own session handling for the whole chart; the spot-measurement lifecycle must not be copied unchanged.

ChromIQ has `workflow/measure_manager.py`, with a `MeasureManager` that controls `chartread`, interprets messages and handles errors. There is also an alternative measurement helper with JSON communication. This is a historical code observation. Further implementation is to use ordinary ArgyllCMS and InkProf's own adapter, without searching for routines in the ChromIQ code. No third-party code has been imported through this decision.

## First practical verification

1. Document the instrument model, operating system, Argyll version, Python environment and desired measurement mode.
2. Create and print a small chart suited to the instrument's row measurement. Preserve the `.ti2`, the patch identities and the print recipe.
3. Calibrate and read several rows with plain `chartread`, to establish that the instrument workflow itself works.
4. Repeat through the bridge and the MATLAB interface. Test re-reading and the handling of a failed row.
5. Finish with saving and resuming. Check what is actually saved, and test controlled error handling on a lost connection.
6. Import the `.ti3` into InkProf's internal JSON and check patch IDs, units, the spectral wavelength axis, measurement conditions, and that previously accepted values are preserved correctly.
7. Check that the MATLAB interface stays responsive, and that errors or incomplete sessions are never shown as complete measurements.

The test decides the bridge's details. Row measurement is in itself no reason to abandon MATLAB.

## Sources

- [ArgyllCMS: chartread](https://www.argyllcms.com/doc/chartread.html)
- [ArgyllCMS: TI3 format](https://www.argyllcms.com/doc/ti3_format.html)
- [MathWorks: system](https://www.mathworks.com/help/matlab/ref/system.html)
- Local code reviewed 2026-09-25: SpectraLab `SpectraLab_v1.2.1-dev/spectralab/+spectralab/+drivers/SpotreadInstrument.m` and `+spotread/ManualSafeBridge.m`.
- Local code reviewed 2026-09-25: ChromIQ `workflow/measure_manager.py`.
