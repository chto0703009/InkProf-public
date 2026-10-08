# Verify an existing printer ICC

InkProf 1.0.0-rc.3 offers a separate project purpose, **Verify existing ICC**, under **New project**. Existing profiling projects keep their original workflow. Project mode is saved in the project and workflow JSON.

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

When importing an ICC v4 RGB printer profile, InkProf opens **ICC v4
compatibility** before conversion. **Cancel** aborts the import. **Create v2
copy** preserves the original and creates a separate approximate ICC v2
compatibility profile for Argyll. ICC v2 inputs are copied without conversion.

This is a reconstruction from a 17³ grid of LittleCMS absolute A2B samples,
not a change to the version byte. Argyll rebuilds the output profile, inverse
tables and perceptual mapping. Original rendering behaviour is not guaranteed.
A `conversion.json` records original/converted hashes, commands and relative
and absolute ΔE00 comparisons on 512 separate RGB probes. These are numerical
checks, not print validation. The verification workflow uses the v2 copy and
marks the imported profile as modified. Keep the original for reference.

The same compatibility routine is also used for Argyll target pre-conditioning.
An original SHA-256 plus conversion-method version identifies a shared cache
under `projects/.icc-v2-cache`. All callers reuse and validate the same v2 bytes;
a Cancel choice stops the operation even when a cached copy already exists.
Each imported package retains its own original, converted profile and numerical
conversion evidence. Existing imported packages are not rewritten automatically;
re-import their original v4 file to use this conversion policy. Native ICC
inspection reads the original unchanged. Native LittleCMS source-image colour
handling remains separate from Argyll RGB printer compatibility.

### Opening the device-RGB target in Photoshop

The C2 TIFF contains **printer device RGB**, already calculated by InkProf.
When asked about its embedded printer profile, choose **Discard the embedded
profile / Don't color manage this document**, without converting pixel values.
If it opened with the tag retained, use **Edit > Assign Profile > Don't Color
Manage This Document**. Do not use **Convert to Profile** or convert/assign
Adobe RGB or sRGB. Removing the association does not perform a pixel conversion.

Then print at actual size with no additional application/OS colour conversion
and Epson **Off (No Color Adjustment)**. Do not select Photoshop Manages Colors
with the printer ICC for this prepared target. If the application cannot
preserve device RGB on output, use a suitable unmanaged print utility. Ignoring
the profile on opening alone does not prove an unmanaged print path. The
embedded ICC identifies the profile already used; it is not an instruction to
apply it again. These rules concern InkProf print targets, not arbitrary images.
