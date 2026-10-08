# Acceptance of the tested RGB interchange – 2026-09-27

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Christer has accepted the tested interchange between InkProf and i1Profiler.
The acceptance applies to the concrete flows below, not to all program versions,
file variants, instruments or measurement conditions.

| Flow | Verification |
|---|---|
| TI2 → InkProf PXF → i1Profiler | The user imported, printed and measured 575 patches. |
| TI1 → InkProf PXF → i1Profiler | The user confirmed successful import of `InkProf-575-from-TI1.pxf`. RGB and patch order are identical to the approved TI2 export. |
| i1Profiler MXF → InkProf JSON/TI3 | All 575 spectra verified through the MATLAB import. |
| InkProf measurement → MXF → i1Profiler | The user confirmed import of `InkProf-575-M0-updated.mxf`; the reference's metadata/layout was retained and the spectra were replaced. |
| Imported MXF → spot revision → TI3 → re-import | Automated test with a synthetic candidate: only the selected patch changes, original and history are preserved. Not a physical instrument test of this whole chain. |

## Approved export path and limitations

`exportPxfTarget` uses RGB8-compatible PXF. The approval applies to the
integer values in this test; fractional RGB and all other recipient variants
are not qualified.

`exchange/export_reference_mxf.py` makes the approved spectral export path
reusable. It reproduces the accepted file byte for byte from the
same sources. It requires M0/XRGA, 36 bands 380–730 nm and unambiguous TargetN/ID,
RGB and position links. A JSON sidecar states the actual source and hash values.
The reference's Creator, date, private settings and layout are preserved for
compatibility reasons and do **not** describe the print of the InkProf original.
The export is not an instruction to re-measure the original print.

`exchange/export_mxf.py` is the older experimental exporter that changes
layout and metadata. Its earlier files were rejected; it is not the
recipient-verified export path. The Creator field alone is not proven
to be the cause of the earlier import failures.

## Corrected measurement and comparison

Spot checks of A22/U22 and the subsequent forward re-measurement of all of
rows 22–23 supported the conclusion that the previously saved row order was wrong. A new complete
revision replaces 42 patches and preserves the other 533 unchanged. The original and
the separate spot revisions remain. New revision:
`measurement-20260927-154833490-rows22-23.json` and the corresponding TI3.

Direct comparison of the corrected TI3 with i1Profiler's original MXF, using a common
D50/2° calculation from the spectra:

- 575 patches, the same RGB within decimal rounding and the same 36 wavelengths.
- Mean ΔE00 0.5616; median 0.5266; P95 1.0507; maximum 1.7035.
- 536 patches below 1 ΔE00; all 575 below 2.
- Spectral RMS error 0.8001 percentage points of reflectance.

These are different prints: the result includes both print variation and
measurement variation. It is not isolated instrument repeatability or a
verification of a finished ICC profile. The previously accepted MXF export
still contains the older row order; it is compatibility evidence,
not the current corrected profiling measurement.

## Remaining limits

Automatic bidirectional row identification can still misinterpret some
non-randomised rows. New code warns about suspected reversed order; it does not
reverse data automatically. Import without an unambiguous layout/link is rejected.
Other MXF variants, physical spot re-measurement after MXF import and ICC generation
and profile validation require further testing.

## Checks before commit

- 31 Python tests passed (`unittest discover`, `test_*.py`).
- 7 MATLAB tests passed: PXF export, measurement import/replacement/re-import,
  spot measurement with a simulated instrument, and paired sweeps.
- The reusable MXF compatibility exporter reproduced the user's
  accepted MXF byte for byte (SHA-256
  `6a5a4f5d8dd7151878558108412607a09c78ac0558308dcd73ec40f6ab8c782a`).
- `git diff --check` without errors. Physical measurements are not part of the automated tests.
