# Importing a measurement file for analysis and profiling

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Status: basic workflow implemented 2026-09-27. `inkprof.importMeasurement`
opens a file chooser for TI3/MXF and uses the same internal measurement model and
spot-measurement revisions. Limitations and remaining verification are stated below.

## Warning: MXF may need additional information

**An imported MXF may contain complete measurement values yet still lack information needed for traceable and reproducible profiling.** Check and, where necessary, supplement:

- Printer model and exact paper product; Glossy/Matte only indicates the paper surface.
- Driver/version, media type, print quality and relevant print options.
- Print application and colour management: whether the print was made without profile conversion, or which profile was applied and how.
- Measurement conditions, instrument and calibration standard when these are not stated unambiguously.

Missing information must be reported as **unknown**, not filled in by assumption. Generic or contradictory metadata fields must not be treated as confirmed print settings. Supplements must refer to the actual print that was measured, not a later print or the application's current default choices.

Documentation requirement: the user's supplements must be saved in JSON with a clear origin as user-supplied information, kept separate from the source file's metadata. The original MXF and earlier measurement values must be preserved unchanged. A complete patch count is not in itself confirmation of complete print provenance.

In the current workflow the information is reviewed in B1 and print details are supplemented in [B2's recipe dialog](profile-recipe.md). These additions apply to the new recipe and do not change the locked B1 basis. The requirement above also describes the desired clarity of the import dialog; this documentation change introduces no new dialog feature.

## The user selects the measurement file

InkProf should let the user select a measurement file, normally **TI3 or MXF**.
The user should not have to find or specify a JSON file. JSON is InkProf's
internal data model and is created after validated import.

**TI2** normally describes the target's patch definition and layout, not the
measurement performed. A TI2 can be used as supplementary target information.
If the user selects a TI2 without measurement data, the program should explain this and
ask for the measurement file. The file extension alone is not proof of the file's content.

## Checks before import

InkProf should check:

- That the file can be parsed and that its content corresponds to a supported format.
- That the control values are RGB. CMYK should be reported as the wrong colour format for InkProf.
- Patch count, identities, duplicates and the link between control values and
  measured values. Repeated RGB values are allowed but must not be used as
  sole unique identities.
- That measured spectra and/or XYZ/Lab exist, with declared or verifiably
  derived scales and numerically valid values. Reflectance above
  100 percent must not be clipped automatically; the cause and measurement conditions must be considered.
- Wavelengths, spectral range and associated colour specifications.
- Measurement conditions such as M0/M1/M2, instrument and calibration standard when these
  are present. Missing or derived information must be reported as such.
- The order of the patches, coordinates and page division when these are present in the source.
  Missing layout must not be replaced by a guess about what the print looked like.
- Agreement with the project's target, if there is one: patch identity,
  RGB and available physical layout. If the layouts differ, a verified
  mapping between the definitions is required.

Multiple measurement conditions or repeated measurements must be preserved separately and identified.
The program must not silently pick the first group or average them.
A suspected reversed row should produce a diagnosis, not automatic reordering of measurement data.

## Result in the import window

The window should show source file, format, number of patches, available measurement values,
measurement conditions and the result of target matching, as well as errors and warnings.

If the file contains sufficient and unambiguous target information, no extra
file should be required. If necessary information is missing, the user should be able to choose a
supplementary target file, for example TI2. An ambiguous patch mapping should stop the
import as usable profiling input until it has been resolved.

A successful import means that data has been parsed and correctly mapped. It is
not proof of measurement quality or that an ICC profile will be correct.
Unresolved quality warnings should follow along to later analysis and profiling.
All texts in the implemented user interface must be in English.

## Internal JSON and traceability

After approved import, InkProf should save data in the project's common internal
JSON model and update the project manifest. The following must be preserved:

- The original file and its hash, original file name and source path.
- Control values, measured values, scales and an explicit patch mapping.
- The source's order, coordinates, pages and metadata, including paper type.
- Measurement conditions and instrument information, distinguishing between reported,
  derived and unknown.
- The importer's version, import time, validation result and warnings.
- Any transformations, for example scale conversion, with traceability to
  original values. Unknown metadata must be preserved without being called verified.

The original file must not be modified. The user continues working with the project and
the measurement; JSON need not be exposed as a mandatory file choice.

## Verification

TI3 → JSON and MXF → JSON should be verified against known reference files, with checking
of all patch mappings, RGB values, spectra and relevant metadata.
The tests should also cover duplicate colours, reordered objects, multiple measurement conditions,
missing information and incorrect mappings.

The successful import test of InkProf's exported MXF in i1Profiler does not
by itself verify the reverse import chain MXF → JSON. That requires its own tests.

See also [the MXF format](../research/i1profiler-interchange/mxf.md) and
[row direction check](row-direction-check.md).

## Running in MATLAB

```matlab
cd('/Users/christer/Desktop/InkProf')
paths = setupInkProf();
[result, measurementFile, sessionFolder] = inkprof.importMeasurement();
```

Select TI3 or MXF. The colour map opens after import; select a patch and choose
re-measurement in the same way as for InkProf's own measurements. `measurementFile`
is returned for scripting but need not be selected by the user.

With specified files, without preview:

```matlab
[result, measurementFile, sessionFolder] = inkprof.importMeasurement( ...
    'measurement.ti3', TargetFile='printed-target.ti2', ShowPreview=false);
```

TI3 requires a matching TI2; an adjacent TI2 is found automatically and checked.
In the interactive workflow a supplementary file chooser opens if none exists.
`SessionFolder` can be specified; it must be new. Otherwise a unique measurement folder is created
in the source's InkProf project, or under the configured project directory.
The project manifest is updated when the import is located in a registered project.

## Implemented MXF variant and re-measurement

The first adapter supports RGB CxF3/Prism with reflectance spectra, explicit
Page/Row/Column and declared spectral specification. RGB 0–255 is converted to
percent, reflectance factors to percent without clipping or resampling.
XYZ is calculated with InkProf's documented D50/2° integration; original
colour values and metadata are preserved in the original file and the objects' XML in JSON.

Each measurement group must have an unambiguous positional mapping to the target. No
matching is done on colour alone or on object order. Source ID, name, physical
page/row/column and the internal ID mapping are saved. The pages' row numbers
are translated to InkProf's global row numbers; the original page is preserved. Empty
layout positions are marked as presentation padding, not measured patches.

If multiple M conditions exist, `Condition="M0"`, `"M1"` or `"M2"` must be specified
explicitly. Other groups are preserved in the original file and as separate source XML
in the import information; they are not mixed with the selected measurement.

MXF without a reliable layout, mixed spectral grids/calibration standards or only
colorimetric values is rejected in this first adapter with an error message.
Supplementary layout matching for such MXF variants remains to be done; the program
must not guess. The converted TI2 file describes the import layout, but
is not a verified instruction for rescanning the whole external target.

Spot re-measurement currently supports i1Pro 2, M0 without FWA and a compatible
calibration standard/wavelength set. A known serial number must match.
Other imports can be analysed but must not be spot-measured with this M0 routine.
A TI3 with unknown measurement condition remains unknown; an explicit `Condition` choice is logged
as user-supplied information and must not contradict the condition reported by the source.

After **Accept replacement** a new JSON revision and an updated
TI3 are saved, which can be used as measurement input for Argyll's ICC generation. The original MXF,
original TI3 and earlier revisions are preserved. A correct file format does not replace
review of remaining measurement warnings before profiling.

Automated tests use synthetic spectra and simulated re-measurement;
they do not contact the instrument. Tests cover duplicate sets of RGB,
reordered objects, multiple pages, condition selection, incorrect coordinates and scales,
serial number check, single replacement and re-import of the new TI3 file.
