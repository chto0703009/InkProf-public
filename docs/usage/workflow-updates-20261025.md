# InkProf workflow updates - 2026-10-25

Applies to version 1.3.0, released 2026-10-25.

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

After successfully saving and registering gamut patches from Refinement tools, the workflow gamut window closes. A standalone gamut viewer remains open. To copy an existing refinement target, select row 15 in the main table and use Copy TIFF16 for printing..., then choose Downloads. The new folder identifies the project and iteration and contains printing files and traceability information. The source project is preserved.

## Timed certificate delivery

Step 14 shows activity and elapsed time while collecting evidence, rendering figures and PDFs, preparing ICC variants, and copying and verifying delivery files. The external bundle includes the exact checked ICC as <name>-verified-original.icc as well as named delivery variants. A stored certificate is not regenerated in place; create a new export revision when changes are needed.
