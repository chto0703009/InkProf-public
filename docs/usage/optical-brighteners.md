# Optical brighteners: OBA, FWA and OBC

> InkProf 1.0.0-rc.2, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Updated 2026-10-02. InkProf now offers selectable D50 compensation in the project definition. The instrument mode of direct measurement is not changed.

## Concepts and physical meaning

**OBA** (Optical Brightening Agents) and **FWA** (Fluorescent Whitening Agents) are two names for the same optical brighteners in paper. **OBC** (Optical Brightener Compensation) means compensation for their effect. All three terms concern the same phenomenon, but OBA/FWA name the substances and OBC names the compensation process. Argyll calls its process FWA compensation; X-Rite uses OBC. These names do not imply identical algorithms or results.

- **OBA (Optical Brightening Agents)** and **FWA (Fluorescent Whitening Agents)** are names for optical brighteners in paper. They absorb UV and emit visible light, mainly in the blue region.
- **OBC (Optical Brightener Compensation)** is X-Rite's name for the compensation, not the substance itself.

The colour of the paper and the print can therefore depend on the UV content of the illumination. An ordinary spectral reflectance curve measured under one measurement light is not sufficient to predict the fluorescence exactly under all other lights. Differences between measurement light and viewing light cannot be solved solely by more RGB patches, better interpolation or a different ICC colour engine.

## Measurement conditions

| Condition | Meaning for this discussion |
|---|---|
| M0 | Traditional measurement condition. The fluorescence excitation need not correspond to D50 viewing. |
| M1 | Intended to correspond to D50 illumination, including relevant UV excitation. |
| M2 | UV is filtered out and the excitation of the brighteners is reduced. |

X-Rite's i1Pro 2 supports M0/M1/M2 in a compatible X-Rite workflow. This does not automatically mean that Argyll's instrument driver or InkProf's current measurement routine exposes all modes. See [chartread and measurement conditions](chart-measurement.md).

M1 is a measurement condition, not a synonym for OBC. Choosing D50 when integrating an M0 spectrum does not make the measurement a physical M1 measurement.

## Using FWA/OBA in InkProf

Open **Project details → Project and materials** and select **Compensate optical brighteners (D50)**. The option is off by default and can be changed even after measurement, profiling or export. It is saved centrally as `printing.fwaCompensation` in the project's JSON.

Changing only compensation preserves locked B1 but makes B2 and later profile results stale. Use the preserved input, save a new B2 recipe and rebuild, then make new checks and approval. Original measurements, earlier recipes, ICC files and reports are kept; the change with before/after values is documented in workflow.json and the result log. An ICC file that has already been exported is not changed.

InkProf uses Argyll `-f D50` together with `-i D50 -o 1931_2`. The same compensation carries over to training check, adaptive evaluation and C3. Recipes, command logs and final reports document the calculation conditions. Early analyses of the raw measurement remain uncompensated and do not change the saved original spectral values.

This implementation requires:

- Original spectral data in known M0 mode, with instrument identity in TI3.
- No UV filtering and no earlier FWA compensation.
- Measured white spectra from the current basis, locked source controls, or an explicitly approved blank-paper reference.

XYZ-only, unknown measurement mode, M1, M2 and already compensated measurements are stopped for this compensation option. M1 data can still be used without this M0 compensation. The simulated D50 response is **not a physical or certified M1 measurement**. Imported data are never relabelled.

C2 adds a paper-white reference patch when FWA is on. It is used for the compensation model and excluded from independent error statistics and improvement prioritisation. New recipes can use an explicitly recorded saved white reference when the current measured basis has none. Older recipes retain their original missing-white restriction.

## English quick guide

Open **Project details → Project and materials → Compensate optical brighteners (D50)**. You may change this after profiling. Keep B1 when only compensation changes; recreate B2 and subsequent profiling/validation stages. Existing profiles and reports remain on disk; the JSON history records the change. Native M0 spectra, a known non-UV-filtered instrument and a measured paper-white patch are required. Compensation simulates D50; it does not certify an M1 measurement. The same FWA settings are used for profile building and evaluation.

## What Argyll can do

Argyll's `colprof -f` activates model-based FWA compensation. According to the documentation, spectral data and measurement without a UV filter are required. The method estimates how spectral measurement values would change with a different excitation of the brighteners.

Argyll distinguishes between compensation for a viewing light and simulation of the instrument's measurement illumination. The documentation describes, among others, the combination `-f -i D50` and simulation via `-f M1` or `-f M2`. InkProf exposes D50 compensation; other simulated lights are not selectable in the app. A simulated M1/M2 response must not be presented as directly measured M1/M2.

For a real viewing light, its spectral distribution, including UV, is relevant. The same colour temperature or white point does not guarantee the same fluorescence. Argyll describes `illumread` as a way to estimate the UV content indirectly. Compensation should therefore be introduced as a separate, verifiable recipe, not as a hidden default setting.

## Recommended further work

1. Use consistent compensation conditions within a candidate comparison. A change requires rebuilding and new checks.
2. Examine **unprinted paper white** and a few light grey patches with M1 and M2 in a workflow that actually supports the conditions. The same paper, backing, instrument, geometry and drying conditions must be used. The differences give diagnostic information about the significance of the brighteners, not a universal correction factor.
3. Document the intended viewing light. A purported D50 light also needs to be assessed with regard to spectral distribution and UV.
4. If needed, create a separate profile recipe for compensation. Preserve raw spectra, original measurement condition, instrument information, compensation method, parameters and engine version together with the derived information.
5. Verify profiling and C2/C3 under consistent conditions. Do not mix compensated profile prediction with uncompensated reference values without an explicit method and reporting. Avoid double compensation of already processed imported data.

We have not yet shown that optical brighteners cause the current local errors in InkProf. This is a possible separate error source to investigate, not an established explanation for M5, U22 or other deviations. A good fit to M0 data does not guarantee the same visual agreement under other UV content.

## Sources

- [X-Rite: Optical Brightener Compensation](https://www.xrite.com/-/media/xrite/files/literature/l7/l7-400_l7-499/l7-439_x-rite_i1_family_optical_brightener_compensation/l7-439_obc_en.pdf)
- [X-Rite: i1Pro 2 User Guide](https://www.xrite.com/-/media/xrite/files/manuals_and_userguides/e/eo2-qsg_i1pro_2_user_guide_en.pdf)
- [ArgyllCMS: colprof, FWA and illumination](https://www.argyllcms.com/doc/colprof.html)
- [ArgyllCMS: Fluorescent Whitener Additive Compensation](https://www.argyllcms.com/doc/FWA.html)

The sources were reviewed 2026-09-29. The web documentation's features must be checked against the installed Argyll version before they are introduced into code.

The Argyll colprof/profcheck chain with `-f D50` was tested 2026-10-02 with ArgyllCMS 3.5.0 and synthetic spectral data. This verifies the program flow, not physical print accuracy.

## Later choice and reporting (2026-10-02)

FWA need not be chosen when the project is created. The choice can also be made in **B2 → FWA / OBA** or in the FWA question when **Automatic** profiling is started. When the choice is saved, the project definition's `printing.fwaCompensation` is updated. A change is logged in `workflow.json` and the result log with the previous and new choice and where the choice was made. If the selection dialog is cancelled, no new FWA choice is saved.

With a later FWA choice the raw measurement and locked B1 basis are retained. Earlier recipes, profiles and subsequent approvals become out of date but their files remain. A B2 recipe that has just been saved with the new choice becomes current when the step has been completed. Automatic profiling uses the new choice for all candidates. Direct changes to other project information follow the project's usual rules for rebuilding.

The measurement certificate has the section **FWA/OBA - settings and results**. It shows whether compensation was actually used in the delivered profile, the saved project choice, simulated illumination, and ΔE00 mean, P95, maximum and number of patches for training fit and verification print. The information about actual use comes from the profile's saved calculation basis, not just from the checkbox. Older data without a documented FWA mode are stated as **Not documented**. Different FWA modes in the profile and verification data stop the export.

The results are the profile's results with the chosen setting. An improvement or deterioration caused by FWA is not calculated automatically by comparing arbitrary earlier iterations. The certificate states that the effect compared with a corresponding profile without FWA is **Not assessed** when a controlled comparison is not reported. This avoids, for example, new measurements or changed profile smoothing being wrongly attributed to FWA.

## FWA compensation and smoothing

New B2 recipes support FWA compensation with final colprof smoothing and with experimental two-pass Argyll pre-smoothing. Save a new recipe; older recipes and ICCs are unchanged. Native spectra are integrated by Argyll spec2cie with FWA to simulated D50 once. Both colprof passes read that XYZ basis without applying compensation again. Fit, C3 and refinement analysis use the same conversion policy.

The input must have verified native M0, a known non-UV-filtered instrument, no prior compensation, and measured short-wave coverage at or below 400 nm through at least 700 nm. This is visible/near-UV spectral response, not a measurement of the illumination's UV excitation spectrum. In particular, i1Pro2 M0 supplies the best available model estimate in this workflow; it does not become native M1. A UV LED observation can indicate brighteners but is not a quantitative input to this compensation.

Argyll averages all device-white spectra (all RGB channels above 99.9%). The evidence records the count, identities, wavelength grid, mean spectrum and per-band sample standard deviation where available. Averaging may reduce random variation; it cannot recover excitation missing from the M0 illumination or guarantee detection of weak fluorescence. White control patches preserved in locked B1 source data can supply the reference even if excluded from the fitting selection.

If measured white is absent, B2 offers **Measure blank paper**, **Select saved blank-paper reference**, or **Cancel**. Acquisition uses stationary native i1Pro2 M0 readings with explicit calibration/measurement actions. Use the same unprinted stock and backing, sample several clean locations and explicitly accept the mean. The selected instrument and spectral grid must match; calibration standards are checked. Missing colour spectra cannot be repaired by measuring only blank paper.

The approved reference is embedded with its source readings and checksums. During conversion it supplies the missing white reference. The build retains an explicitly named auxiliary measured paper-white anchor so that ICC media white is not inferred solely from coloured samples. Analytical reports compare only the original measured target patches; the auxiliary blank-paper reading is not reported as a target patch or independent validation. Saved references can be carried into continuation on the same documented stock; current measured white takes precedence when available.

`inkprof.measurePaperWhite(b1Folder)` opens acquisition and returns the approved reference JSON path. Scripts can pass `PaperWhiteReferenceFile=referenceFile` to `inkprof.createProfileRecipe`. No missing-white case silently falls back to maxima of coloured spectra or disables compensation.

New jobs save `fwa/fwa-preparation.json`, the compensated XYZ basis and tool log. Original spectra remain unchanged. Certificates disclose the model limitation, white-reference source and count, and separate training/verification evidence. The extension has numerical and integration checks; physical print improvement requires independent measurement.

Sources: [Argyll colprof](https://www.argyllcms.com/doc/colprof.html), [spec2cie](https://www.argyllcms.com/doc/spec2cie.html).

## Best-practice decision and external methods

The [complete profiling appendix](profiling-best-practice.md) puts the compensation choice before comparable builds and final verification. Do not infer a need for compensation merely from yellowish white or fluorescence under a UV lamp. Review native data, paper and intended viewing conditions; preserve the selected policy in the recipe and reports.

[X-Rite’s guidance](https://www.xrite.com/resources/successful-color-management-of-papers-with-optical-brighteners) favours actual M1 for OBA-enhanced substrates. The i1Pro2 hardware supports M1 in compatible workflows; InkProf’s current M0 simulation does not acquire M1 or determine calibrated UV excitation from short-wave spectral bands. White averaging reduces random variation, not this limitation. i1Profiler’s OBC and InkProf’s Argyll-based compensation are distinct implementations; do not claim equivalence or the same accuracy without a controlled comparison. Where the intended reference requires M1, use actual M1 measurement in a compatible workflow rather than labelling compensated M0 as M1.
