# Best practice for profiling and final print verification

This guide covers InkProf RGB printer profiling. The goal is a reproducible profile with measured evidence for its intended use. A possible, valid outcome is that the printer, ink, paper and settings cannot reproduce every reference colour within the selected comparison limits. This must be disclosed; it is neither an automatic profiling failure nor evidence of compliance with a standard.

## Optical-brightener terminology

**OBA** (Optical Brightening Agents) and **FWA** (Fluorescent Whitening Agents) are two names for the same optical brighteners in paper. **OBC** (Optical Brightener Compensation) means compensation for their effect. All three terms concern the same phenomenon, but OBA/FWA name the substances and OBC names the compensation process. Argyll calls its process FWA compensation; X-Rite uses OBC. These names do not imply identical algorithms or results. See [optical brighteners](optical-brighteners.md) for the physical and measurement limitations.

## Agree on the intended use first

Record whether the profile is for photographic printing, a particular reference condition or contract proofing. Agree on the relevant colours, gradients, viewing conditions and acceptance criteria before interpreting results. Where a standard applies, identify its edition, target, measurement conditions and complete requirements. A custom InkProf RGB target is not a Fogra MediaWedge conformity test.

## Stabilise the printing and measurement conditions

Record printer, ink, paper, coating, driver preset, quality and resolution. Check nozzle condition and consistency, allow prints to dry, and use consistent backing and measurement conditions. Record instrument identity and calibration. Keep M0/M1/M2 measurement condition separate from the illuminant used to calculate Lab. FWA compensation is not a replacement for an actual M1 measurement.

Follow the text supplied with each TIFF. Device-RGB fitting targets preserve their RGB values; C2 verification targets already contain the intended ICC transformation. Neither should receive an additional conversion during printing. For these InkProf targets, Photoshop's opening choice is **Discard the embedded profile (don’t color manage)**; disable application colour management and printer-driver colour adjustment. This instruction is specific to these prepared targets, not every image containing a printer ICC.

## Build from trustworthy measurements

Review patch identities, layout, scan direction, abnormal readings and repeatability before accepting and locking inputs in B1. Remeasure suspect rows or patches and save a new revision rather than silently replacing evidence. Correct acquisition errors before changing smoothing or refinement settings.

Record the B2 recipe, final colprof settings, any regularisation and the selected refinement method, **Argyll only** or **InkProf/Jacobian**. Compare accuracy and gradients on equivalent data and paths. A lower training error does not by itself establish better print accuracy or smoother gradients.

## Refine only when the evidence supports it

Inspect local residuals, neutral balance, skin tones, shadows and gradients, including blue gradients. Use new fitting patches where they can resolve a specific uncertainty. Compare iterations at common samples (row 18), keeping training fit, changes between profile predictions and independent measured print error separate.

A practical stopping decision is that comparable measures and visual checks show no useful improvement, or further refinement trades unacceptable accuracy for smoothness. Document the evidence and rationale. Do not treat numerical convergence as proof that desired colours are physically printable, or assume that InkProf automatically establishes a plateau.

## Make the final control print and measure it

After building the selected current profile in row 17:

1. Run row 8, **Fit, Grid and C1**.
2. Run row 9, **C2. Save verification target as TIFF16**, for this exact profile and iteration.
3. Print according to the accompanying instructions, without further colour conversion.
4. Run row 10 to measure the control print and retain its revision.
5. Run row 11, **C3**, and row 12 to review the results and feedback.
6. Run row 13, **Approve for intended use**, entering scope, accepted limitations and review notes. Confirm only when the evidence supports that decision.
7. Run row 14 to deliver the ICC and measurement certificate.

Once a measurement has trained an ICC, it is not an independent verification of that ICC. A final verification measurement should not be folded into a later build while retaining a claim that it verifies that new build. Row 19 is a separate numerical-only delivery route, without current independent print verification.

## Interpret colours the system cannot reproduce

Assess both **Measured print vs desired colour** and **Measured print vs current profile prediction**. A large desired-colour error with a small prediction error is consistent with a reproducible print that cannot match the requested colour, but it does not by itself prove a physical gamut limit. Check profile identity, TIFF RGB, print settings, measurement conditions, inversion and local model reliability before assigning a cause.

Distinguish model-reachable references, outside-model-or-inversion-unresolved references and unclassified references. Model gamut and numerical inversion are estimates; an unresolved inverse is not proof that a colour is physically outside the printer gamut. Paper white, attainable black, chroma and substrate effects can constrain reproduction even with a well fitted profile.

The ISO-related limits in InkProf certificates are comparison references. MediaStandard Print 2018, Table 30, summarises ISO 12647-7:2016 criteria for proofing and the Fogra MediaWedge; those criteria must not be transferred into a blanket pass/fail claim for this custom target. See the [certificate documentation](measurement-certificate.md) and [bvdm source, Table 30, printed page 50](https://www.bvdm-online.de/fileadmin/user_upload/Bundesverband/Technik-Produktion/Richtlinien-Handreichungen/MediaStandard_Print_2018.pdf).

If an applicable requirement is not met, report that fact. Physical limitations may explain the result but do not waive the requirement or permit a claim of conformity. For an agreed photographic use, the user may instead approve the measured result with explicit limitations. If the intended use requires conformity, change the print system or intended reference and verify again, or decline approval for that use.

## Present a fair and complete result

Report all unique assessed colours, their count, mean, median, P95 and maximum error, with difficult colours and repeat controls identified separately. Do not show only worst patches, or hide them behind the overall average. Keep prediction comparisons separate from actual print measurements. Describe the target's sampling and challenge emphasis: it is not automatically representative of every photograph.

PDF gamut is an ICC-derived L*=50 section with a* and b* axes. HTML allows 2D and 3D views of gamut and measured points. The 2D measured-point view uses a disclosed lightness band; gamut geometry is model evidence, while points represent measurements.

The English certificate should identify the delivered ICC, measured iteration, measurement revision, print conditions, limitations and explicit user approval. Historical measurements remain labelled historical. Retain the ICC, target, matching TI2/layout, measurement revisions, build recipe and complete HTML report folder.

Suggested review wording, only when supported by the evidence:

> The delivered profile was verified by measuring a control print produced with the documented settings. It is approved by the reviewer for the stated photographic use with the recorded limitations. Some reference colours exceed the selected comparison limits. The documented evidence indicates limitations of this print system in the identified regions; no claim of ISO conformity is made.

Where the cause is unresolved, replace the causal sentence with: “The cause of the remaining deviations has not been established.” Never describe system limits as established merely because iteration has stopped improving.

## Related guides

- [Complete workflow](workflow-v1.0.md)
- [Measurement certificate and scope](measurement-certificate.md)
- [Profile comparison](profile-comparison.md)
- [Gamut surface and measured-point views](gamut-surface.md)

See [Profiling paths, regularisation and refinement](profiling-paths.md) for the current B2/B3 choices, refinement defaults and settings that are not inherited.

## Complete profiling route: handbook appendix

The same route is included in the Swedish and English handbook appendices. Patch budgets and stopping triggers below are practical recommendations, not mandatory standards or automatic acceptance rules.

### Plan and create the base target

#### 1. Define success before printing

Agree on photographic use or a specific reference condition, viewing light, important colours and gradients, and acceptance criteria. Record printer, ink, paper, driver preset, quality, resolution, backing and instrument. Check nozzles and allow consistent drying time. A custom RGB target does not establish ISO proofing conformity.

#### 2. Use an existing ICC as a starting estimate

Choose a reliable RGB printer ICC for the same printer, ink, paper and settings, or a reasonably similar system. In target generation, select an Argyll method supporting perceptual placement and supply the preconditioning profile. Argyll uses its predictions to distribute device-RGB patches; the base target is not converted through that ICC. A poor or unrelated profile can bias sampling. Without a suitable ICC, use an unconditioned initial target and improve the sampling after the first build.

#### 3. Choose the measurement budget

For a careful full profile used regularly, approximately 1,500–2,000 samples are the practical recommendation. Around 800–1,000 is a lower-budget start with broad RGB coverage, neutrals, shadows, skin tones and distributed controls; the existing 2,000-patch route is appropriate when measurement time permits. A 300–600-sample pilot can reveal setup problems before a larger run. These are workflow recommendations, not a universal optimum or a software default. Reserve space for repeats and several unprinted-white readings; confirm the actual generated count, including controls, in the preview.

#### Decision before saving

Preserve patch size and instrument scan geometry. Choose paper dimensions and inspect the actual page preview. Save the TIFF16 together with its matching TI2, layout and PRINTING.txt. Keep the original ICC and its identity with the project. A target-generation preconditioner is distinct from the profile later built from the measurements.

### Print, measure and decide on OBA

#### 4. Print the prepared RGB target

Follow its PRINTING.txt. In the Photoshop profile-mismatch dialog choose Discard the embedded profile (don’t color manage). Disable colour management in the printing application and colour adjustment in the driver. Print at 100% with the recorded preset. Do not convert to Adobe RGB or apply the printer ICC again. An identifying embedded ICC does not change this instruction. C2 reference targets have already received their specified preparation; their RGB values must also reach the printer unchanged.

#### 5. Measure and review before B1

Calibrate the instrument, use consistent backing and scan direction, and measure all pages. Save each measurement round as a revision. Review identities, white controls, duplicate colours and unusual readings; remeasure suspect patches or a whole row with the correct page and forward/reverse choice. Correct acquisition errors before smoothing. Select and accept the intended revision, then lock B1. Keep different print rounds identifiable.

#### 6. Decide whether FWA/OBA compensation is needed

Do not enable compensation solely because white looks yellow or a UV lamp makes the paper glow. Consider the paper, verified measurement condition and intended viewing light. For the supported i1Pro2 M0 route, compensation is a D50 simulation using available visible spectra, not a measurement of UV excitation or an M1 result. If the paper has little OBA, or the available evidence does not support compensation, retain the uncompensated route and document the choice.

#### If compensation is selected

Use native M0 spectra with verified instrument metadata and sufficient spectral coverage. InkProf averages available white-patch spectra and records their count and variation. If no usable white reference exists, B2 offers blank-paper measurement, a saved approved reference, or Cancel. Measure several clean locations on the same paper with the same backing. Averaging can reduce random noise; it cannot recover missing excitation information. Save a new B2 recipe. Keep compensation and viewing assumptions consistent through comparisons and final verification; changing this choice invalidates later results.

### Build, refine and stop

#### 7. Choose smoothing and the B3 route

Start with Argyll only (raw measurements) when repeatability is good. If noisy measurements or gradients justify it, compare Argyll colprof pre-smoothing (experimental) against the raw route. Its Assumed noise (%) and Smoothing at ICC build are separate settings; 0.5% is the initial recipe value, not an established optimum for every instrument. Check colour fit and equivalent photographic gradient paths. Select the RGB gradient test when useful. For an exact saved B2 recipe, choose Manual in B3; Automatic creates its own recipes and does not inherit every B2 smoothing setting. With FWA and pre-smoothing, use the newly saved supported two-pass recipe.

#### 8. Select the refinement method

Use Argyll only as the initial refinement choice: Argyll places additional patches using the current profile. Current InkProf (Jacobian sampling) uses measured local residuals and local response to propose additional RGB samples. Both routes build the resulting ICC with Argyll. Choose Jacobian sampling when a reproducible local discrepancy warrants targeted investigation; do not expect it to make unattainable colours printable. Save the choice with the proposal. Print and measure the added device-RGB target unchanged, then build the next iteration.

#### 9. Compare equivalent evidence

Use row 18 for Previous profile prediction vs current profile prediction at common samples. Separately review fitting error, development/held-out evidence where available, repeatability, gradients and Measured print vs desired colour. A smaller training error alone is insufficient. A small inverse round-trip error only shows consistency of the model and inverse. Large measured discrepancies require checks of profile identity, RGB values, print management, patch mapping and measurement conditions before attributing them to gamut.

#### 10. Decide whether another iteration is worthwhile

Continue when a specific measured uncertainty can be reduced. Stop when comparable errors and gradients show no useful improvement beyond repeatability, or a further round produces an unacceptable accuracy/smoothness trade-off. One or two comparable rounds without meaningful gain are a practical review trigger, not an automatic InkProf acceptance rule. Record the evidence, selected profile and reason for stopping. Numerical convergence does not prove physical colour accuracy or compliance.

### Final verification and certificate

#### 11. Verify the exact profile to be delivered

After choosing the final iteration, run row 8 (Fit, Grid and C1) and row 9 (C2: save verification TIFF16) for that current profile. Make a new control print with the documented settings and no further colour conversion. Measure it in row 10, retain the revision, and run row 11 (C3) and row 12 (feedback). Do this even if development or training measurements already look good. A measurement used to train a later build cannot independently verify that later ICC.

#### 12. Assess the whole result

Review count, mean, median, P95 and maximum for all assessed unique colours, not only the worst patches. Identify challenge colours, controls and repeatability. Compare desired-colour error with current-profile prediction error where available. Inspect important photographs and gradients. Model-reachable, outside-model/inversion-unresolved and unclassified references describe model evidence; they are not proof of a physical gamut limit. Confirm white, black, neutral balance and the intended viewing conditions.

#### 13. Approve or decline the intended use

In row 13, enter review notes, scope, print settings, limitations and the decision. Approval is justified only by the relevant measured evidence and agreed criteria. If a required standard limit is not met, report it; printer limitations do not waive that requirement. Photographic use may be approved with explicit limitations when agreed, while conformity for a different use is declined. If the remaining cause is unresolved, say so. Row 14 exports the selected ICC and English measurement certificate.

#### 14. Preserve the evidence and status

Check that the certificate identifies this ICC, iteration, current verification revision, regularisation, FWA reference and reviewer decision. Retain the target, TI2/layout, PRINTING.txt, raw measurements, recipe, ICC and complete reports. Row 19 is numerical-only delivery and cannot replace fresh measured verification. If the ICC or print setup changes after approval, repeat final verification. The defensible conclusion is measured and approved for the stated use, with disclosed limits—not automatic ISO approval.

Target-preconditioning behaviour is described in the primary [Argyll targen documentation](https://www.argyllcms.com/doc/targen.html). See also [profiling paths](profiling-paths.md), [OBA limitations and white references](optical-brighteners.md), and [target printing instructions](target-print-standard.md).

### Evidence behind the recommendations

#### Argyll: sampling and measurement quality

The targen documentation supports using a prior or similar ICC to guide perceptual patch placement. printtarg explains instrument-dependent patch geometry and randomised locations, which help identification and distribute spatial printing effects. Preserve the generated layout; do not rearrange patches manually. There is no universally optimal patch count. The suggested budgets in this appendix are InkProf working recommendations to be evaluated against repeatability and independent results.

#### Argyll: smoothing is an uncertainty assumption

colprof defines -r as the assumed average deviation of device and instrument readings, with a default of 0.5%. Raising it gives less weight to individual readings and more to collective behaviour. A percentage is not ΔE00. Estimate the need from repeat readings and compare accuracy and gradients; do not increase smoothing simply to conceal a systematic print error.

#### X-Rite: distinguish M0 compensation from M1

X-Rite describes M1 as the preferred condition for OBA-enhanced substrates and explains that M0 does not fully define UV content. The i1Pro2 hardware supports M1, but the InkProf path described here uses verified M0 data. Recording spectral bands near or below 400 nm does not measure the illumination spectrum or establish calibrated UV excitation. Averaging white readings improves repeatability, not the physical definition of M0. Use actual M1 measurements in a compatible workflow when required by the reference or conformity claim.

#### Fogra: verification needs the relevant reference and control

Fogra links contract-proof verification to its defined MediaWedge, printing condition and applicable tolerances. An InkProf custom RGB verification and reviewer approval are useful evidence for a stated use, but do not substitute for that complete procedure. The independent final control print in this appendix is an InkProf quality-control recommendation.

#### What external sources do not establish

These sources do not demonstrate that InkProf Jacobian sampling outperforms Argyll only, nor that the recommended patch budgets or stopping triggers are universally optimal. Those decisions require comparable local results. Sources reviewed on 8 October 2026; the handbook describes current InkProf behaviour separately from external guidance.

Sources reviewed on 8 October 2026:

- [Argyll: target placement and preconditioning](https://www.argyllcms.com/doc/targen.html)
- [Argyll: patch layout and randomisation](https://www.argyllcms.com/doc/printtarg.html)
- [Argyll: smoothing and profile building](https://www.argyllcms.com/doc/colprof.html)
- [X-Rite: measurement conditions and optical brighteners](https://www.xrite.com/resources/successful-color-management-of-papers-with-optical-brighteners)
- [Fogra: MediaWedge and contract-proof verification](https://fogra.org/en/shop/mediawedge-cmyk)

### Torger and i1Profiler: comparison and practical synthesis

#### Torger: a useful photographic starting point

Torger recommends preconditioning, optimised placement and extra greys. His Colormunki example favours about 840 patches as a practical balance; this is experience with that instrument and print system, not a universal limit. He uses colprof -r1.0 to trade a little fit accuracy for smoothness and evaluates diagnostic gradients and a familiar photograph. His reported profile-matching errors compare predictions with measured device patches, including training-data checks; they are not interchangeable with InkProf C3 errors against desired colours on a separate profile-converted print. His tutorial is primarily a base-profiling workflow, not evidence that InkProf refinement replicates a particular iterative algorithm.

#### i1Profiler: a more extensive measurement route

X-Rite’s recommended RGB workflow proposes 2,033 or 1,586 patches, wider patches for better sampling, about an hour of drying, instrument calibration and saved measurement data. These recommendations concern its own software and layouts: do not blindly increase InkProf patch width or assume one hour guarantees stability for every paper. i1Profiler also offers targeted optimisation and optical-brightener compensation; the internal engine is not Argyll, and its OBC must not be described as identical to InkProf’s M0 method.

#### Reconciled recommendation for InkProf

For a paper used regularly and a careful i1Pro2 profiling job, begin with approximately 1,500–2,000 patches when feasible. Around 800–1,000 is a reasonable lower-budget start; a 300–600-patch pilot is for setup checks. Use a suitable existing ICC for placement, distribute neutral and white controls, and preserve reliable patch geometry. Compare raw Argyll fitting with justified smoothing on the same data. Choose further patches from measured evidence rather than a fixed obligation to iterate.

#### The final decision remains measured

Neither an attractive photograph nor low model-fit error alone establishes measured accuracy for the intended reference. Keep the familiar photographic check and gradient review, then make the independent final C2 print and C3 measurement before reviewer approval and certificate delivery. This combines practical photographic assessment with traceable measurement.

- [Torger: Inkjet printer profiling with Argyll and Colormunki](https://www.torger.se/anders/photography/argyll-print.html)
- [X-Rite: Recommended RGB Printer Profiling With i1Profiler](https://www.xrite.com/it-it/service-support/recommended_rgb_printer_profiling_with_i1profiler)
- [X-Rite: i1Profiler features and targeted optimisation](https://www.xrite.com/-/media/xrite/files/literature/l7/l7-700_l7-799/l7-760-i1-brochure/l7-760_i1_brochure_en.pdf)

## Keith Cooper: photographic printer test images

Keith Cooper (Northlight Images) provides printer test images and assessment notes, including the Datacolor image made available courtesy of Datacolor. Use it for overall photographic assessment of skin tones, neutrals, shadows and saturated colours. In InkProf comparisons, inspect the sky gradient for banding or uneven transitions when assessing smoothing; it is a visual diagnostic, not proof of a particular cause. Compare the same source, ICC path, intent, BPC, print preset and viewing light. The original Adobe RGB photograph needs one intended printer-profile conversion; an already converted device-RGB version must receive no second conversion. Do not apply fitting-target opening instructions to the original photograph. JPEG quantisation and clipping can also produce visible steps; use synthetic high-precision gradients alongside it. Download from Keith Cooper’s page; the image is not distributed in the InkProf repository.

Source and downloads: [Keith Cooper — Printer Test Images, Northlight Images](https://www.northlight-images.co.uk/printer-test-images/).
