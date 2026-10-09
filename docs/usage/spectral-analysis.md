# Spectral analysis with Python

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Implemented 2026-09-26. MATLAB Base calls a separate Python process. The instrument is not used during the analysis.

## Installation per computer

Use InkProf's existing configured Python or the project's `.venv`. The analysis's locked package set has been tested with Python 3.13.6 on macOS Apple Silicon. Choose Python 3.11–3.13 for this set; other operating systems/versions are not qualified by this test.

From the project folder, for the local environment on macOS/Linux:

```bash
.venv/bin/python -m pip install -r requirements-analysis.txt
.venv/bin/python -m pip check
```

On Windows use `.venv\Scripts\python.exe`. Installation is done in the environment that MATLAB actually selects. If necessary, specify `PythonExecutable` directly in the call. See [Python per computer](python-runtime.md). No new packages are needed to use only the existing chartread bridge.

## Run from MATLAB

```matlab
paths=setupInkProf();
[file,folder]=uigetfile('*.json','Select measurement JSON',paths.Projects);
if ~isequal(file,0)
    result=inkprof.analyzeMeasurement(fullfile(folder,file), ...
        SpectralScale=100, Illuminant="D50", Observer="1931_2");
end
```

Select a saved `measurement-....json` of type `inkprof.chart-measurement`, not chart.json, target.json or the TI3 file itself. TI3 is imported first with the existing `inkprof.importChartMeasurement`. Direct MXF import is not added by this function; the format adapter must first deliver the canonical measurement structure.

`SpectralScale` is explicitly required. The value 100 means reflectance in percent; 1 means reflectance as a fraction. The scale is not guessed from the data's maximum. Choose it according to the source format's documentation and the measurement's metadata. The function is for reflectance, not emission spectra.

The result is written to a new time-stamped JSON next to the original. `OutputPath` can specify another name in an existing folder. Existing files are never overwritten. The original's spectra, XYZ and Lab are not changed.

```matlab
result=inkprof.analyzeMeasurement(measurementFile, ...
    SpectralScale=100, OutputPath=fullfile(outputFolder,'analysis-D50.json'));
xyz=result.data.xyz100;
lab=result.data.lab;
```

The derived coordinates are not an ICC profile or a conversion to the printer's RGB. Device RGB is retained as control values and is not interpreted as sRGB.

## Comparing two analyses

```matlab
result=inkprof.analyzeMeasurement(secondMeasurementFile, ...
    SpectralScale=100, ReferenceAnalysis=firstAnalysisFile);
disp(result.comparison.mean);
disp(result.comparison.max);
```

The reference is an earlier analysis JSON. Matching uses patch ID and physical location, not row order. The same patch set and RGB values are required. Illuminant, observer, wavelength basis, white point and calculation method must be identical. The measurement condition must be known and agree: M0, M1 or M2. An unknown condition prevents the comparison but not the spectral calculation itself. The report preserves whether the condition was originally reported or interpreted.

The result contains ΔE00 per patch as well as mean, median, 95th percentile and maximum. The statistics cover all supplied measured rows, including any check or layout fields. This is a comparison between measurements, not automatically a test of profile accuracy. Profile fitting and a separate verification print remain.

## Calculation convention

- Illuminants: D50 (default), D65 and A. Observers: CIE 1931 2° and CIE 1964 10°.
- Linear interpolation to an integration grid with at most 1 nm between points; the original measurement wavelengths are included. Trapezoidal integration over the measured range only.
- No extrapolation of reflectance. A truncated range is warned about and documented. This is not ASTM E308 or a promise of exactly the same numbers as Argyll's method.
- Common normalisation so that a perfect diffuse reflector gets Y=100. No normalisation of individual patches' lightness.
- Lab is calculated with the chosen illumination's white point over the same range. No chromatic adaptation.
- Negative or non-finite reflectance values are rejected. Reflectance above 1 is preserved with a warning, since fluorescence, among other things, can give such values. No values are clipped.
- No compensation for optical brighteners. Measurement condition and calculation illumination are different things; D50 does not mean that the measurement was made in M1.

## JSON and traceability

The job has `schemaVersion=1`, `measurementPath`, `outputPath`, `spectralScale`, `illuminant`, `observer` and optional `referenceAnalysisPath`. Python CLI:

```bash
.venv/bin/python analysis/spectral_analysis.py analysis-job.json
```

The result's `documentType` is `inkprof.spectral-analysis` and `schemaVersion=1`. It contains source path and SHA256, original chart/TI3 hash when present, measurement condition, targetInfo when present, program versions, calculation convention, white point and derived data. The raw spectrum remains in the unchanged measurement file, which is referenced by hash; the analysis file does not replace the raw measurement file. For transport or archiving both should be kept.

The analysis is published as a completely written new file. Errors give process code 2 and an error message, which MATLAB displays through its existing process handling. The run does not automatically choose another Python installation.

## Verification

The Python tests cover physical white/grey/black, D50 white point, scale equivalence, six published CIEDE2000 reference pairs from Sharma/Wu/Dalal (2005), identity matching, incompatible comparisons, incorrect spectra, a single patch, alternative illuminants/observers and overwrite protection. The MATLAB tests verify the whole process call, saving, reference comparison and unchanged source file.

```bash
.venv/bin/python -m unittest discover -s tests -p test_spectral_analysis.py -v
```

For the MATLAB process tests `INKPROF_TEST_PYTHON` is set to the current environment and `tests/testSpectralAnalysis.m` is run. A separate test on a historical 143-patch measurement succeeded; the result is in the local `work/spectral-analysis-acceptance/`. Its measurement condition is missing from the original JSON and has therefore been left unknown. No physical measurement has been made in this implementation.

Verified run: 10 Python analysis tests, 5 MATLAB tests (analysis and Python calls), 3 terminal measurement tests and 3 chartread bridge tests passed. The package check `pip check` passed. These are selected tests, not a run of the whole project's test suite.

## Reusable PDF report

New measurement PDFs use English headings, explanations and table labels. Source filenames and recorded measurement conditions are preserved. Existing PDFs are not rewritten.

Install the report dependencies in the chosen Python environment with `python -m pip install -r requirements-report.txt`.

```matlab
pdfFile=inkprof.exportMeasurementReport(measurementFile,analysisFile, ...
    fullfile(outputFolder,'measurement-report.pdf'));
```

The report contains all supplied patches with ID, coordinate (in the form A4), print page, calculated XYZ/Lab, original XYZ, calculation difference dE00 and a colour swatch per patch. Measurement and analysis are matched with SHA256 and patch identities. An existing PDF is not replaced. The run requires chart.json next to the measurement file and uses the original layout.json when available, otherwise the TI2 session's page/row division. Check targets with renumbered rows need to be interpreted according to their separate check mapping.

The first version requires saved XYZ and analysis D50/1931_2, numbered rows and lettered columns. It is intended for InkProf's usual row layouts. The calculation difference is not profile accuracy. Spectral tables are not included in the PDF; spectra are preserved in the measurement file. The colour swatches are calculated from the analysis's XYZ and white point, adapted with Bradford to sRGB/D65 and clipped to the sRGB range. They are approximate previews, not the printer's RGB control values or colour references. The report is created in Python with ReportLab and bundled portable Vera fonts; no macOS-specific typefaces are required.

### Rough check against TI2

`exportMeasurementReport(..., TargetWarningDeltaE=20)` adds the column **dE TI2**. Values above the limit get `!` and a red underline. The default of 20 is a changeable practical attention limit, not a standard or tolerance for profile accuracy. The number of warnings is shown on the report page. The column **dE calc.** retains the separate comparison between Python and Argyll calculation.

The TI2 estimates are taken from chart.json and matched with ID, position and RGB. XYZ is assumed to follow the TI2 scale of 100. `APPROX_WHITE_POINT` is explicitly treated as the estimates' reference white and adapted with Bradford to D50 before ΔE00. This is a diagnostic assumption, not a certified reference. If XYZ or an unambiguous reference white is missing, the check is shown as unavailable; RGB is not converted arbitrarily to Lab.

A separate `.target-check.json` next to the report saves the limit, assumptions, identities, ΔE00 and flags. No measurement values are deleted or replaced. Large differences may be due to a wrong row, wrong layout, or to the TI2's estimates not describing the printer's colour reproduction.

## Measurement figures and HTML companion

Measurement PDF export also saves a standalone HTML companion. Both display actual measured-spectrum Lab points; PDF uses L*=50 +/-5, while HTML offers 2D/3D. If the chart is linked to a checksum-verified C2 target and ICC, an ICC gamut is generated for that exact profile. PDF shows the exact L*=50 surface intersection; HTML offers 2D/3D. Raw targets without a linked ICC report the gamut as unavailable rather than inferring one from the points. All axes are named L*, a*, b*; 2D fixes L* and plots a* horizontally and b* vertically. Gamut assets are saved beside the report for traceability.
