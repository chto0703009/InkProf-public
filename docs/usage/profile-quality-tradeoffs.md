# Accuracy and gradient quality

InkProf evaluates colour accuracy and numerical gradient behaviour separately, then uses both when automatic iteration has reserved development measurements. No numerical selection approves physical print quality.

## In the app

- **Photographic gradients** is available after a current ICC has been built. It evaluates nine paths from sRGB and Adobe RGB (1998), relative colorimetric and perceptual intent, BPC off/on, and float/16-bit/8-bit input and output buffers. It is also available from the RGB gradient window.
- **Compare accuracy and gradients** is available after B1 is locked. Enter final `colprof -r` values, using raw measurements. Each combination builds a separate candidate. The current workflow ICC and selected B2 recipe are preserved.

Comparison results are saved as `comparison.json` and CSV; each candidate has a job folder and photographic gradient report. Inspect the reports, then enter the preferred preprocessing and final `-r` settings in B2 and run Manual B3. The comparison dialog does not adopt or approve a candidate.

## What the photographic check measures

LittleCMS converts a working RGB profile into the printer ICC with the stated intent and BPC, clamps device RGB to its legal range, then evaluates the result through relative A2B into predicted Lab. Integer modes use integer buffers at both ends of the photographic conversion, including quantization of the input. They model these buffer depths, not the printer's ink screening or Photoshop's exact CMM.

The report lists normalized Lab curvature, colour steps, lightness reversals, distinct device RGB values, unchanged steps and longest plateaus. Plateaus in quantized ramps are expected. Floating-point interior curvature is used for candidate comparison. Points at hard device-channel clipping are excluded; this heuristic is not a measured physical-gamut boundary. The interior coverage and number of supported paths are reported. Aggregate curvature values are not comparable when different paths have interior support; inspect matching path records.

## Automatic selection

When development measurements exist and the refinement mode is **Current InkProf**, automatic B3 holds A2B quality at high and compares final `-r` values **0.5, 1.0 and 1.5** by default. In the default **Argyll only** mode, automatic B3 builds one high-quality candidate with final `-r 1.0`. It records the photographic check for every candidate. Existing per-patch and gray regression limits remain in force.

A candidate can replace the baseline when it improves development weighted RMS, or improves mean relative gradient curvature by at least 5% with a development RMS increase of at most 0.05. On each matching float path, curvature P95 and maximum must stay within 25% of the baseline plus a small absolute numerical allowance (1 in normalized curvature units); lightness reversals must not increase and interior coverage may fall by no more than five percentage points, and interior Lab span must retain at least 95% of the baseline minus a 0.1 numerical allowance. This prevents a collapsed gradient from winning solely by being smooth. These are configurable numerical heuristics, not validated visibility thresholds.

Missing gradient evidence prevents a contender from replacing the baseline. The reason is saved in the iteration selection record. Without development measurements, InkProf builds one high-quality candidate (engine-default `-r` in Current InkProf mode) and saves diagnostics; it does not claim that candidate is superior. Automatic mode builds its own raw-input recipes; B2 preprocessing is used by Manual B3, not silently carried into automatic mode.

```matlab
[folder, result] = inkprof.iterateProfile(measurementFile, ...
    RoleFile=roleFile, SmoothingCandidates=[0.5 1 1.5], ...
    GradientTolerance=0.25, MaxAccuracyTradeoff=0.05);

[report, reportFile] = inkprof.checkPhotoGradients(jobFolder);

[T, comparisonFolder] = inkprof.comparePreRegularization(b1Folder, ...
    AvgDev=[], FinalSmoothing=[0.5 1 1.5]);
```

### Measurement certificate evidence

New certificates include the saved photographic-gradient diagnostic matching the selected ICC SHA-256. The certificate records the conversion method, CMM version, samples, tested combinations, eligible float-path coverage, total L* reversals and the largest path curvature P95. Full per-path results, including quantization plateaus and precision, are embedded in the certificate JSON with the diagnostic hash. These are numerical observations, not perceptual pass/fail thresholds or physical print validation. Missing or mismatched evidence is reported as unavailable. Re-run the report step (step 14) to create a new certificate; existing signed or historical certificates are preserved.

### Delivered rendering intents

New B2 recipes request dedicated perceptual gamut mapping with `colprof -s` (generic compression, default 20%). B2 exposes **Perceptual compression (%)**; the MATLAB API uses `PerceptualCompression`. This is a starting setting, not an optimized or measured gamut compression. Relative colorimetric uses B2A1. Absolute colorimetric uses the relative table and media white (wtpt), rather than a separate B2A3 table. New builds require B2A0, a distinct B2A1, and wtpt before publication. The saved job and certificate record the intent settings. Existing recipes and ICC files are preserved: create a new B2 recipe and rebuild B3 to obtain these changes. Imported profiles are not rewritten. See [Argyll colprof documentation](https://www.argyllcms.com/doc/colprof.html).

### Reopen saved comparison results

Run `inkprof.showProfileQualityComparison()` and select the saved `comparison.csv` under the project's `profiles/comparisons/` folder. This displays the existing results without rebuilding candidates or modifying workflow selection. The table converts MATLAB strings to supported cell text and shows missing numerical diagnostics as unavailable.

### Refinement method choice

When choosing **From verification errors** in the refinement step, select:

1. **Argyll only**: Argyll `targen -G`, preconditioned by the current
   checked ICC, generates additional device RGB patches. Existing and nearby
   RGB points are excluded. No InkProf Jacobian is calculated. After measurement,
   the saved choice selects high-quality `colprof` with final `-r1.0` and no
   InkProf pre-regularization. The result still requires a new C2/C3 print check.
2. **Current InkProf**: retain C3 residual/Jacobian-guided sampling and the
   existing continuation candidate-selection behaviour.

The choice is saved as `refinementMode` in the proposal and carried into the
continuation and iteration options. Older proposals default to Current InkProf.
This route uses Argyll target placement and profile fitting. Target size, printer,
measurement system and rendering settings remain project-specific. Controls,
provenance and measurement handling remain managed by InkProf. Image-guided
refinement remains a separate source choice.

### Current Argyll defaults

B2 offers raw measurements (default) and optional experimental Argyll pre-smoothing. Final colprof -r remains editable. Refinement defaults to Argyll only; Jacobian sampling is a separate option. See [profiling paths](profiling-paths.md) for the distinction between Manual and Automatic builds.

## Keith Cooper: photographic printer test images

Keith Cooper (Northlight Images) provides printer test images and assessment notes, including the Datacolor image made available courtesy of Datacolor. Use it for overall photographic assessment of skin tones, neutrals, shadows and saturated colours. In InkProf comparisons, inspect the sky gradient for banding or uneven transitions when assessing smoothing; it is a visual diagnostic, not proof of a particular cause. Compare the same source, ICC path, intent, BPC, print preset and viewing light. The original Adobe RGB photograph needs one intended printer-profile conversion; an already converted device-RGB version must receive no second conversion. Do not apply fitting-target opening instructions to the original photograph. JPEG quantisation and clipping can also produce visible steps; use synthetic high-precision gradients alongside it. Download from Keith Cooper’s page; the image is not distributed in the InkProf repository.

Source and downloads: [Keith Cooper — Printer Test Images, Northlight Images](https://www.northlight-images.co.uk/printer-test-images/).
