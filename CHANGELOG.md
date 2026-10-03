# Changelog

## v1.0.0RC1 — public release candidate (1.0.0-rc.1, 2026-10-03)

- External ICC verification: balanced photographic patch selection with reserved skin tones and shadows, distributed neutrals/challenges, and recorded selection quotas; existing targets remain unchanged.

- Separate existing-ICC verification projects: seven steps, editable 575-patch TIFF16 target, physical measurement, two error comparisons and portable measurement certificates; original ICC bytes preserved.
- Complete 19-row project workflow with persistent JSON state, prerequisite checks, measurement revisions, result logs and iteration history.
- Central editable project/material/print settings, portable folders, renaming checks, dye/pigment ink type, printer coating and drying time.
- TIFF16-only print delivery, editable cut-sheet/roll suggestions, JSON sled limits, row labels on both sides and compact-page footer spacing.
- Instrument identity capture, startup/reconnect feedback and clearer patch remeasurement review. Measurement startup is guarded against reentrant callbacks and duplicate session locks have an actionable message. Temporary PTY/controller read unavailability now waits for the next event instead of aborting measurement; unexpected chartread failures are recorded in the session JSON.
- ICC recipe/build/checks, physical C2/C3 verification, image-guided refinement and C2 training data in subsequent iterations.
- Matte shadow strategy: editable sampling emphasis, numerical grid emphasis and up to 48 additional dark fitting patches per iteration.
- Common-sample ICC comparisons, default 2D L*=50, 3D points and a separate ICC gamut surface.
- Measurement certificates for print-reviewed or explicitly numerical-only scope; signature, references/explanations in Appendix A and legal terms in Appendix B; portable HTML folders.
- Updated Swedish/English presentations and workflow PDFs, Swedish handbook, installation and current usage index.
- Licensing review: source notices, full dependency notices, preserved provenance, redistributable font and PDF notices. Minimal independently authored PXF scaffold replaces older vendor settings; PXF patch-set import/display, printing and physical measurement with the replacement were verified and accepted by the user on 2026-10-03 (tested round8 export).

This is a public release candidate, not the stable v1.0.0. See VALIDATION.txt and docs/releases/v1.0.0.md. No new physical accuracy claim follows from automated tests.

## 0.9 — historical public snapshot

Initial public source distribution, separated from private development history and private reference datasets. Subsequent development is summarized above. Historical validation records apply to their original source state only.
