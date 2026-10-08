# New M0 reference from i1Profiler, 2026-09-27

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Current status: see [acceptance 2026-09-27](acceptance-20260927.md).
Dated statements below about pending import tests describe earlier troubleshooting.

Source in the project: `projects/Canon-575-20260927/exports/InkProf-575-from-TI2-v2_i1profile.mxf`.
SHA-256: `f8686e81cd3aa6a9a200d76d50e15e93a46c274cc650f4f6610f956cfcb9ca27`.
The original file has not been changed.

## Verified through file analysis

- 575 Target objects and 575 M0_Measurement objects; no M1/M2 objects.
- All target RGB values and their list order match exactly InkProf's generated
  `InkProf-575-from-TI2-v2.pxf`. There is thus a concrete recipient flow
  from our PXF to a saved measurement file, not just internal XML re-reading.
- 575 unique position keys `(Page, Column, Row)` in each group;
  the position sets match unambiguously. `SampleID=-1` and empty SampleName cannot
  be used as unique identities in this file.
- Each spectrum has 36 finite values. The specification states start 380 nm,
  step 10 nm, XRGA, Filter_None and M0_Incandescent; the end is 730 nm.
- The reflectance-factor range is 0.002413–1.049892. Values above 1 have not
  been clipped or normalised away.
- Layout: one page, 29 columns and 20 rows. The first 20 patches are in
  column 0, rows 0–19. This is column-wise filling, unlike the
  separate InkProf print's two pages with 21 patches per row.

## Differences from the rejected MXF v2 export

The reference states MeasurementMode=1 in the user's Single Scan/M0 flow;
the earlier export inherited MeasurementMode=2 from an M0/M1/M2 reference.
The new reference has integer RGB, SampleID=-1, empty SampleName, private
ProfileSettings and the original's layout/printer attributes. The earlier
export changed several such fields at once and wrote fractional RGB.
The differences are candidates for isolated import tests, not proven causes
of the message `Error reading CxF version information`.

The next step is re-import of the new, unchanged i1Profiler file as a
positive control. After that, a separate export candidate should change only the
spectral payload with verified target linking, before further metadata changes.
A reference layout must not be described as the InkProf original's physical layout;
both position systems must then be documented in JSON.

The inspection result is in the project's
`exports/i1profiler-reference-inspection.json`. The new physical measurement values
have not been merged with or replaced InkProf's earlier measurements.
