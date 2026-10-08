# Acceptance ahead of the new verification print, 2026-09-28

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

The user accepted proceeding and requested a commit/push after reviewing the new 575 measurement. The acceptance covers working B1–B3 and numerical checks as the basis for the next C2. It is not an approval of the profile's measured print quality.

- Source: `InkProf-575-from-TI2-v2_0928.mxf`, 575 RGB patches, M0/XRGA, i1 Pro 2, 36 spectral bands 380–730 nm.
- Locked basis: `a3b30fac-483d-4da7-9caf-f1fc61c45aa0`.
- Recipe: `192c7980-83ed-4d78-81c0-ce9862bb27b2`, spectral.
- Profile job: `f1864640-237e-49ff-b08e-89c754744923`.
- ICC SHA-256: `1eca263b2b7d9fd08db64fa4535949ab99724267a88fbae2023634b1d52d430f`.
- Fit to 575 measurement points: mean ΔE00 0.6715; max 3.5527.
- Round trip on 729 RGB points, relative colorimetric: mean ΔE00 0.4142; max 2.5648.
- Neutral Lab round trip within the model: mean ΔE00 0.0554; max 0.3535.
- No lightness reversals in the tested RGB grey ramp. One candidate for local ramp unevenness remains for review; maximum second difference 1.2104 Lab units at step 1/256.

B1 verifies the hash of the positioned original MXF file, patch IDs, positions and RGB through a new import when the TI2 lacks estimated XYZ. This is an identity check, not proof of the correct physical sweep direction. The measured values are also compared between the selected JSON revision and the TI3.

Next step: create a new C2 target with this profile and contrast markers, document the print settings, print without further profile conversion, and measure. Older C2 results apply to other profile/print conditions and do not approve this candidate. ISSUE-001 on measurement noise/condition number remains open.
