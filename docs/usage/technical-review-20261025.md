# Technical description editorial review - 2026-10-25

Both technical descriptions now use the 1.4.0 baseline consistently, with matching contents and Appendix A-J / Bilaga A-J headings. The 19-page structure is retained.

- Removed duplicate baseline wording and unexplained references to another application's SG140 restriction.
- Updated release links and implementation baseline. Appendix C reports the 32 MATLAB and 39 Python tests recorded for 1.4.0; the earlier 23-test result is explicitly historical. No new physical qualification is claimed.
- Corrected Swedish grammar, paired-scan terminology, input-hash wording and native-tool terminology.
- Split the shadow-selection description into policy and data-flow paragraphs. Added source maps to chapters 2 and 8.
- Rewrote appendices D-J around implementation, source files, identities, state transitions and retained artifacts instead of handbook click instructions.
- Removed unexplained issue-closure prose while retaining the limitation concerning noise propagation through refitting.
- Confirmed C3 output is relative to the directory containing verification.json: <C2-package>/checks/<ID>/. Main-workflow packages use targets/<ID>; the API default uses verification/<name-ID>. File tables and Appendix E now describe both.
- Confirmed gamutPicker closes the figure after successful target creation and registration for both workflow and standalone entry paths. Corrected the contrary Swedish handbook sentence; English handbook already agreed with the implementation.
- Clarified that requirements-analysis.txt and requirements-report.txt reference the single pinned requirements.txt rather than providing independent locks.

All 38 technical PDF pages were rendered and visually inspected. Heading locations and TOC rows were checked against all 18 section headings in each language. The changed Swedish handbook page was rendered and visually reviewed; it retains 81 content pages plus cover. Downloads and the existing PDF collection receive SHA-verified copies. File hashes are recorded in docs/documentation-update-20261025-technical-editorial.json.
