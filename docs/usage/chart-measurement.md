# Chart reading and interactive row measurement

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

## Warning: external prints without contrast markers

**Targets printed without contrast markers between the patches can cause problems in row measurement with chartread**, particularly when adjacent patches have similar colours. This can, for example, produce errors if too few or too many patches are detected. A correctly imported patch definition does not guarantee that the existing sheet can be read reliably.

**Recommended workflow:** import the patch definitions as TI1/TI2 in the first instance, or as generic CGATS from another program, and let InkProf generate a new TIFF16 print with contrast markers and matching TI2/JSON. Then use the TI2 of that new print package for the measurement. Contrast markers reduce the risk of segmentation problems but do not guarantee error-free sweeps.

An import or reordering in the program does not change a sheet that has already been printed. If the existing sheet is measured in another program, its measurement file can be imported separately with the patch linkage preserved.


Status 2026-09-26: The Terminal workflow and the MATLAB bridge have read a seven-row contrast target with the i1Pro 2 and imported all 143 source patches. The new modal dialog has been tested with a simulated process and synthetic measurement data; the basic forward flow has also been physically tested with the i1Pro 2. The paired mode with averaging remains to be tested physically. The interactive PTY bridge uses POSIX. InkProf has been tested on macOS only; Linux is untested and Windows is waiting for a separate console adapter.

## Measurement variation, averaging and handling check

Working principle decided 2026-09-29. With correct calibration, placement and reading with the i1Pro 2, we assume for the time being that the instrument's noise contribution is smaller than the print's variation. This is a working assumption based on the user's experience, not an instrument value established here. The instrument contribution therefore need not govern the current profiling iteration, but the assumption shall be open to reconsideration in the event of systematic deviations or poor repeatability.

**Checking shall precede averaging:**

1. Check patch identity, position, measurement conditions and completeness for each reading. Compare the colour values of the repeats before an average result is accepted.
2. In the event of a large difference: flag for review or remeasurement. An average must not hide wrong placement, the wrong row, the wrong patch or a failed sweep. A large difference is a warning signal, not on its own proof of a handling error; print variation can also contribute.
3. For accepted repeats with the same measurement conditions and wavelength grid, an equally weighted **mean spectrum** is used. XYZ and Lab are then calculated from the mean spectrum with a documented illuminant and observer. An average of Lab or ΔE00 does not replace this spectral calculation.
4. Preserve the individual spectra, patch linkages, comparisons, warnings and accepted/excluded readings in JSON, together with how the average was formed. An accepted remeasurement shall not erase earlier evidence.

Repeated measurements of the same physical patch mainly describe the repeatability of the reading. Separately printed patches with the same RGB additionally contain position and print variation. Both are useful but shall be kept apart in the metadata. The same RGB from different print occasions must not be automatically merged without checking paper, settings and any drift.

In the latest C2 measurement, the mean distance between twelve pairs of separately printed repeats was **0.37 ΔE00**, with a maximum of **0.68**. This can be used as an observed variation level for the print and measurement chain. It is **not** a standard deviation, a statistical confidence limit or a universal tolerance. The value shall not be subtracted from every colour error and does not replace the configurable warning limit for repeats.

Small differences between iterations, for example 0.6 versus 0.7 ΔE00, are used as diagnostic information and shall not alone decide the choice of profile when both results are practically sufficient. Prioritise large, recurring local model deviations. See also [verification feedback](verification-feedback.md).

This section documents the working principle; the addition does not change the measurement code. Existing paired averaging and warnings shall not be interpreted to mean that automatic exclusion of faulty readings or separation of printer and instrument noise is already implemented.

## Modal measurement dialog in MATLAB

Interface language: English in the measurement dialog, result map, button texts and confirmations. Argyll's original messages are shown unchanged. The operating system's file chooser and MATLAB's own system errors follow the computer's/MATLAB's language.

```matlab
setupInkProf();
dialog=inkprof.measureChart();
```

Choose the target file (TI2) in the window and enter the settings before **Start measurement**. No instrument process is started when the window opens. A new session folder is created at start; saved measurements are not overwritten. A known target file can also be preselected:

```matlab
dialog=inkprof.measureChart(fullfile(paths.Projects,'mitt-target','target.ti2'));
```

### Three measurement modes

The dialog has exactly three choices under **Scan mode**:

1. **Single direction** (`ScanMode="single"`): one reading per row, left to right. Uses chartread `-B`.
2. **Alternate rows** (`ScanMode="alternating"`, default): row 1 forward, row 2 back, row 3 forward and so on. One reading per row. Uses chartread `-b` for direction recognition. The displayed direction is guidance; the sensor movement is not separately checked.
3. **Forward + reverse average** (`ScanMode="paired"`): the same physical row is read first forward and then back. Then the next physical row follows. Both readings are preserved and averaged patch by patch.

In mode 3, seven physical rows become fourteen logical chartread passes. The original `chart.json` and `source.ti2` are preserved. A separate `paired/` session contains the doubled data. The return pass's RGB, identity linkage and expected XYZ are in reverse physical order; chartread uses `-B` because the direction is already expressed in the data. The dialog shows the physical row and phase, for example **Page 1 · Row 1 · FORWARD scan (1/2)** and **REVERSE scan (2/2)**. No new print is needed. Argyll's raw log uses the logical pass numbers.

`paired-plan.json` links each runtime position to the original's patch index, page, row and sweep. The original readings are saved in `paired/chart.ti3` and separate measurement JSON files. The physical direction is instructed, not independently verified by a motion sensor. A wrong row/direction may therefore still require a reread on a chartread warning.

After complete measurement, `chart-mean.ti3` and a measurement JSON for the original target are created. Each spectral band is averaged with the weights 0.5 and 0.5. XYZ is averaged linearly under the same measurement conditions; this corresponds to the average before the same linear spectral integration. Lab is not averaged; this workflow requires XYZ and spectra. Original data and the pairs' indices are also saved in `pairedReadings`, together with the spectral RMS difference per patch in the original TI3 units. Large differences are shown as numerical comparison data; no universal acceptance limit is assumed. An incomplete pair must not become a complete average result.

An ordinary reread still replaces the selected logical pass. The other half of the pair is a separate entry and is not overwritten. Earlier saved measurements and the original layout remain unchanged. The paired mode has been tested numerically and by dialog simulation; physical verification with the i1Pro 2 remains. At present it requires complete TI2 rows (columns A onward exactly once per row), with numbers for rows and letters for columns; the order of the entries in the file may differ (see *Randomised targets* below).

Other settings:

- **Scan tolerance:** sends `-T`; default 1. Refers to consistency within the patch.
- **Instrument port:** 0 selects chartread's default, a positive number is sent as `-c`.
- Measurement mode, tolerance, port and target file are locked at start. The measurement mode and the actual chartread arguments are saved.

### Result map after saving

After successful saving and import, a separate result window opens automatically. Each square shows the column letter and row number, for example A1, B1 or U7. Page selection is available for multi-page targets. Clicking a square shows its SAMPLE_LOC, patch ID, RGB control values and available measured XYZ/Lab and spectral values. Padding is marked separately; missing measurements are marked as missing.

The colours of the squares come from the target file's RGB values and are an on-screen preview, not a colorimetric rendering of measured XYZ or a measure of colour accuracy. The measured values are shown separately and retain the TI3 scale. The map is schematic in row/column order, not a print file with physical patch dimensions and contrast fields.

The selected square's values are shown clearly above the measurement details: **Measured Lab** when finite Lab values are present directly in the measurement data, otherwise **Target RGB (%) — indication only**. RGB is the target file's control values on the scale 0–100, not measured colour. No hidden conversion of the spectrum is made. A spectrum can be integrated to XYZ and Lab without an ICC profile, but then the illuminant, standard observer and reference white must be defined; this is not part of the preview.

A saved measurement can be reopened with `inkprof.previewMeasurement(sessionFolder)`. The latest saved measurement JSON in the session is then selected. If the result window cannot be shown, the saved measurement still remains; a display error is not classified as a measurement error.

### The measurement dialog

The log and instrument prompts are updated automatically. No manual `poll` or `sendKey` is needed. For an already prepared, new session, `inkprof.MeasurementDialog(sessionFolder)` is used.

- **Calibrate:** place the instrument on the white reference and select the button when it becomes active.
- **Scanning a row:** there is no start button in the dialog; use the instrument button (see *Starting a strip scan* below) and do not trigger an extra scan while the instrument is working.
- **Reread / retry:** used after an error message. Wait for a new row prompt before the next sweep.
- **Previous row / Next row / Next unread:** selects a row, does not start the sweep. To reread an already read row: select it and sweep again.
- **Accept reading:** is activated only on a warning about an unexpected colour response and requires confirmation. Rereading is the first choice.
- **Save and finish:** is activated when chartread reports that all rows have been read. Import takes place only after successful process exit and a check that the definition is unchanged. The result is in `dialog.Result` and as measurement JSON in `dialog.Folder`.
- **Open results folder:** shows the measurement files in the computer's file manager.
- **Close / cancel:** asks for confirmation if the measurement is in progress; unsaved readings may then be lost. The window's close button behaves the same way.

The dialog is limited to new sessions and complete saving. Resuming/partial measurement remains in the Terminal workflow. Unknown or incomplete instrument prompts are shown in the log without automatic keypresses. A complete import confirms patch coverage, not colour accuracy. The modal workflow has been tested physically with the i1Pro 2 forward; the paired mode with averaging remains to be tested with the instrument.

## JSON is the internal model

InkProf uses **JSON internally**. TI2 and TI3 are adapters for communication with ArgyllCMS, not the internal project model:

```text
Approved TI2 from the print package → chart.json
chart.json → temporary/recreated chart.ti2 → chartread
chartread → chart.ti3 → validated measurement-*.json
```

`prepareChart` is the first import adapter to the measurement step. It accepts CTI2 with RGB values, unique patch positions and consistent row/page counts. PXF, TI1 and RGB CGATS shall first be used to create a TIFF/TI2 package. A patch list alone does not specify the physical chart to be measured. "Approved" here means validated file structure and patch linkage, not that paper or instrument have been verified.

## Prepare a session

```matlab
paths=setupInkProf();
sessionFolder=fullfile(paths.Projects,'matning-001');
chart=inkprof.prepareChart( ...
    fullfile(paths.Projects,'mitt-target.ti2'),sessionFolder);
```

For a general `createTarget` package, the data is in the package folder's `target.ti2`. For `createTiff16`, the TI2 has the same base name as the first TIFF file. Always choose the data from the actual print.

The session contains `chart.json` and an unchanged `source.ti2` as provenance. The imported file is not needed in its old location. The JSON contains patch ID, SAMPLE_LOC, RGB in percent, padding marker, row/page parameters and original helper tables/metadata. These preserve, for example, calibration data. Rectangles in millimetres cannot be derived generally from TI2 and are therefore not claimed to exist in this adapter.

Separate exchange can be done with `inkprof.exportChartTi2(chartJson,outputPath)`. No existing output is overwritten.

## Recommended: measure in a separate terminal window

Updated 2026-09-26: Python now owns the entire interactive measurement session. MATLAB opens a terminal window on macOS; chartread gets the terminal's input/output directly. No `poll()` or `sendKey()` is needed in this workflow. Calibration messages, measurement results and warnings are shown automatically. Return and other keys are typed in the **terminal window**, not in MATLAB.

First stop any older `ChartReadSession` with `s.stop()` and check that it has ended. Only one instrument process should run.

```matlab
run=inkprof.startMeasurement(sessionFolder);
```

Calibrate and measure according to chartread's dialog. At the row prompt, use the instrument's button for measurement. Do not also send an extra key that starts the next measurement.

### Remeasuring a row

Chartread already has this support. At the row prompt: use `b` for the previous row and `f` for the next row until the right row number is shown, and read that row again. `n` selects the next unread row. The meaning of the keys depends on the current dialog: on a warning, Return can accept a suspect measurement. Always follow the text shown.

To exit with saving, choose `d` at the row prompt and follow any follow-up questions. Also save a partially measured chart before exiting if you want to continue later. `q`/Esc or closing the terminal can lose unsaved readings.

After Python has reported `saved_unvalidated`, go back to MATLAB:

```matlab
result=inkprof.finishMeasurement(run);
disp(result.complete);
```

MATLAB checks the chart and result hashes, links patches and saves measurement data in internal JSON. `complete=false` means that not all source patches are present yet. A successful process exit does not in itself mean a complete or quality-approved measurement.

To continue a saved session or remeasure rows in a finished chart:

```matlab
run=inkprof.startMeasurement(sessionFolder,Resume=true);
% Measure and save in the terminal.
result=inkprof.finishMeasurement(run);
```

Resume sends `-r` to chartread and requires the same chart JSON as before. The previous TI3 is copied to `before-<runId>.ti3` before chartread starts. A changed result is copied to `result-<runId>.ti3`. MATLAB imports that run's snapshot, not any old TI3. Within an ongoing chartread run, a row reread replaces the row's values; intermediate readings that were never saved cannot be restored by InkProf. Full revision management with user choice is still a later feature. (Note 2026-10-08: saved revisions can now be chosen with `inkprof.selectMeasurementRevision` and the workflow step **3. Measure / select measurement revision**.)

Each run has `terminal-run-<runId>.json` with status, arguments, version, hash and result path. The states are `ready`, `running`, `saved_unvalidated`, `no_new_result`, `failed` or `interrupted`. An unchanged TI3 on Resume does not count as a new measurement result. If the terminal is hard-aborted, the status may remain `running`; no automatic import then takes place.

For stable, direct terminal contact, this version **does not capture raw dialog text to a separate transcript file**. The dialog is in the terminal window; run metadata and TI3 snapshots are saved. The older bridge's transcript applies only to the older path.

On Linux: use `OpenTerminal=false` and run the returned `.command` file from your own terminal. Automatic terminal opening is implemented for macOS; Windows remains. Local paths in the start file are generated on the current computer and shall not be version-controlled as portable settings.

```matlab
run=inkprof.startMeasurement(sessionFolder,OpenTerminal=false);
disp(run.launcher);
```

Python tests have verified terminal connection, numeric TI2, saving, Resume, previous results, changed chart and rejection of a run without a terminal, using a simulated process. MATLAB tests cover start preparation, result import and a manipulated result hash. This is not physical qualification of the new measurement path. The row recognition problems for the printed 575 chart remain to be investigated with a real chartread.

## Older interface: ChartReadSession (troubleshooting)

Create the local Python environment according to the [Python instructions](python-runtime.md). No external Python module is needed. Close other programs that use the spectrometer before starting.

```matlab
s=inkprof.ChartReadSession(sessionFolder);
events=s.poll(10);
```

`poll(10)` waits up to ten seconds for the next event. `poll()` reads immediately available JSON events and shows Argyll's raw dialog text. Call it continuously to see calibration and measurement instructions. The MATLAB command prompt remains available while the process runs. This first version has no graphical measurement window yet and does not interpret free console text as guaranteed states.

Respond only according to the current chartread dialog:

```matlab
s.sendKey(char(13));  % Return when the dialog asks for it
s.poll();
% s.sendKey('d');     % only when chartread offers exit with saving
```

Spectral saving is chartread's default; the bridge does not send `-n`. Nor does it send automatic calibration responses or commands that accept warnings. The instrument port can be chosen with `Port=1` etc. if Argyll's current instrument list requires it; the list and the instrument connection must be checked locally. Specific filter/measurement condition configuration has not yet been introduced in the API.

`stop()` aborts the process and can lose unsaved readings. Clearing the session object closes the control channel and ends the child process. An exit or an existing TI3 is **not** reported as a validated, complete measurement.

## Results and resuming

When chartread has finished and saved the TI3:

```matlab
result=inkprof.importChartMeasurement(sessionFolder);
disp(result.complete);
```

The import checks CTI3, RGB, patch identities and control values against the JSON. It saves a new JSON snapshot and a copy of the TI3 without overwriting the previous result. `complete` refers to coverage of the source patches. Incomplete results are saved with `complete=false`. Anonymous padding rows with ID 0 are not counted as source patches. Spectra and metadata are preserved; no missing spectra or measurement conditions are invented and no spectral scale is normalised automatically.

```matlab
s=inkprof.ChartReadSession(sessionFolder,Resume=true);
```

Resume requires the previous TI3 and the same JSON checksum as the previous run. The previous TI3 file is backed up before the run. A session lock prevents two bridges from using the same session at the same time. Use only one active instrument connection even when different sessions exist.

Each run saves arguments, the tool's version output, raw dialog log and a checksum linking the generated TI2 file to the internal JSON. Without an explicit Resume, start is rejected if a TI3 already exists.

## Verification and limitations

- MATLAB tests: JSON import, TI2 re-export with both the MATLAB and Python adapters, partial/complete synthetic TI3, wrong RGB and control of a simulated child process.
- Python tests: PTY dialog, individual key commands, exit and protection against overwriting an existing TI3.
- A practical basic test with the i1Pro 2 has been carried out: calibration and seven rows with 143 source patches, XYZ and spectra, via Terminal and the MATLAB bridge/dialog. The linkage to TI2 has been checked. The new mode with two sweeps and averaging, as well as robustness during row rereads, cable interruptions and resuming, still requires physical verification.
- Do not use synthetic test results as instrument measurements.

Sources: [chartread](https://www.argyllcms.com/doc/chartread.html), [TI3](https://www.argyllcms.com/doc/ti3_format.html). Local help verified for ArgyllCMS 3.5.0.

## Own spot reread and independence

InkProf has no runtime dependency on SpectraLab or Camera-41. Separate spot reread is implemented with Argyll `spotread`, stable patch linkage, preserved originals and accepted saved revisions. Review and save the candidate; measuring once more does not automatically replace the revision in use. Chartread's row reread and resuming is a different workflow and requires physical verification. See [decision 007](../decisions/007-independent-inkprof.md).

## Correction after the first start test, 2026-09-26

The Python adapter incorrectly put quotation marks around numeric TI2 data. Argyll then rejected RGB_R as text. The adapter now writes numeric data without quotation marks and preserves quotation marks for identities. The real 575 chart has since passed Argyll 3.5.0's reading in external XYZ input mode, without instrument measurement. Start and exit are now shown by the MATLAB control. Original PXF/TIFF/TI2/layout files have not been changed.

## Tolerance and reading direction

`startMeasurement(...,ScanTolerance=1.5,Direction="forward")` sends `-T 1.5 -B`. The default is tolerance 1 and `Direction="auto"`. `Direction="both"` sends `-b` and activates two-way recognition even for non-randomised charts. `forward` requires forward direction in the target's patch order. Auto follows Argyll's choice, which normally turns off two-way recognition for non-randomised targets. The recognition uses expected colour values and can choose the wrong direction if these are unsuitable.

The tolerance value scales the check of variation within a patch; it is not a direct setting of the patch boundary's sensitivity. Test one parameter at a time, without suppressing warnings. Arguments and settings are saved in the run manifest.

A separate data set for rows 13-17 of the existing 575 print has been created in `projects/test-575-rad13-17-T1p5`. It contains 145 positions, of which 143 are source patches and two are padding. Order, values and row names are preserved; the row range in the TI2 index pattern and the number of rows are changed to the subset. The original print and earlier measurement are not changed. No new print is needed. The first test uses `ScanTolerance=1.5,Direction="forward"`. Physical improvement has not yet been verified.

## Measurement conditions: M0, M1 and M2

See also [optical brighteners, OBA/FWA and OBC](optical-brighteners.md) for the difference between measurement conditions, D50 calculation and fluorescence compensation.

The dialog distinguishes between reading direction and measurement condition. For the current i1Pro 2 workflow, the choice **M0 – i1Pro 2 without UV filter** is the default. The alternative **Instrument default – unspecified** leaves the M condition unspecified. M1/M2 are shown as a limitation, not as available direct measurement modes.

Argyll's documentation states that the i1Pro 2's UV measurement mode is not supported. FWA compensation can be used for calculation under other conditions, but it is a separate processing step and must not be labelled as a direct M1/M2 reading. General `chartread -F` options do not prove that a particular instrument supports them. InkProf therefore sends no `-F` command in this i1Pro 2 workflow and performs no FWA calculation during measurement. (Note 2026-10-08: optional D50 FWA compensation of M0 spectra is now available at profile building; see [optical brighteners](optical-brighteners.md).)

The settings are saved in `measurement-settings.json` with the measurement definition's hash, requested condition, reading direction, tolerance and port. Each newly imported measurement JSON contains `measurementCondition`, in which the requested (`requested`), file-reported (`reported`) and interpreted (`interpreted`) conditions are kept separate. M0 can be interpreted from the combination of i1Pro 2 in the TI3 and an unambiguous run log reporting no UV filter. It is then explicitly reported as a conclusion from the instrument/driver, not as an M0 label in the original TI3. If the data is missing, the condition is left unknown. Older saved results are not rewritten automatically.

The condition information is also shown when a square is selected in the result map. The on-screen colours are still target RGB; the choice of M condition does not change the on-screen preview.

Sources: [Argyll: i1Pro 2 and instrument limitations](https://www.argyllcms.com/doc/instruments.html), [chartread: filter selection](https://www.argyllcms.com/doc/chartread.html), [TI3: INSTRUMENT_FILTER](https://www.argyllcms.com/doc/ti3_format.html). Checked against the installed ArgyllCMS 3.5.0 documentation and the official website 2026-09-26.


## Retry a failed calibration (2026-09-27)

If calibration fails, the calibration button becomes **Retry calibration**. Place the instrument on its own white reference and select that button. Repeated failures can be retried in the same session. Row navigation stays disabled until calibration succeeds and chartread presents a row prompt. During calibration the controls are disabled to avoid duplicate keypresses. This change handles chartread calibration failures; it does not add forced recalibration while chartread is waiting for a strip scan.

## Printed page changes (2026-09-27)

The current printed page and row appear in the measurement status. At a page transition, the dialog shows **Change to page X of Y**, the next printed row and its position on that page. Place that sheet in the guide and select **Page loaded**. This acknowledgement sends no key to chartread; press and hold the button on the i1 Pro 2 to scan afterwards. Navigation back across pages also requests the appropriate sheet. Forward/reverse paired passes use the physical page in the paired plan.

Page boundaries come from the imported TI2 `PASSES_IN_STRIPS2`, not from a fixed number of rows. For the 575-patch print with 21 + 7 rows, page 2 begins at printed row 22. Page 1 is assumed loaded initially. The software confirmation gates the dialog controls only: chartread still listens to the instrument hardware button, so do not trigger that button before changing the sheet. No page-change confirmation is required after all rows have been read.

## Paired rereads and warning after saving

In mode 3 the navigation buttons are **Previous scan**, **Next scan** and **Next unread scan**. They move between logical sweeps: row 1 forward, row 1 reverse, row 2 forward, row 2 reverse, and so on. Navigation alone changes no readings. Scanning a selected pass replaces only that pass. On saving, the latest forward and reverse readings for each physical patch receive equal weight; an additional reread is not a third sample in the mean.

After saving, the result window identifies physical rows where any patch differs by more than `PairedWarningDeltaE` (default **1.0 CIEDE2000**) between directions. This configurable threshold concerns repeatability, not the TI2 estimate comparison. Set it through `inkprof.measureChart(..., ScanMode="paired", PairedWarningDeltaE=1)`. Raw readings and diagnostic results remain in the saved measurement JSON. The comparison uses stored XYZ with D50/2. If the optional analysis packages are unavailable, the result explicitly warns that the comparison could not be computed; it never reports that as a passing check. Existing saved measurements are not rewritten.

## Remeasure one patch (i1 Pro 2, M0)

After saving, click a patch in the colour chart, then **Remeasure patch**.
Alternatively, open a saved measurement directly:

```matlab
fig = inkprof.remeasurePatch(measurementFile, "Q1");
```

`measurementFile` is a saved `measurement-*.json`, not a TI2 file. The dialog
uses English labels. Close other instrument sessions first and keep the same
print, backing and instrument. Press **Start spot measurement**, put the
instrument on its own white reference, and press **Calibrate**. A failed
calibration can be retried. Then place it stationary at the centre of the named
patch and click **Measure patch** in the dialog window. Keep the instrument
still until the result appears. Do not swipe or press the instrument button
in this workflow; the dialog sends the measurement trigger.

InkProf shows previous and new D50/2 Lab and their CIEDE2000 difference. This
checks change from the previous measurement, not profile accuracy. **Accept
replacement** creates a new complete measurement JSON and TI3 containing the
replacement. **Discard / Close** leaves the original measurement unchanged.
To take another candidate, close this attempt and reopen the patch dialog.

The selected physical coordinate is supplied by the operator: a spectrometer
cannot identify which printed patch it is placed on. The first implementation
requires i1 Pro 2 native unfiltered reflectance, interpreted as M0, without FWA.
Other conditions are rejected. It explicitly uses D50, the 1931 2-degree
observer and the original XRGA/XRDI/GMDI conversion standard. Wavelengths must
match exactly; no resampling is performed. Where the original instrument
serial can be recovered from its hash-verified transcript, a different serial
is rejected. Otherwise using the same instrument remains the operator's check.

Each attempt has its own `spot-rereads/<timestamp-uuid>/` directory containing
`request.json`, `run.json`, `transcript.txt` and, after a valid reading,
`candidate.json` and `comparison.json`. `decision.json` records acceptance or
discard. The project manifest is updated at preparation, review and decision.
Accepted revisions retain parent and candidate hashes, patch identity and old
values in `patchOverrides`. Parent measurements and raw forward/reverse scans
remain unchanged. The spot value replaces the final value; it is **not** a
third sample in the two-sweep average. Existing forward/reverse warnings are
historical evidence, explicitly labelled as such after replacements.

The implementation is independent of SpectraLab at runtime. The calibration/
reading workflow and strict spectral-block interpretation were adapted from
SpectraLab v1.2.1-dev `tools/spotread_manual_measure.py` and
`spectralab/+spectralab/+drivers/+spotread/Parser.m` (GPLv3). InkProf uses its own
PTY bridge and reflection settings, not SpectraLab's emissive configuration.
Argyll's [spotread documentation](https://www.argyllcms.com/doc/spotread.html)
defines the command-line interface. The transport uses POSIX features. InkProf has been tested on macOS only; Linux and Windows remain untested.

Automated tests use a fake instrument, including failed calibration, retry,
complete spectrum parsing, modal review and discard, immutable replacement,
wrong wavelengths and unchanged neighbouring patches. Physical spot
measurement still needs a user-run check with the actual instrument.

### Find patches with the largest repeatability differences

The saved-measurement window lists all available forward/reverse patch
comparisons, largest dE00 first, with physical coordinate, page and tolerance
status. The largest difference is selected initially. Clicking a table row
opens the correct page, highlights that patch and enables **Remeasure patch**.
Patches within tolerance remain selectable and can also be remeasured.
The values compare the two original sweeps, not the print against a profile.
Accepted spot replacements are marked **Spot replaced**: the old
scan difference is retained as history rather than presented as a new spot
repeatability measurement. If paired comparisons are unavailable, the window
says so; it does not infer differences from nominal target RGB.

After a complete spot result, the bridge closes Argyll automatically. Some
instrument/Argyll combinations first report `Spot read stopped at user request!`
and ask `Hit Esc or Q to give up, any other key to retry:`. InkProf answers this
exit confirmation with a second quit; it must not initiate another reading.
The raw transcript remains available even if process shutdown fails. A timeout
alone therefore does not establish that no physical reading took place.

Before accepting a spot reading, the dialog replaces the transport log with a
six-row table showing previous and new L*, a*, b*, X, Y and Z. The change in
dE00 is prominent and is also included in the Accept button label. The saved
chart distinguishes **Scan dE00** (the original forward/reverse discrepancy)
from **Spot change** (accepted replacement versus previous final value).
Selecting a replaced patch shows its accepted spot Lab. Swatch colours still
represent the target RGB, so they do not change when measurement values change.

The deviation table uses fixed column widths, compact headings and values
rounded to three decimal places for display; stored values retain full
precision. The selected patch uses a red border when it contrasts with the
nominal displayed RGB, otherwise cyan or black/white. An additional inset
black/white outline provides contrast on the patch itself. This is a display
visibility heuristic, not a colourimetric assessment of the printed patch.

## Randomised targets and bidirectional average measurement

Corrected 2026-09-28: TI2 can store entries in SAMPLE_ID order even though the print is randomised. The paired mode therefore sorts its walkthrough by SAMPLE_LOC (numeric row and letter column), and keeps an explicit mapping to the original's JSON index. The original TI2, patch ID and measurement linkage are not changed. Previously, Start measurement could be stopped by this assumption before the instrument started. Start errors are now also shown in an error box, the log and MATLAB's command window.

Verified with synthetic forward/backward measurements and averages for both a randomised and a non-randomised target, as well as the actual C2 target's seven rows/fourteen passes. No instrument measurement was included in the regression tests.


### Starting a strip scan

**Start measurement** connects the instrument and begins the session. **Calibrate** responds to the white-reference prompt. There is no **Start scan** button: at the row prompt, press and hold the i1 Pro 2 instrument button and scan the displayed row, starting and finishing on white paper. Follow the displayed direction. **Reread / retry** clears an error prompt; wait for the row prompt and then use the instrument button again. **Page loaded** only acknowledges a sheet change and never sends a scan trigger.

InkProf-generated charts retain contrast markers as standard. External prints without markers can be harder for chartread to segment; this is not a universal prohibition on measuring charts without markers. If measured in another application, preserve the original MXF under the project's `sources` directory with a unique name. `inkprof.importMeasurement` creates a separate measurement session, preserving the imported source and mapping.


### Row numbers with random patch order

The dialog's row numbers are derived from the TI2 file's physical patch coordinates in row order, not from the order of the entries in the file. This applies to single direction and option 2 (alternating direction), also with Previous/Next and page changes. Option 3 uses its separate linkage between sweep and physical row. A display error for randomised TI2 files was corrected 2026-09-28; chartread could be on row 2 while the dialog showed row 1. Warned readings from such a session shall not be accepted as the right row.


### Hardware scan after page change (2026-09-29)

After changing the sheet, either select **Page loaded** or scan the indicated row
with the instrument button. A new **Strip read OK** also acknowledges the page
of that completed pass. The next prompt shows the current printed page, row and
direction; in paired mode, the first accepted forward scan on page 2 therefore
shows the reverse scan on the same row. Failed scans and Previous/Next navigation
do not acknowledge a page change. Historical successful scans are consumed only
once, so they cannot override a later manual page confirmation. The dialog cannot
verify which physical sheet is in the guide; the operator must still change it.

### Activity during patch remeasurement

Remeasure patch shows progress while preparing the attempt, connecting the spectrometer, calculating the comparison, saving the accepted revision and rebuilding the overview. Calibration and measurement show elapsed time in the status area. Progress closes before a user decision is required. The existing overview remains available until its replacement is ready, and repeated actions are blocked while processing. Closing records the decision and releases the instrument with visible progress.
