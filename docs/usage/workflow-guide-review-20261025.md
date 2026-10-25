# English workflow guide editorial review - 2026-10-25

The 17-page guide now consistently describes 1.4.0, including the Python 3.13.6 environment and separately licensed bundled ArgyllCMS 3.5.0 tools for ARM/Intel macOS. MATLAB and a portable Python runtime are not bundled. Historical licence review evidence is labelled as historical.

Workflow table names now use C2a/C2b and distinguish the approval row from the Open review and approval / Approve for stated use buttons. Narrative uses row and iteration consistently, British grey, ΔE notation, i1Pro 2, explained Chroma Optimizer (CO), and supporting evidence folder (underlag/). Unexplained issue-closure prose and capitalised emphasis were removed. The running title is grammatical English.

Source verification established that iterateProfile runs internal Fit, Grid and C1 diagnostics, but advanceWorkflowCycle marks dependent checks stale and selects checks (row 8) for the new active iteration. The guide and both handbooks explain this distinction; the ordinary continuation route remains 16 -> 17 -> 8 before verification/delivery, with row 18 available for comparison. No application logic changed.

The standalone gamut figure already closes on successful completed target creation in gamutPicker. The Swedish handbook contradiction was corrected in the preceding technical-document review; this guide retains the source-confirmed behaviour.

All 17 guide pages were rendered and visually reviewed. Both handbook page-28 corrections were rendered and inspected; every handbook chapter remains on its previous page. Downloads and the existing PDF collection were SHA-256 verified. The receipt is docs/documentation-update-20261025-workflow-editorial.json.
