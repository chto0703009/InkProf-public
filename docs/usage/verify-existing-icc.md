# Verify an existing printer ICC

InkProf 1.0.0-rc.1 offers a separate project purpose, **Verify existing ICC**, under **New project**. Existing profiling projects keep their original workflow. Project mode is saved in the project and workflow JSON.

## Seven steps

1. **Import existing RGB printer ICC.** Select an ICC/ICM file. InkProf validates the supported RGB output structure and copies the profile byte-for-byte into the project. Its original filename and SHA-256 are recorded. Current support requires usable A2B1 and B2A1 LUTs; CMYK, display and unsupported profiles are rejected. This is a structural check, not a quality assessment.
2. **Save verification TIFF16.** The editable suggestion is 575 patches, including repeats (64–2000 supported). The selection covers colours, explicit dark and photographic skin-tone candidates, neutrals, challenges and repeated patches. Gamut screening uses the profile's numerical inverse and is disclosed. The chosen count is saved in project JSON. Paper planning uses existing sheet/roll and measurement-sled settings. Multiple TIFF16 pages can be necessary.
3. **Measure / select verification revision.** Print the saved TIFF16 separately, at 100% size, with ALL further application/driver colour conversion OFF. The ICC was applied once when creating the target, with absolute colorimetric D50 and no black point compensation. Use the documented printer, paper, ink, coating and print settings; allow the configured drying time. Measure with the matching TI2 in the app, or select/import its measurement revision. Patch remeasurement and immutable revisions are available as before.
4. **Analyse profile and print.** The existing C3 analysis checks patch identities and compares spectrally measured D50 Lab both with desired Lab and the profile's prediction. No measurements or pass results are invented.
5. **Review feedback.** Inspect unusual patches, neutral balance and repeatability.
6. **Record assessment for intended use.** Review the evidence and document your intended use and accepted limitations. The result is a user assessment, not automatic ISO certification.
7. **Save measurement certificate.** Project copies of HTML, PDF, JSON, an unchanged ICC copy and supporting evidence are retained. Choose an external destination to copy the complete report folder. Sign the PDF on paper if required. Reference/method explanations are in Appendix A; legal terms follow in Appendix B.

## What the two errors mean

- **Measured versus predicted:** how closely this print agrees with the profile's description of its device RGB.
- **Measured versus desired:** how closely it reaches the requested colour, including the limits of the printer, paper and ink and the effects of the inverse transform.

The certificate reports mean, median, 95th percentile and maximum ΔE00 for both comparisons. Outlier colour chips show target, predicted and measured colours as sRGB previews. Challenge colours are also identified in the detailed results; their large desired-colour errors do not alone prove a defective profile.

Original profile training data are generally unavailable. InkProf therefore reports **unknown independence from training**, rather than claiming all patches are independent of that data. No training-fit, C1 or profile-building results are claimed. This workflow tests a new print; it does not rebuild the imported ICC or make it a newly calibrated profile. FWA processing used when building the external ICC is unknown; verification uses the current native spectral measurement with no new FWA compensation.

Changing print details invalidates the verification target and subsequent steps. Replacing the imported ICC invalidates all subsequent results. Older files remain preserved. Reopening or moving the whole project uses the persisted relative references and integrity checks.

Validated on macOS with automated workflow tests and a real RGB printer ICC for target generation; Windows/Linux and physical print accuracy are not qualified by those tests.
