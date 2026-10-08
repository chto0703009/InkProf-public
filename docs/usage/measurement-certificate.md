# InkProf - measurement certificate

## Optical-brightener terminology

**OBA** (Optical Brightening Agents) and **FWA** (Fluorescent Whitening Agents) are two names for the same optical brighteners in paper. **OBC** (Optical Brightener Compensation) means compensation for their effect. All three terms concern the same phenomenon, but OBA/FWA name the substances and OBC names the compensation process. Argyll calls its process FWA compensation; X-Rite uses OBC. These names do not imply identical algorithms or results. See [optical brighteners](optical-brighteners.md) for the physical and measurement limitations.

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

The measurement certificate is a handover document for a saved ICC profile. It summarises the project's prerequisites, measurement results and the user's assessment for a client. It replaces the term final report in the app's delivery step.

## Project and results

The certificate contains the project's name and ID, the project manager, the document's user and date, the iteration and a unique certificate ID. Printer, paper and paper surface, ink, driver/RIP, media selection, print quality, printing program, colour management, drying time and other printer settings are taken from the project definition. Missing information is shown as **Not specified**; it is not guessed.

The SHA-256 of the delivered profile identifies exactly which ICC file the result applies to. Training error and the results from the verification print are reported separately. Measurement conditions, any FWA/OBA compensation, source data, assessment and history are included. The certificate reports the evidence; it does not imply accreditation, calibration certification of the instrument or automatic ISO conformance.

## FWA/OBA - choice and results

The certificate reports the actual use of FWA, the project's choice, the simulated illumination and the profile's training and verification results (number of patches, ΔE00 mean, P95 and maximum). Missing documentation is marked as unknown. The result for a compensated profile is not in itself proof of improvement through FWA; a controlled comparison without compensation is not reported automatically. See [FWA/OBA](optical-brighteners.md).

## Physical reproduction capability and limits of the result

The result with an ICC profile depends on what the combination of **printer, paper and ink** can physically reproduce. The paper's whiteness, surface and optical brighteners, the ink's properties and the printer's and driver's settings limit the colour gamut, density, contrast and tone reproduction.

An ICC profile describes this combination and helps colour management reproduce colours within its capability. It cannot create colours or contrast that the materials and equipment cannot reproduce. There is therefore a physical limit to how close the print can come to a desired reference. Colours outside the gamut need to be adapted.

More measurement points or further profile iterations do not guarantee a better result. Measured deviations are also affected by print stability, drying time, measurement conditions and viewing light. The result applies to the documented conditions; changes may require new profiling and verification. This is also explained in the PDF, HTML and text versions of the measurement certificate.

## Responsibility for the limitations of equipment and materials (liability)

The profiling provider is not responsible for deviations caused solely by inherent physical limitations of the printer, paper and ink combination, provided the service was otherwise performed professionally and in accordance with the agreement. An ICC profile does not promise colours, black level, contrast or tonal range beyond that combination's actual capabilities. This limitation does not cover errors in the provider's own work, inadequate instructions or recommendations, breaches of expressly agreed obligations, or liability under mandatory law.

This allocation of responsibility should also be included in the service agreement before the work begins and needs to be assessed in light of the assignment and applicable law. It is no guarantee that every limitation of liability can be enforced.

## The client's prints and information

The following text is included in PDF, HTML, text and JSON:

If the client printed the targets, the client is responsible for following the supplied instructions and providing correct and complete information, including printer, paper, ink, driver and colour-management settings, scaling, drying time and print handling. The profiling provider is not responsible for the client's printing work or resulting profile errors to the extent caused by deficient prints or incorrect or incomplete client information. The certificate records results for the supplied evidence; it does not confirm that the provider verified the client's print process or information. This allocation does not limit responsibility for the provider's own errors, inadequate instructions or obligations under mandatory law.

The allocation of responsibility should be made part of the service agreement and provided to the client before the assignment begins. The fact that the text appears in a subsequent measurement certificate, or that the profiling provider signs the certificate, does not in itself show that the client has accepted a contractual term. The text is a general contract basis and needs to be assessed for the assignment concerned; it is no guarantee of legal validity. If necessary, the term should be reviewed by a lawyer, particularly for consumer assignments.

The delimitation with respect to mandatory law and the provider's own errors is deliberate. The Swedish Consumer Agency (Konsumentverket) describes that terms limiting the consumer's statutory rights in the event of the trader's breach of contract can be unfair. See [Konsumentverket's examples of unfair contract terms](https://www.konsumentverket.se/marknadsratt-foretag/exempel-pa-oskaliga-avtalsvillkor-for-foretag/) and [the Act on Contract Terms in Consumer Relationships](https://www.riksdagen.se/sv/dokument-och-lagar/dokument/svensk-forfattningssamling/lag-19941512-om-avtalsvillkor-i_sfs-1994-1512/) (checked 2026-10-02).

## Date and signature on paper

The PDF file has the document date, user and page number with total page count in the footer. The last page contains the project, certificate ID, document date and the profile's SHA-256, and space for **place and date, signature, printed name and organisation/role**. The signing date is filled in by hand and may differ from the document date.

The signature confirms that the signatory has reviewed the document's prerequisites, results and limitations. InkProf does not sign on behalf of the user. The JSON file states `signature.status = unsigned`; a signature on paper does not automatically update the app and is not a digital signature.

## Workflow and delivery

1. Check the information in **Project details** before profiling and delivery.
2. Complete profiling, verification measurement and assessment.
3. Select **Save ICC and measurement certificate**. Choose your own file names and locations for the ICC and the certificate.
4. Open the document with **Open selected step results → Open PDF report**, review the PDF, print it and sign the last page.
5. Hand over the ICC file together with the measurement certificate. The HTML version's accompanying resource folder must be included if the HTML is handed over.

Older exports are not rewritten automatically. Run the delivery step again for a new certificate. Internal `final-report.*` file names and the JSON type `inkprof.final-report` are retained for compatibility with existing projects. The visible document name is **Measurement certificate**. The app's suggested external file name is `measurement-certificate.pdf`.

## Compact list of patch deviations

Measurement results and patch deviations are gathered in a colour-focused section without a separate statistics table. The visual appendix does not repeat the patch list; complete numerical results remain in the JSON and the text basis.

PDF and HTML show three columns with colour swatch, reference ID, page/coordinate, patch type and measured ΔE00 against the desired D50 Lab. All unique verification patches with ΔE00 > 5 are included and sorted with the largest error first. The selection is made before rounding; no entries are limited to a top list. Colour, grey and challenge patches are included. Repeats and the paper-white FWA reference are excluded. The list is page-broken as needed. If there are no exceedances, this is stated explicitly; missing patch data is stated as not assessable.

The limit is an **ISO-related comparison reference**, not a general classification such as "outside ISO". MediaStandard Print 2018, table 30, reproduces ISO 12647-7:2016 with a max ΔE00 of 5 for all fields in the Fogra MediaWedge. Other criteria and special patch groups have other limits and colour difference measures. InkProf's own RGB verification target is not this control wedge, and the list does not assess full ISO conformance. InkProf's grey diagnostics with ΔE00 2 is not ISO's grey balance measure and is not used as the selection limit in this list.

The sRGB swatch is calculated from measured Lab D50 via Bradford adaptation to D65 and sRGB encoding. Colours outside sRGB are clipped and marked with *. The hex value is saved and shown as text even if the document is printed without colour. The ΔE00 value comes from the C3 measurement comparison and is not calculated from the screen's sRGB colour. The JSON stores the selection limit, source, number of assessed patches, errors, exceedances and colour data for each entry.

Source: [Bundesverband Druck und Medien (bvdm), MediaStandard Print 2018, table 30, printed page 50](https://www.medienverbaende.de/fileadmin/user_upload/01_Global/Downloads_PDF_DOC/Downloads_Technik/MediaStandard_Print_2018.pdf), checked 2026-10-02.

## Instrument identity

On measurement import, the instrument designation and serial number are saved in the measurement's JSON
(`instrument.model`, `instrument.serialNumber`). The source is documented; serial numbers
from the instrument's printout are used only when the printout is linked to the
measurement via SHA-256. Missing information is stated as unknown and conflicting
serial numbers are stopped. Instrument identity is not a certification of calibration.

The measurement certificate's JSON contains `instruments.measurement` and
`instruments.c2measurement`, with the checksum of the respective measurement. Designation
and serial number are shown separately for profiling and verification in PDF, HTML and
text. Older measurements can use their saved, checksum-verified
instrument printout without the original measurement being changed.

Bundesverband Druck und Medien (bvdm) is Germany's trade association for printing and media and the publisher of *MediaStandard Print*. ISO stands for International Organization for Standardization. The industry publication summarises standard requirements; it does not replace the ISO standard itself.

See also [abbreviations and terms](abbreviations.md).


## Exported ICC filename and display name

External ICC delivery defaults to `<project-name>_<YYMMDD>.icc`. The chosen
filename, without its extension, is also written into the ICC profile description
so colour-managed applications can display the same name. Renaming a file later
in Finder does not update this internal description.

Only the delivery copy is renamed internally. The checked project candidate is
preserved. All ICC tag payloads except the profile description remain byte-identical;
the file structure and ICC v4 profile ID are updated as required. This changes the
file checksum without changing the colour transform tables.

The delivery JSON and external PDF/HTML report identify both the delivered file
and its source candidate, with separate SHA-256 checksums. The portable report
bundle includes the named delivery in `underlag/delivered/` and the original
candidate as `underlag/profile.icc`. Existing exports are not modified retroactively;
export again to obtain the matching filename and internal display name.

In step 14, **Open selected step results → Save ICC and report copies...**
opens the ICC save dialog first, followed by the report destination dialog.
The PDF and HTML choices in the results list open the existing reports.


## Certificates for later iterations without a new verification print

Step 19 now exports **measurement-certificate.pdf** and its HTML counterpart,
using the measurement certificate title and layout. The internal JSON type
`inkprof.numerical-report` is retained for compatibility and describes the
evidence scope, not a different user-facing document.

The certificate explicitly states that the current iteration was numerically
checked but not verified by a separate print and measurement. It contains the
current profile identity, project settings, FWA/OBA processing evidence, the
iteration comparison and the user's recorded decision. It does not create an
approval for step 14 or transfer an earlier approval to the current profile.

Where available, the previous archived certificate is checked against its saved
artifact hashes and included as historical evidence in `previous-certificate/`.
Its measurement errors, instruments and colour patches are labelled with the
previous iteration. They are not verification results for the current ICC.
The signature page is followed by **Appendix B - Legal terms** in both PDF and HTML.


## Profile figure in iteration certificates

When a current, checksum-verified profile comparison is available, the certificate
embeds its shared RGB sample data directly. HTML reuses
`analysis/profile_comparison_view.js`: the default view is the a*/b* plane at
L*=50 with a half-width of 5. The L* slider selects a different slice; unchecking
2D displays all lightness levels and enables pointer-drag rotation in 3D.
Controls are local and require no internet connection.

The PDF contains a vector a*/b* slice of the same samples at L*=50 +/-5. Blue denotes
the previous profile and orange the current profile. These are predicted CIELAB
D50 values, not measured gamut boundaries or evidence of improved print accuracy.
No figure is invented when a valid comparison is absent. The source checksum and
current ICC identity are checked before rendering, and the default view settings
are recorded in the report JSON.

## Reference table and appendices (2026-10-03)

After the colour results, both certificate paths show a selected four-row ΔE00 reference table from bvdm MediaStandard Print 2018, Table 30 (printed page 50), summarizing ISO 12647-7:2016. The table is reference context, not automatic pass/fail classification of InkProf RGB targets. It remains present when no patch exceeds the list threshold or when the current iteration has only numerical checks. Historical results keep their iteration scope.

After signing, Appendix A contains expanded organization names, source, standard edition, explanation of metrics and limits of applicability. Appendix B contains legal terms. The versioned resource `resources/certificate-standards.json` is copied into new report JSON as `standardsReference`; PDF, HTML and text use the same values. Existing signed/project certificates are not silently rewritten.

## v1.0.0 project settings

Project details also records dye/pigment ink type, printer coating and coating settings. Matte paper can activate configurable extra dark patch sampling and shadow table emphasis. Read [matte shadow profiling](matte-shadow-profiling.md), [the current workflow](workflow-v1.0.md) and [gamut surface](gamut-surface.md). Certificates distinguish the saved build recipe from requested future patch counts.

## Licences and third-party rights in Appendix B

New PDF, HTML, text and JSON exports also contain a common licence notice: InkProf's GPL licence and disclaimer do not replace any permissions needed for others' copyright, trademarks or patents. The terms of external components are in LICENSE and THIRD_PARTY_NOTICES.md on the project's GitHub. This applies both to print-verified and numerically scoped certificates.

The release's open rights issues are documented in the licence review and the release checklist, not as conclusions about the customer's measurement results. The notice does not resolve a rights issue. Certificates already saved are historical documents and are not changed automatically; create a new export for the updated appendix.

### Colour chips for the last measured result

Each outlier shows target (**Desired**), profile prediction (**Predicted**) and measurement (**Measured**) as adjacent sRGB previews in HTML and PDF. D50 Lab is Bradford-adapted to D65 and clipped to sRGB. Delta E00 still compares measured Lab with target Lab. Historical results retain their original iteration; they are not measurements of the current ICC. Legacy target/prediction colours are recovered only from the checksum-verified accompanying C3 source. Missing evidence is labelled, never inferred from printer RGB.

## Difficult colours and reachability

Certificates disclose model-reachable, outside-model-or-inversion-unresolved, and unknown reference colours separately, with desired-colour error summaries for each available group. Outlier cards show reachability and challenge status. This prevents difficult references from being mistaken for a representative whole-profile accuracy score. Numerical reachability and convergence do not prove physical gamut coverage or print accuracy. An unresolved inverse is not automatically a physically out-of-gamut colour. Review measured-versus-predicted error and independent printed verification as well. Older reports require regeneration.

### Balanced whole-target presentation

New certificates begin the measurement section with counts and percentages for
all unique colour, gray and challenge patches in descriptive dE00 ranges 0–1,
above 1–2, above 2–5 and above 5. These ranges are not contractual acceptance
criteria. Repeat patches and paper-white references are excluded from this
population. HTML and PDF also show every unique measured colour in target order,
with its ID and measured-print-versus-desired error. The sRGB swatches are screen
previews, not colour proofs. Individual cards above 5 remain diagnostic details;
they must not be mistaken for the distribution of the entire result.

Torger's `profcheck -k` example compares the profile with the measurements used
for profiling. C2/C3 independently tests desired colour through conversion,
printing and measurement. These are different experiments, even though both
report CIEDE2000. Compare matching populations and metrics before comparing
numbers: https://www.torger.se/anders/photography/argyll-print.html

### Separate C2/C3 chain diagnostics

Rerunning C3 adds `chainDiagnostics` to the saved verification-check JSON and
shows three separate checks in the C3 window:

1. Desired absolute D50 Lab through ICC B2A then A2B, alongside the round-trip
   for the saved quantized device RGB. Numerical agreement is not proof of
   physical gamut reachability.
2. Saved device RGB16 versus the central 3 × 3 pixels of each rendered TIFF
   patch, using the saved layout rectangles and TIFF resolution. Report the
   mismatch count and maximum code difference; missing layout/TIFF evidence is
   explicitly unavailable. This does not inspect every pixel or prove correct
   colour handling by the printing application.
3. ICC A2B prediction from actual TIFF centre RGB versus measured C3 Lab.
   Summaries exclude repeats and paper-white references. Large disagreement
   requires investigating the print chain, local model validity and measurement
   identity; the diagnostic does not automatically identify the cause.

The JSON records per-patch results and hashes of the inspected layout and TIFFs.
Original artifacts are unchanged. RGB16 LZW decoding requires the optional
analysis dependencies `tifffile` and `imagecodecs`.

## Interpretation of measured print results

JSON, TXT, HTML and PDF certificates explain that **Measured print vs desired colour** compares the measured C2 print with desired absolute D50 Lab. The ICC is applied once in target generation; the print path must preserve device RGB. Results apply to the documented profile, printer, ink, paper and settings together.

B3 profile fit measures agreement with profiling measurements, not accuracy of a new print. **Measured print vs current profile prediction** is separate diagnostic evidence. The overview includes all unique measured colours; difficult-target results are not a universal photographic quality score. Unreachable desired colours cannot be reproduced exactly, but model-based reachability is not proof of physical gamut. Missing evidence remains unclassified. A numerical-only certificate does not establish measured-print accuracy for the current profile.

### What the model means

The model is the ICC profile's mathematical description of printer device RGB versus expected printed Lab colour. Profiling measurements support fitted curves and lookup tables, with interpolation and smoothing. The forward direction predicts colour from RGB; the inverse direction selects RGB for a desired colour, subject to profile and printer limitations. Predictions are calculations, not new physical measurements. Imported profiles may come from another tool with unavailable original training data.

## Certificate language

New measured-print and numerical-only certificates are generated in English in JSON, TXT, HTML and PDF, including headings, metric descriptions, standards references, FWA/shadow information, signatures and legal appendices. User-entered notes, project values and historical source documents retain their original language. Existing certificates are not rewritten automatically.

## Gamut and measured-colour views

PDF gamut figures use the exact intersection of the ICC surface with L*=50, with equal a*/b* units and named axes. Actual measured points are shown separately in the a*/b* plane for L*=50 +/-5; the band and visible count are disclosed. HTML offers independent 2D/3D selectors for gamut and measured points, defaults to L*=50, and names L*, a* and b*. Missing measurements or unavailable ICC surfaces are stated explicitly. Numerical-only reports can show verified historical measured points, labelled with their iteration, without treating them as measurements of the current ICC. Regenerate old reports to receive these views.

## Final measured approval and unmet comparison limits

For a final independently measured delivery after refinement, run row 8, create the current profile's C2 target in row 9, print without further colour conversion, then measure and review in rows 10-12. Row 13 records explicit approval for an intended use and accepted limitations; row 14 exports the corresponding ICC and certificate. Row 19 cannot establish current print verification.

Selected comparison limits may remain unmet because of print-system limitations, but the cause must be supported by evidence rather than inferred from convergence. Report all measured results and separately disclose model reachability, unresolved inversion and unknown causes. An accepted photographic result with limitations is not a claim of ISO conformity. If conformity is required and applicable requirements are unmet, do not approve the result for that purpose. See [Best practice for profiling and final print verification](profiling-best-practice.md).

New certificates include the shared acceptance context in the opening scope explanation in JSON, TXT, HTML and PDF, for both measured and numerical-only delivery. It distinguishes accepted use from standard conformity, requires evidence before attributing errors to physical limits, and calls for whole-target assessment. Existing certificates must be regenerated; saved approvals are not changed.

## M0 white-reference compensation evidence

New FWA recipes disclose a native-M0-based simulated D50 response, not direct UV excitation quantification or native M1. Certificates record training and verification white-reference source/count and embed preparation evidence. Averaging reduces random variation but cannot recover missing UV excitation; weak fluorescence remains uncertain. A separate approved blank-paper reference supplies missing white, with any auxiliary ICC white anchor distinguished from actual target patches. See [FWA acquisition and smoothing](optical-brighteners.md).
