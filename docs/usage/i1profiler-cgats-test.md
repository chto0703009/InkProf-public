# CGATS measurement export for i1Profiler

This test transfers an existing complete InkProf native M0 spectral measurement
without a new print or measurement. It does not change the current ICC profile.
In the app, select step 14 or 19 and tick **Include CGATS for i1Profiler when saving ICC/certificate** below the TIFF16 copy button. The checkbox starts unchecked when a project is opened and is enabled for these delivery steps in profiling projects. No extra CGATS confirmation dialog appears.

Import and profile creation were verified for the documented i1Profiler 3.8.5 case. Other versions and measurement conditions are not qualified. A command-line entry point is also available.

Run from the repository using the configured Python environment:

```sh
.venv/bin/python exchange/export_i1profiler_cgats.py /path/to/measurement.json /path/to/new-test.txt
```

The measurement must have its matching `chart.json` beside it. The routine checks
its SHA256, patch identity, location and RGB pairing, completeness, native M0,
XRGA and the observed 36-band grid (380–730 nm). It exports all source patches,
including repeated colours with distinct IDs. Spectra are not FWA compensated.
M0 can be inferred in the original measurement; the JSON sidecar preserves this
qualification. No M1 measurement is synthesised.

RGB percent is converted to 0–255 without integer rounding. Spectral percent is
divided by 100, preserving values above 1 for fluorescent samples. Every output
row is parsed back and compared with the source. Existing outputs are refused.
The sidecar records source/output hashes and `recipientImportVerified: false`.

## Recipient test

1. Open RGB printer profiling in i1Profiler, then **Measurement → Load**.
2. Choose the CGATS text file (`.txt`), not the JSON sidecar.
3. Check that the expected patch count is loaded (2,200 for the Canon test),
   RGB values and spectral curves are present, and M0 is used.
4. If import fails, record the exact error and i1Profiler version. Do not change
   RGB rounding or spectral scale silently to make it load.
5. If it loads, save a separate MXF and, if available, CGATS spectral export for
   numerical comparison before declaring the transfer verified.

The CGATS file transfers measurements; it does not reconstruct the physical
multi-page target. SAMPLE_NAME uses letters plus global row, e.g. A32. Physical
positions remain in InkProf's chart. Never use the imported layout to remeasure
the original print without separate layout verification. Recipient-side profile
construction and colour accuracy remain separate tests.

The field names and scales follow a stored spectral export from i1Profiler 3.8.5.
X-Rite documents CGATS measurement import from other applications:
https://www.xrite.com/service-support/downloads/i/i1profiler-i1publish_v3_7_1

## Verified recipient result, 2026-10-16

The user successfully loaded the CGATS `.txt` in RGB Printer → Profiling →
Measurement and created an ICC profile using i1Profiler 3.8.5 on macOS.
A renamed `.mxf` copy had failed with “Error reading CxF version information”;
that failure did not test the CGATS reader. Use the CGATS file-type selection.

The resulting ICC was inspected read-only. Its compressed `CxF ` tag contains
2,200 Target objects and 2,200 M0_Measurement objects. Matching by SampleID
against the source confirmed all source IDs and 36 spectral bands per patch.
Largest spectral difference after conversion back to percent:
1.4210854715202004e-14 percentage points (floating-point precision).
Largest RGB difference: 0.39215666666666493 percentage points, approximately
one step on the 0–255 scale. Embedded RGB values were rounded to integers by
the recipient; the source export retained fractional RGB.

The import view displayed one page, while embedded location tags listed pages
1–4. This observation does not establish physical-layout compatibility.
The retained profile description “Chart 2033 Patches” did not reflect its actual
2,200-patch payload. Import and profile creation are verified for this case;
profile quality, other recipient versions and physical remeasurement are not.
The exporter deliberately keeps `recipientImportVerified: false` in new sidecars:
new files are not automatically recipient-tested by this historical result.

## Cross-engine agreement, 2026-10-16

For the tested Canon measurement, InkProf/Argyll shows good overall agreement
with i1Profiler. Remaining differences are largest in blue and cyan. This is a
comparison between model predictions, not proof of print accuracy or robustness
to measurement noise.

The three supplied ICCs were evaluated using LittleCMS double-precision buffers
on the same 25³ device-RGB grid (15,625 points), with no black-point compensation.

| Difference from i1Profiler | InkProf with FWA/OBA compensation | InkProf without compensation |
|---|---:|---:|
| Mean ΔE00, relative colorimetric | 1.037 | 0.911 |
| Maximum ΔE00, relative colorimetric | 4.874 | 4.312 |
| Mean ΔE00, absolute colorimetric | 1.431 | 0.868 |

Mean differences decreased approximately 12% in relative and 39% in absolute
colorimetry without compensation. The stronger absolute change is consistent
with a paper-white/reference effect. OBA handling contributes, but does not
explain the remaining blue/cyan differences. Attribution is conditional on other
build settings being unchanged; all recipe parameters were not independently
compared. RGB rounding and different fitting/gamut-mapping methods may contribute.

These results support agreement for this measurement and configuration. They do
not establish repeated-build stability, noise robustness (ISSUE-001), equivalence
across printers/papers, or superiority in independent printed verification.

## Export from the InkProf app

When saving the ICC and certificate in step 14 or 19, tick **Include CGATS for i1Profiler when saving ICC/certificate** in the main
window. There is no additional CGATS confirmation dialog. The default is not to include it.
InkProf creates `i1profiler-measurement.txt` and the same-stem provenance JSON
inside the new project export. When saving externally, both files also appear
at the top level of the delivery folder and in its supporting files; receipt
checksums cover the delivered copies.

This option exports the selected original profiling measurement in native M0,
not the FWA-compensated training input, an accumulated refinement dataset, or C2
verification measurements. It is unavailable for external-profile verification
projects without a selected profiling measurement. Unsupported/incomplete sources
are rejected explicitly. A failure does not alter the original measurements or
profile; repeat saving without CGATS if only the ICC/certificate is required.
