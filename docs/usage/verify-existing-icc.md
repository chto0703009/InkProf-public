# Verify an existing printer ICC

InkProf 1.0.0-rc.4 offers a separate project purpose, **Verify existing ICC**, under **New project**. Existing profiling projects keep their original workflow. Project mode is saved in the project and workflow JSON.

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

## Balanced photographic patch selection

External-profile targets use the versioned `inkprof-balanced-photographic-v1` selector. This is InkProf's own synthetic Lab selection, inspired by the idea of a balanced photographic chart, **not a reproduction of ColorChecker SG or its reference values**.

The existing overall quotas remain colours, neutrals, challenges and repeats. Within the reachable colour quota, approximately 15% is reserved for photographic skin-tone candidates and 10% for shadows. The remainder is distributed across lightness, hue and chroma. Neutrals span the candidate lightness range evenly; challenges are distributed across colour regions instead of taking the first difficult candidates. Distinct quantized device RGB values are required, except for intentional repeat patches.

For a 140-patch target, the usual allocation is 97 colours (15 skin-tone, 10 shadow and 72 broad colours), 20 neutrals, 13 challenges and 10 repeats. These are requested quotas: profile reachability and clipping can limit coverage. Reserved-colour shortfalls are filled from other reachable colours and recorded in `verification.json`, together with the selection method, requested/actual group counts and each patch's category. If the profile cannot supply enough distinct patches, generation stops with an explanation. The seed makes the selection reproducible for the same profile and software.

This improves coverage; it does not establish print accuracy or a standardized chart certification. Existing targets and measurements are unchanged. To use the new selection, run **Save verification TIFF16** again and print and measure the new target with its matching TI2. Measurements from an earlier layout must not be reused for the new patch definitions.

### ICC v4 import

Existing-profile verification preserves the selected ICC v4 original. No v2
reconstruction is requested for this workflow. C2 target RGB, forward
predictions and C3 chain diagnostics use LittleCMS on that original, with
absolute colorimetric intent and no BPC. Reachability is a stored B2A/A2B
round-trip diagnostic, not Argyll numerical inversion or proof of gamut.
C3 integrates measured spectra with Argyll `spec2cie` (D50 / 2 degrees),
then compares the resulting Lab with the original ICC predictions.
The certificate and delivered profile refer to the original colour tables.

Argyll target pre-conditioning still needs an explicitly accepted approximate
v2 compatibility copy. Its samples now come from relative A2B and are prepared
with inverse Bradford adaptation for the media white before `colprof` rebuilds
the profile. Numerical comparisons use LittleCMS on both profiles and include
forward and inverse directions. The cache method version has changed so old
copies are not silently reused. Original tables and perceptual behaviour are
not guaranteed by this reconstruction.

Previously imported verification packages are preserved. Re-import the original
v4 profile to use native verification. See the dated
[ICC investigation](../research/icc-v2-v4-compatibility-20261009.md) for the
historical findings and the initial prototype.
