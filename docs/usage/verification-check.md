# C3 – analysis of a measured verification print

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Implemented 2026-09-28. MATLAB Base is the interface; Python/Colour and ArgyllCMS profcheck do the analysis. The analysis routine does not open any instrument.

```matlab
setupInkProf();
[report, reportFile] = inkprof.checkVerificationTarget();
```

First choose the C2 package's **verification.json**, then the measurement's saved **measurement-….json**. The unchanged TI3 revision with the same base name, chart.json and source.ti2 must still be in the measurement folder. JSON is InkProf's internal traceability record; an external TI3/MXF is first imported through the ordinary measurement workflow.

For a repeated analysis:

```matlab
[report, reportFile] = inkprof.checkVerificationTarget( ...
    verificationFile, measurementFile, ...
    PrintSettings=struct('application','Adobe Photoshop', ...
                        'evidenceStatus','Screenshots pending'));
```

`ShowDialog=false` gives the same saved report without a window. `PrintSettings` is the user's description, **not a verification**; give only information that is actually known.

The window's filter shows all patches, unique patches, gray scale, colours, challenge, repeats, or unique colours judged reachable by the model. Rows are sorted with the largest ΔE00 first. Desired and measured Lab each have separate L*, a* and b* columns. Numeric values are right-aligned; Lab, ΔE00 and summary values display one decimal. Page numbers and IDs have no decimal suffix. Saved reports retain full precision.

## Comparison and traceability

- **Identity.** Patch ID, coordinate, RGB and completeness are checked against the C2 definition. After reordering, the reference's `id` can differ from the print's TI2 ID. The explicit mapping `placement.sampleId` is then used; the analysis does not guess identity from colour similarity or row order. The report's `sampleId` is the reference ID and `measurementSampleId` is the measurement file's ID. The mapping must be one-to-one, and coordinate and RGB must still match. Older material without `placement.sampleId` requires the same ID in the reference and the measurement file.
- **Hashes.** SHA256 is checked for the ICC, TI2, chart.json and the TI3 revision. If an input file changes during the analysis, reporting is aborted.
- **Colorimetry.** Argyll profcheck integrates the spectral data with D50/1931_2, with the same optional FWA/D50 compensation as the profile recipe. Measured Lab is read with six decimals. The same Argyll method is used in the profile's training check; the separate general spectral integrator is not used here.
- **Primary ΔE00** compares the **desired absolute D50 Lab** with the measured Lab. The difference from the profile's prediction is a separate diagnostic value.
- **Groups.** The main statistics include all unique patches, including challenge, but not their extra repeats. Group statistics separate out challenge and gray scale. Reachable by the model does not mean proven physical gamut. Dark means desired L* < 25; highChroma means desired C*ab ≥ 40. Groups can overlap.
- **Gray balance** is reported as the signed mean deviation in L*, a*, b*, and the measured C*ab of the intended neutral patches.
- **Repeats.** Separate repeated patches are compared with their originals. That variation includes both print position and measurement. The comparison of forward and return sweeps is kept separately in JSON and concerns repeatability, not colour accuracy.

Each run creates, under the verification target:

- `checks/<uuid>/verification-check.json`,
- a Markdown report with all patches,
- `profcheck.log`.

The project manifest is updated, and the sources' paths and hash values are saved. No measurements or ICC files are overwritten.

## Decision and remaining control

The current C3 gives status `insufficient-evidence` and `qualityValidated=false`. This is intentional: the report is diagnostic and does not change the profile's status to approved. Automatic acceptance and profile ranking are not implemented. A final decision needs a verified print chain and agreed limits for colour error and gray balance. ISSUE-001 on measurement noise and the inverse remains open.

The C2 TIFF has already been converted with the printer profile, absolute colorimetric, without black point compensation. It must not be converted again when printing.

**Double colour-management check.** C3 also simulates the most common print-chain mistake: the TIFF values treated as sRGB or Adobe RGB (1998) and converted with the printer ICC (LittleCMS, relative colorimetric, no BPC). If the measurement matches that simulation much better than the desired colours (direct mean ΔE00 ≥ 3 and simulated mean ≤ 0.6 × direct), the report and the C3 window show a warning, and the reason is listed first in `decisionReasons`. The result is stored in `colourManagementCheck`. It is a heuristic: clogged nozzles or wrong media can give similar patterns. On 2026-10-07 it identified a C2 print where Photoshop had assigned Adobe RGB (1998) to the untagged TIFF (12.4 ΔE00 against the desired colours, 5.3 against the simulated Adobe RGB chain). Photoshop **Printer Manages Colors** and a greyed-out **Off** in the driver do not prove that the chain has no further conversion. The current run of 2026-09-28 saves these user-reported choices as unverified; screenshots are pending. Another print method may require a new, unconverted target.

A verification target used for later model improvement becomes training data, and a new separate final control target is then required.

C3 also saves `iteration-feedback.json`, `iteration-feedback.md` and `feedback.log` for further diagnostics. For your own limits and re-analysis of an existing result, see [verification feedback](verification-feedback.md).

In the table, `Measured vs desired (dE00)` is the measured against the desired colour. `Model vs measurement (dE00)` is the model's prediction against the measured colour. The latter was previously called `dE00 predicted`, which could be misread as the predicted error against the target. The JSON field `predictedDeltaE00` is kept for compatibility and still means model against measurement.

## Certificate regularization evidence

New certificates record the selected job's saved pre-regularization method and its assumed noise (`avgdev`), final ICC `colprof -r`, rendering-intent settings and the saved model-change summary. Model change is measured against raw observations and is not print accuracy or evidence of absence of banding. Missing recipe/result evidence is stated explicitly; imported ICC verification cannot infer original build settings. The same summary is included in PDF, HTML and text, with structured parameters and result evidence in JSON. Existing certificates remain unchanged; rerun certificate export to create a new report.

A photographic-gradient report is included only when its ICC SHA-256 matches the selected profile. CMM, samples, tested combinations, float-path coverage, reversals and curvature are summarized; complete diagnostic evidence and its hash are embedded in JSON. These are numerical observations, not perceptual acceptance thresholds or proof of absent banding.

## Optional measurement point viewer in the certificate

When saving a certificate in step 14 or step 19, choose **All measurements** or **Latest measurements** under **3D and patch comparison**
to include `all-measurements.html` and its JSON data in the delivery folder.
Open the link **Open 3D and patch comparison** in the certificate HTML.
The viewer works offline and needs no external libraries or network connection.

It includes every patch in the current ICC's fitting report, including accumulated
refinement inputs, and (step 14 only) all current C3 measurement patches as a
separate group. It does not merge unrelated measurements from the project.
Imported profiles have no fitting cloud when the original data are unavailable.
Circles and squares distinguish fitting and verification; controls hide groups,
filter L*, and show the translucent predicted ICC surface. Drag to rotate and
click a point for its ID, measured Lab, available device RGB and the group's
Delta E00 comparison. Fitting Lab follows the saved fit colourimetry (including
FWA compensation); verification Lab follows C3 colourimetry. Repeated colours
and paper white remain included. These points do not establish a measured gamut
boundary or independent verification of the fitting data.

This option adds an interactive HTML companion; the PDF certificate keeps its
existing figures. Share the whole delivery folder so that the viewer link works.

The same choice controls a compact comparison table in the certificate HTML and
the interactive viewer. It selects up to 100 largest unrounded ΔE00 values strictly above
1 and displays the selected patches in ascending order, with desired, predicted and measured swatches when available.
This display threshold is not an acceptance limit. Latest selects current C3
measurements in step 14, or fitting measurements in step 19. All includes fitting
and current C3. Group controls and the L* filter also update the viewer table.

Certificate export also creates a Swedish PDF (`-sv.pdf`). English PDF, Swedish
PDF and the English-only measurement supplement are published at the delivery
folder root. The HTML remains English. The full supplement includes every fitting
and current verification patch, colour previews, Lab values, hashes and history.
Visible timestamps use local time with a UTC offset. The PDF verification plot
shows the L* 40–60 band. Never regenerate a registered export in place; use a new
workflow export to keep project and workflow artifact checksums consistent.
