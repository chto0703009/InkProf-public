# ICC gamut surface

> InkProf 1.4.0, released 2026-10-25. See the [current app workflow](workflow-v1.0.md) and [source updates](workflow-updates-20261025.md). These instructions are included in release 1.4.0.

The **View gamut** button becomes available when the current iteration has a valid ICC profile. It opens a separate rotatable surface in CIELAB D50. The existing 2D/3D sample-point views remain available and retain their own meaning.

Both measurement certificate export paths include this surface: independently print-verified certificates and certificates for numerically checked iterations without separate print verification. HTML defaults to 2D at L*=50 and offers a selector for 3D L*/a*/b*. In 3D, drag to rotate or enable automatic rotation. PDF contains an exact mesh-plane intersection at L*=50, with a* horizontal and b* vertical. The comparison point viewer still defaults to 2D at L*=50.

The surface is calculated with the installed external ArgyllCMS `iccgamut` executable using `-d 5 -ff -ia -pl`: forward A2B, absolute colorimetric, CIELAB D50. The detail parameter is a sampling setting (approximately Delta E), **not an accuracy tolerance**. No convex hull of the measured patches is substituted. The display uses clipped sRGB previews, so the monitor cannot reproduce every colour on the surface.

This is the gamut described by the ICC model, not a new measurement, a quality score, an ISO conformance result, or proof of what every print can reproduce. The printer, paper and ink combination, profiling data and model all affect the result. Existing approval and verification requirements are unchanged.

## Traceability and portability

The export stores `gamut-surface.json` (Lab vertices, zero-based triangle indices and sRGB previews), the original Argyll `.gam`, and the tool log. `final-report.json` records the mesh file checksum and the source ICC SHA-256. Renderers reject a changed mesh or a mesh from another ICC. The named delivery ICC may have different metadata; the surface remains linked to the checked project original.

App-only viewing uses a temporary directory and does not change workflow state. Saving a selected patch proposal registers new project artifacts. During generation a progress dialog remains visible. If the tool or profile cannot produce a surface, the certificate states that it is unavailable, with a reason; no substitute figure is invented. The app shows an error. This optional visualization does not cancel otherwise valid certificate export.

The HTML viewer is included in the report and does not need a network connection or a third-party web viewer. External delivery bundles carry all underlying files. ArgyllCMS remains a separately installed program under its own licence; no Argyll source is incorporated.

References: [ArgyllCMS iccgamut](https://www.argyllcms.com/doc/iccgamut.html), [Argyll GAM file format](https://www.argyllcms.com/doc/File_Formats.html#gam).

Tested on macOS with MATLAB R2025b and ArgyllCMS 3.5.0. Windows and Linux have not been tested.

## Neutral lightness reference

All 3D Lab views show a contrasting L* reference through a*=b*=0, labeled from 0 to 100. It remains visible over surfaces or points. Interactive report and fixed certificate figures use the same reference. The line is a coordinate guide, not a measured neutral ramp or a claim that every point lies inside the printer gamut. Existing reports require regeneration to receive it.

## Select an area for additional measurements

In the MATLAB **View gamut** window:

1. Rotate the surface to expose the area, then click **Select area**. Click the coloured surface; a white marker identifies the selected mesh vertex. Select several positions around an indentation if needed. **Rotate view** restores dragging; **Clear selection** removes all markers.
2. Review the selected printer R/G/B percentages and **ΔE76 offset** in the side table. These are device values, not the clipped sRGB display colours. The offset is the distance between the mesh vertex and its nearest sampled forward ICC colour; it is **not measured print error**.
3. Set **Neighbour radius** (default 3 RGB percentage points per channel), **Minimum spacing** (default 1), and **Maximum new patches** (default 100). The proposal explores a 3×3×3 RGB neighbourhood for each selected area, clipped at the device cube boundary. Already-measured training colours and near duplicates are excluded; the requested budget is an upper limit.
4. Click **Review patches / create TIFF16**, uncheck unwanted rows, then **Create TIFF16 target**. Review the paper plan. InkProf saves the proposal and the unmanaged print package in a new project `refinements/` folder. Controls and development patches are assigned before measurement; extra controls and configured matte-shadow samples can increase the printed total.
5. In app **step 15 → From gamut selection**, use the latest selection (or select its `proposal.json`). This registers a new immutable print package for the workflow and includes pending C2 patches when applicable. Print **this step-15 package**, measure in **step 16**, then build the next profile in **step 17**.

The mesh comes from Argyll's envelope and does not carry original device RGB coordinates. The interactive window therefore associates vertices with nearest forward samples from 65-level RGB cube faces and a 17-level interior grid, in absolute CIELAB D50. This is an approximate association; its distance and sampled Lab are retained in the saved anchors. A picked point is not proof of a profile defect, and extra measurements cannot extend the physical gamut. Assess the rebuilt profile with a fresh independent verification print.

ICC files outside a successful InkProf profile job can be inspected and selected, but cannot create a project refinement target. Report viewers retain their existing rotation-only behaviour.

## Add measurements in an inner gamut shell

In **View gamut**, the sampling menu defaults to **Whole inner gamut shell**.
No surface selection is needed. Set **Shell thickness (ΔE76)** (default 3,
maximum 50), **Minimum spacing** in device RGB percentage points, and
**Maximum new patches**. Review the proposal and continue through the same
step 15–17 print, measurement and rebuild workflow described above.

Thickness is the shortest Euclidean Lab distance to a surface triangle,
measured inward from the current ICC gamut. RGB lines or other features near
the surface can guide the chosen thickness; InkProf does not automatically
detect them or infer their cause. The shell covers the entire gamut, not only
blue colours. Boundary points are included. The mesh must be closed;
Concavities are retained rather than replaced by a convex hull.

InkProf forward-transforms a reproducible pool of 16,384 scrambled Sobol RGB
samples plus 17-level RGB cube faces, quantised to RGB16. It retains only
samples inside the mesh and within the chosen thickness, excludes existing
training RGB and nearby duplicates, then selects candidates by greatest Lab
distance from existing measurements and previously selected candidates.
The requested budget is an upper limit; a very thin shell or large spacing
may yield fewer points. This is finite candidate sampling, not exhaustive
coverage. A larger fitting target does not by itself prove improved accuracy.

**Selected inner shell areas** optionally restricts the same shell to Lab
spheres around clicked surface vertices; **Selected shell area radius**
(default 15 ΔE76) sets their extent. **Selected RGB neighbourhoods** retains
the earlier device-neighbourhood method. The proposal stores the source mesh,
ICC hash, parameters, predicted Lab and each shell patch's surface distance.

Programmatic use: `inkprof.refineFromGamut(jobFile, anchors,
SamplingMode="shell", Surface=surfaceData, ShellThicknessDeltaE76=3)`.
For the whole shell, `anchors` may be an empty struct array; `surfaceData`
must contain the current profile hash, Lab vertices and zero-based triangles
from InkProf's Argyll gamut result.

## Shared refinement tools and higher ICC grid trials

Use **Refinement tools** in the main app (also the menu in step 15).
It groups **From image**, **Manual gamut points / inner shell**,
**From saved gamut selection**, **From verification errors**, and
**Try higher ICC grid (same measurements)**. Manual gamut / shell opens the
same gamut viewer; save the reviewed proposal there, then choose the saved
gamut selection in this menu to create the step-15 measurement package.

The grid trial offers High or Ultra for **B2A only** or **A2B and B2A**.
Argyll controls resolution through its `-q` and `-b` quality settings; this
feature does not accept an arbitrary n. The source recipe is copied, keeping
the same locked B1 measurements, smoothing, colourimetry, FWA and gamut
mapping. B2A-only trials retain forward-model and pre-fit quality. A both-table
trial also changes the pre-fit resolution if pre-smoothing was enabled.
Choose a level higher than the source; Ultra defaults to B2A only.

A separate candidate job and `grid-trial.json` are saved under the project,
with source ICC/recipe hashes. `grid-comparison.json` reads actual n and n³
from the source and new ICC tables; the dialog displays both. Training fit,
grid and photographic-gradient checks run on the candidate. The original
profile and active workflow selection are retained. A denser LUT does not
supply new measured information or demonstrate improved print accuracy.
No new chart or measurement is required for this trial.

Programmatic use: `inkprof.rebuildProfileGrid(b1Folder, sourceJobFolder,
Quality="ultra", Tables="B2A")`. Use `RunBuild=false` to save a trial recipe
without starting Argyll. Reference: [Argyll colprof](https://www.argyllcms.com/doc/colprof.html).

## Visual numerical verification

The gamut patch review includes a rotatable 3D Lab plot of proposed patches
against the translucent source gamut when a shell mesh is available. A second
plot shows each shell patch's inward ΔE76 distance and the chosen thickness.
These plots show all proposed candidates; the Use checkboxes determine which
are printed. The underlying mesh, predicted positions and depths remain in
the saved proposal.

The ICC grid trial shows a grouped chart of actual source/candidate n³,
plus selectable matching test-gradient curves: printer R/G/B percentages
and predicted L*. Dashed curves are the original; solid curves are the trial.
Nine identical sRGB test paths are converted with relative colorimetric,
BPC off and float LittleCMS buffers. `grid-curves.json` saves their values
and both ICC hashes. These are numerical verification plots, not a print
measurement or proof that a visible artefact has been removed.

After a direct gamut proposal creates its print package, a folder chooser
lets you save a complete copy elsewhere. Cancel retains the project copy.
Copied files are hash-checked and existing deliveries are not overwritten.
This direct package remains the proposal package; for workflow measurement,
use the step-15 package described above. The gamut viewer also has a visible
**Close** button below its sampling panel.

## Register an already printed shell for step 16

If a shell was printed directly from the gamut viewer but step 16 is locked,
choose **Refinement tools → From saved gamut selection**, select its proposal,
and choose **Use existing print package**. This registers the exact saved TI2
and patch roles in step 15, after verifying the current ICC and print-package
hashes. It does not regenerate the target or add pending C2 patches. Complete
the assessment note; step 16 then measures that same printed package.
When the gamut viewer was opened from step 15, close it after saving to return
to this registration flow. A new print package always requires its own print.

## Explore the current gamut boundary

Choose **Gamut boundary exploration (both sides)** in the sampling menu.
Set **Boundary distance (ΔE76)** and the patch budget. No selected area is
required. The same reproducible printable RGB pool is used, but candidates
near either side of the current mesh are retained. Signed distance is positive
inside and negative outside; outside predictions are recorded explicitly.
The pool may contain no outside predictions: no artificial Lab targets or
unprintable RGB values are invented. Existing measurements and duplicate
colours remain excluded. Review, print, measure in step 16 and build step 17.
The existing profile is preserved. Only new measurements can establish whether
the rebuilt model describes a larger usable gamut; physical expansion is not
guaranteed. The inner shell options continue to sample inward only.

## Extend the latest unmeasured target

In **View gamut**, tick **Extend latest target**, choose the shell/area and
additional patch budget, then **Review patches / create TIFF16**. InkProf
resolves the latest saved gamut target for the exact current ICC and verifies
its TIFF package, TI2, roles and source training snapshot. The review lists
only the NEW candidates and states how many previous patches are retained.
Previously selected fitting/development patches (including supplementary
shadow patches) are carried forward automatically. Existing training RGB and
exact duplicates are excluded; new candidates also respect the minimum
spacing from retained points. Controls and development roles are frozen again
for the new print version. No original file is overwritten or deleted.

A target with started measurement data cannot be extended: keep measuring its
original TI2 or create a separate additional target. The new proposal records
the parent proposal, TI2 and role hashes, retained/new counts and snapshots.
The new TIFF package is registered for **step 16** and can be copied to Downloads
through the existing print-copy dialog. Print every page of this new package,
measure its NEW TI2 in step 16, and build the next profile in step 17.
The earlier print layout and measurements never belong to the new TI2.

Programmatic use: `inkprof.refineFromGamut(..., ExtendLatestTarget=true)`.
`ExtensionProposal` optionally selects a specific checked parent proposal
inside the current project rather than the latest one.

The external-copy folder dialog opens in **Downloads**. It appears only after
the target is saved normally inside the project. Selecting a folder creates
a separate print-package copy there; **Cancel** skips this optional copy and
keeps the completed project target available for measurement.

After successful TIFF16 creation and the optional external-copy dialog,
**View gamut** closes automatically. Cancelling patch review or encountering
an error leaves the viewer open so the selection can be corrected.

## Review measured Lab density and a balanced candidate

**Refinement tools → Review measured Lab density / balanced trial** reviews
measured training Lab from the source job's colourimetry-aware fit check.
The report lists dense Lab groups and their RGB span, and identical RGB16
repeat groups with maximum ΔE00. New iteration builds also save this density
review automatically with their first candidate. Original observations stay
unchanged. Provisional defaults: complete-link distance 1 ΔE76, target four
representatives per group, repeatability review threshold 1 ΔE00.

**Build separate balanced candidate** creates an experimental subset of
unchanged measured rows; it does not assign numerical weights or average
measurements. Neutral device RGB, global lightness extremes, each group's
RGB channel extrema and inconsistent repeat groups are protected, so the
target count can be exceeded. Complete-link grouping avoids chains that
join distant Lab endpoints. Similar Lab at distinct RGB can describe
saturation and is not automatically labelled a bad measurement.

The original input, source rows, report parameters and hashes are retained
in a separate density-trial folder. The recipe keeps source profiling
settings; only fitting row selection changes. The candidate is compared
against ALL original fitting observations, including omitted rows, and
matching photographic gradients. Reserved development IDs are compared
when available from the current iteration. Missing development evidence is
stated explicitly. There is no automatic replacement or approval of the
active profile. Fresh independent print verification remains required.

Programmatic APIs: `inkprof.reviewMeasuredDensity(job, LabRadius=1,
TargetPerGroup=4, RepeatLimit=1)` and `inkprof.buildDensityTrial(job, reportFile)`.
`RunBuild=false` prepares the derived input/recipe without building;
`DevelopmentMeasurement` and `DevelopmentIds` supply reserved development
observations for the comparison. Thresholds are experimental, not standards.

The density review shows integer **Readings**, **Count** and **Retained**
values. Tick **Use balancing** for groups to include in the balanced trial;
**Select all** checks every group. Unchecked groups retain every measured
point. Protected observations remain retained in either case. Building saves
a separate dated group selection with the original report hash; **Close**
only closes the review and changes no fitting input.

**Select all** now both checks every balancing group and highlights its rows.
The header shows the selected/total group count. **Clear all** restores all
measured rows to the proposed fitting input; no source observations are deleted.
The repeatability review flag is read-only text, not a selection checkbox.

Adjust **Lab distance (ΔE76)**, **Target per group** and **Repeat review (ΔE00)**
in the density window, then press **Recalculate**. This saves a fresh review
using the same colourimetry-aware measured Lab report. Candidate building is
disabled when the current selection omits zero points, with an explicit
explanation. Selecting all groups does not override protected observations
or force removal; increasing Lab distance or reducing the target can propose
a smaller subset, subject to the existing protections.

Density analysis and **Recalculate** use an activity dialog attached to the
visible app/review window. Balanced candidate building keeps the elapsed timer
visible and reports source verification, snapshots, ICC construction, common
measured-patch comparison, original/candidate gradients, development checks
and result saving. The timer closes on completion or failure.

### Dark neutral refinement sampling

For matte projects with shadow processing enabled, each newly generated refinement print now supplements the Argyll candidate pool with 129 device-gray levels and small positive/negative channel offsets. The selector reserves approximately one third of the existing shadow-patch budget for neutral patches and one third for weakly coloured patches (predicted C*ab up to 10). The remaining budget covers other dark colours; unavailable quota slots return to the general dark pool. The total configured budget is unchanged (48 by default).

Selection uses the lower quarter of the current ICC's predicted black-to-white L* range. Device-gray probes remain eligible even if that ICC predicts a colour cast. Existing RGB values and duplicates are excluded at 16-bit quantization. The selection receipt records the policy, source ICC hash and predicted Lab. These are model estimates, not new measurements.

The new target contains device RGB with no profile applied. Print without colour conversion, measure the new TI2, and build the next iteration through the ordinary refinement workflow. Existing targets, measurements and profiles are preserved. A separate fresh verification print is required to assess shadow neutrality, tone separation and changes elsewhere. This cannot guarantee a lower physical paper black point.

Enable this in **Project details > Project and materials > Paper finish: Matte**, then **Profiling > Matte shadows: Extra shadow detail for Matte**. Defaults: **Dark patch emphasis 2**, **Shadow grid emphasis 1.3**, **Extra iteration patches 48**. In Refinement tools choose **Manual gamut points / inner shell**, select an area, then **Review patches / create TIFF16**. Shadow patches are added automatically to the new refinement target; they are additional to the selected gamut points. **Extend latest target** creates a new complete print version when extension is eligible; print all its pages and use its new TI2.
