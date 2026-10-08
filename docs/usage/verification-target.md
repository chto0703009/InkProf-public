# C2 – independent verification target with the ICC applied

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

The first implementation uses **absolute colorimetric, D50/2° and no black point compensation**, as the user chose. The profile is applied once, when the patches' device RGB is computed. The TIFF16 is then written without further colour management and without scaling. The printer ICC is embedded as a TIFF tag only; the pixels are unchanged device RGB. The tag exists because an application such as Photoshop may otherwise assign its working space (for example Adobe RGB 1998) to an untagged file and convert it to the printer profile, which applies the profile twice. When opening in Photoshop, discard/ignore the embedded profile without converting the RGB values, and print with colour management off in the application and driver. The tag remains preserved in the original TIFF as provenance.

```matlab
[folder, reference] = inkprof.createVerificationTarget(jobFolder, ...
    Name="Epson3880-Glossy-C2", ...
    ColourPatches=80, GrayPatches=24, ChallengePatches=12, Repeats=12, ...
    Seed=20260928, DPI=300, Paper="A4-landscape");
```

Without a job argument, a folder chooser opens. The name is given with `Name`, and `OutputFolder` can give your own new folder; otherwise a unique folder is created under the project's `verification`. Existing content is never overwritten.

The app offers paper suggestions for C2 with editable project dimensions. A4 landscape is the default. The existing print standard is used, with the project's editable dimension limits, contrast markers, letters, row numbers, page count and full path.

To build C2 from a fixed reference set (ColorChecker SG, Argyll .cie, TI1), see [profile test with a reference set](profile-test-reference-sets.md).

## Colours and independence

The desired absolute D50 Lab colours are chosen in PCS; they are not copies of the measured training values. Chromatic candidates are sampled with a stored seed, L* 18–90 and a*/b* −75 to 75. Neutral gray samples have a*=b*=0. Print RGB is computed via `xicclu -fb -ia -pl`, quantized to 16 bits, and used unchanged in layout and rendering.

After profile conversion, an RGB value is excluded if it lies closer to any training patch than `MinTrainingRGBDistance` in the max-channel norm (default 1/255 of normalized RGB). Different unique samples must not collapse to the same RGB16. Repeats explicitly duplicate chosen verification patches and keep `repeatOf`. With the defaults there are 116 unique samples and 12 repeats. The randomized print order is traceable in TI2 and JSON.

The selection is model-informed through gamut screening. A separate numerical A2B inversion is used to estimate whether the desired colour can be reached:

| Label | Rule |
|---|---|
| `model-reachable` | residual ≤ 0.5 ΔE00 |
| `outside-or-inversion-unresolved` | all others, since an incomplete numerical inversion does not prove that the colour is outside the gamut |
| challenge samples | chosen among residuals > 3 ΔE00 |

These are selection criteria, not acceptance limits for the profile. Gray samples can also be gamut-limited and are to be reported accordingly.

The output RGB and the profile's predictions are kept separately from **referenceLabD50Absolute**, which is the comparison reference for C3. If verification measurements are later used in retraining, they are no longer independent, and a new final control target is needed.

## Saved package

| File | Content |
|---|---|
| `definition/printer.icc` | Exact copy of the tested profile, with SHA-256. |
| `definition/source-Lab-D50.icc` | Standard Lab representation of the source coordinates, archived as provenance. xicclu receives PCS Lab directly. It must **not** be assigned to the TIFF file. |
| `definition/verification.ti1` | Already profile-converted device RGB and expected XYZ, for layout and patch recognition. The XYZ is a model prediction, not a measurement. |
| `print/target*.tif`, `print/target.ti2`, `print/layout.json` | Verified, existing print package. The same TI2 is used for measurement. |
| `verification.json` | Main reference: desired Lab, separate predictions, roles, repeats, RGB16, page/coordinate, profile hashes, colorimetry, print recipe and file links. |
| `PRINTING.txt` | States pixel conversion and embedded ICC separately: ordinary Lab references are converted once; device-RGB reference sets are not converted. Both have the printer ICC tag. |

The package's pixel verification checks the TIFF against the patch definitions. C2 also checks that every source patch has exactly one placement with the correct RGB16. Contrast markers and padding are not included in the verification's colour score. The project manifest is updated.

If rendering fails, the definition can be saved without a finished print package. Only a main reference with status `ready-to-print-not-measured` marks a complete C2 package. After a correction, generate into a new folder.

## Printing and next step

Use exactly the same physical printer, paper, media and quality settings as when the profile was characterized. The recipe information is carried along, but the actual settings must be confirmed by the user; unknown values do not become verified automatically. No new colour conversion may happen in the application, operating system or driver.

Measure with the matching TI2 and the same documented measurement conditions. C3 computes Lab with the same D50/2° convention and compares it with the desired absolute Lab. Keep model-reachable, other colours, gray samples and repeats apart. C2 only builds the target; the comparison is done separately in [C3](verification-check.md), which is diagnostic and does not approve the profile.

Acceptance limits for ΔE00 and gray balance are recorded as **awaiting user acceptance** in JSON. No arbitrary limits are used to pick a winning profile. ISSUE-001 remains open, and C2 does not perform a full measurement-noise study.

## Preparation feedback and colour management

C2 displays an activity message and elapsed time while checking the profile and preparing colours and paper options. It applies the ICC once, with absolute colorimetric intent and no black-point compensation. The RGB16 TIFF contains device values with the printer ICC embedded as a tag only (packages made before 2026-10-07 have no embedded ICC). Print without an additional profile conversion. This target tests the selected reference colours through the profile; it is distinct from a raw RGB refinement target.

The device-RGB reference-set route is an exception to the once-applied conversion above: RGB is printed directly and reference Lab is predicted from A2B. Both routes embed the identifying printer ICC. Companion instructions record the conversion, tag name and hash, and require printing with application/OS/driver colour conversion disabled. See [TIFF ICC handling](tiff16-dialog.md#icc-conversion-and-the-embedded-tag).
