# InkProf workflow updates - 2026-10-25

Applies to version 1.4.0, released 2026-10-25. The earlier workflow improvements remain included.

## Review and lock once

Step 4 keeps the measurement preview open until Continue to assessment. B1 validates the selected revision, opens a modal Lock profile input confirmation, then saves a checked snapshot. Activity and elapsed time are shown during validation and saving. Suggested navigation is B1, B2, B3; B2 is shown for recipe review, while Automatic B3 still creates its own recipes.

## Patch counts and result windows

Initial B3 no longer asks for extra refinement patch parameters. Those apply when adding patches or continuing an iteration. C1 saves its numerical reports without opening successive result windows automatically; use Open selected step results. C2a handles verification-target preparation; choose existing files when reusing a printed sheet.

## Correct recorded details

When Project details changes, distinguish Correct recorded details from Changed actual setup. A documentation correction requires a reason and unchanged physical conditions. Original file hashes are checked and a new audit record stores before/after values. Numerical processing changes cannot use this exception. Existing stale steps are not automatically restored.

## ISSUE-001 closed

ISSUE-001 was closed by user decision on 2026-10-25 after several measurements without observed problems. Remaining uncertainty was accepted for current use. This is not a claim that a full noise-propagation/refitting study was performed; real numerical alerts and independent print verification still apply.

## RGB and other spot measurements

RGB controls, single-patch replacements and paper-white spots use a short start sound for screen-triggered and i1 Pro 2 instrument-button measurements. Calibration does not use the spot start sound. RGB colour rows show page, colour and progress only. The temporary sound-test button has been removed. Page changes are shown inline without a separate confirmation window.

## Cancel and resume safely

Skip / close and the window close button can cancel the RGB control dialog while calibration is waiting. Saved requests, transcripts and readings remain. Partial output lines no longer block GUI polling, and Argyll debug text after a prompt is handled. Main workflow activity is cleared on interruption. Restart InkProf after source changes; resume saved chart rows only for the same physical print.

## Refinement print copies

After successfully saving and registering gamut patches from Refinement tools, the workflow gamut window closes. The standalone gamut viewer also closes after successful TIFF16 creation. To copy an existing refinement target, select row 15 in the main table and use Copy TIFF16 for printing..., then choose Downloads. The new folder identifies the project and iteration and contains printing files and traceability information. The source project is preserved.

## Timed certificate delivery

Step 14 shows activity and elapsed time while collecting evidence, rendering figures and PDFs, preparing ICC variants, and copying and verifying delivery files. The external bundle includes the exact checked ICC as <name>-verified-original.icc as well as named delivery variants. A stored certificate is not regenerated in place; create a new export revision when changes are needed.

## Gamut boundaries and extended targets

### Explore the current model boundary

View gamut offers Gamut boundary exploration (both sides), alongside the existing inner-shell and selected-area methods. Set Boundary distance in Delta E76, minimum RGB spacing and maximum NEW patches. Candidates are printable device RGB, not invented out-of-range colours. A negative signed distance means predicted outside the current mesh; it does not prove physical gamut expansion.

### Extend latest target

Tick Extend latest target to combine the latest completed gamut print for the exact current ICC with new points. Unprinted proposals are skipped. Previous fitting/development points and supplementary shadow points are retained; exact duplicates and existing training RGB are excluded. Controls are regenerated. Started or paused measurements prevent extending that same target. The earlier TIFF, TI2 and readings remain unchanged.

### Print and measure the NEW version

The complete target is saved normally in the project. The optional external-copy dialog defaults to Downloads; Cancel skips only the external copy. Print every page without colour conversion. Step 16 measures the new TI2, and step 17 builds the next profile with the earlier training. Do not measure an earlier layout with the new TI2. View gamut closes after successful creation and the copy dialog; cancellation/error leaves it open.


## Review measured Lab density

### Read the measurements

Refinement tools > Review measured Lab density / balanced trial lists close measured Lab groups and their RGB span. Readings is an integer count of repeated RGB16 observations; maximum Delta E00 describes their repeatability. Similar Lab at different RGB may describe saturation. No original measurement is deleted, overwritten or averaged.

### Set, recalculate, select

Adjust Lab distance (Delta E76), Target per group and Repeat review (Delta E00), then Recalculate. Defaults 1 / 4 / 1 are provisional. Use balancing applies automatic representatives to checked groups; unchecked groups keep all rows. Select all checks/highlights all groups; Clear all restores every row to the proposed input. Neutrals, lightness/RGB extrema and inconsistent repeats stay protected. The target count may therefore be exceeded.

### Build a separate candidate

Close only closes the review. Build separate balanced candidate uses the reviewed subset and is disabled when zero points would be omitted. Try different settings and Recalculate rather than forcing removal. Both profiles are compared to ALL original fitting observations, including omitted rows, to available reserved development patches and to matching photographic gradients. These are diagnostics, not final independent print verification. No candidate automatically replaces the active profile.


## Activity, provenance and computer changes

### Visible work stages

Density review, Recalculate and the balanced trial show elapsed time and current phase: input verification, original snapshots, ICC build, all-patch comparison, original/candidate gradients, available development checks and result saving. Changing settings requires Recalculate before building. Trial parameters, checked groups, source rows and SHA-256 hashes remain in separate review/trial records.

### One environment per program

Each program has its own .venv with Python 3.13.6 and the same pinned requirements. From the code folder use setup_python_environment("check"), "sync" or "rebuild". A rebuild preserves the previous environment as a backup and restores it on failure. Do not commit or move a .venv as a portable replacement for rebuilding it. Projects and measured originals are separate from the runtime.

### Native Argyll and documentation scope

The program folder includes separately licensed ArgyllCMS 3.5.0 for ARM and Intel macOS, with upstream notices and provenance. Native tools are preferred and checked for actual startup. This document describes release 1.4.0. Restart the app after source updates.

## Dark neutral refinement sampling

New refinement targets reserve about one third of the shadow budget for neutral patches and one third for weakly coloured shadows (predicted C*ab up to 10); remaining slots cover other dark colours. With 48 available patches this normally gives 16 per group. Dense device-gray probes and small channel offsets supplement Argyll sampling. Unavailable quota slots return to the dark pool. Existing RGB16 colours are excluded. The receipt records policy and source ICC hash. Print device RGB without colour conversion, measure the new TI2 and build the next iteration. The current ICC only predicts selection; it is not applied to this print. Original targets and profiles remain unchanged. Verify the candidate with a fresh print; more patches cannot guarantee a darker physical black.

Set Paper finish to Matte under Project details > General, and choose Extra shadow detail for Matte under Profiling. Defaults: patch emphasis 2, grid emphasis 1.3, extra patches 48. This applies to newly generated refinement targets, including eligible extensions.
