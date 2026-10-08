# Row recognition: i1Profiler, Argyll and ChromIQ

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Reviewed 2026-09-26. ChromIQ code read at explicit request for analysis; no code copied and no measurement engine replaced. Local revision: 92e6ead0.

## Conclusion for the 575 print

There are three separate levels: the instrument driver divides the raw data of the scan into patches; chartread links patches to row/direction and checks expected colours; Python/MATLAB handles session and presentation. An improvement in the user interface does not automatically mean better segmentation.

The saved measurement has missing rows 14-17 and a patch offset on row 13. The M0 reference from i1Profiler shows very weak spectral differences at Z/2A on these rows. This is a concrete hypothesis for the segmentation error, not proof of its exact mechanism.

## 1. i1Profiler

The real MXF sample shows that its measurement path handles the same print. This may be due to different signal processing, geometry knowledge, thresholds or a different acquisition strategy. MXF contains finished spectra and positions, not a raw time series or a segmentation algorithm. No specific user setting for a patch-boundary threshold has been verified. We therefore cannot say that a particular setting can be transferred to Argyll.

## 2. Contrast fields are supported in the Argyll workflow

printtarg has coloured contrast fields (-c), black-and-white (-b), none (-n) and scaling of the contrast fields (-A). A practical generation test with installed ArgyllCMS 3.5.0 succeeded with -ii1 -c -T72 -p320x280 on a copy of a 256-patch target. TIFF and TI2 were created. No physical measurement of this test layout has been made.

The correct approach is to generate a coherent new TIFF/TI2 package with printtarg or a carefully verified equivalent. Do not simply insert arbitrary wide white boxes into the old TIFF file: they may be interpreted as extra patches and the layout is then changed. Contrast fields may take space from the number of patches per row; the patches' suitable size and the maximum total image of 320 x 280 mm are to be kept. The new image must be printed. The existing i1Profiler definition does not automatically apply to the new layout.

Randomisation is a separate aid for greater difference between adjacent patches, but does not guarantee all boundaries. For this troubleshooting test, explicit contrast is a clearer intervention than merely shuffling everything.

## 3. ChromIQ has two measurement paths

workflow/measure_manager.py can start ordinary Argyll chartread with -v/-c and options for -B/-b (direction), -S (hide warnings), -N, -p (point-wise), -H, -r and extra arguments. Its alternative native/chromiq-chartread is a modified chartread with a JSON protocol, atomic autosave per row, direct row selection and extended row/direction checking also for some non-randomised targets.

Code for row identification assesses whether the rows are sufficiently separated in expected Lab and whether a row differs from its reversed order. This takes place after the instrument driver has delivered patch values. It is not a new algorithm for dividing the raw scan into patches.

native/instlib/PROVENANCE.md states that the instrument library comes unchanged from ArgyllCMS 3.5.0. The SHA256 of i1pro_imp.c begins 8b8516cdd89e21de, which matches the inventory. The function i1pro_extract_patches_multimeas has separate criteria for signal transitions and the patches' internal consistency. The error I1PRO_RD_NOTENOUGHPATCHES arises here when too few candidates are found, before chartread's row identification. There is therefore no source-code support for assuming that ChromIQ's modified chartread in itself solves this particular i1Pro problem.

ChromIQ's layout code also has options for coloured/black-and-white/no contrast fields and field scaling. A successful ChromIQ test must therefore use exactly the same TIFF/TI2 if the intention is to compare measurement engines; a new layout also tests the print's geometry and order.

Its native measurement path includes spectral TI3 saving. A general claim that ChromIQ does not save spectra is thus too broad; support must be assessed per workflow.

## Tolerance is not the same as patch boundary

chartread -T scales the tolerance for variation within an identified patch. In the reviewed i1Pro code, scan_toll_ratio is linked to patch_cons_thr, while the transition threshold is calculated separately. Raising -T is therefore not a direct solution to weak boundaries or a wrong patch count. -S hides warnings, repairs nothing and should not be used to accept row 13. -B can isolate direction selection but does not restore a lost patch boundary.

## Proposed test order

1. Preserve the current TI3/MXF and flag row 13 as unsuitable for profile building.
2. Try diagnostics on the same problem row with Argyll, without suppressing warnings. Point measurement via chartread -p is a possible separate check of colour values when row segmentation fails.
3. Generate a small new test target with problem colours and Argyll's own contrast fields. Keep patch size and measurement conditions and print at actual size.
4. Compare against a layout without contrast fields. If the improvement is repeated, introduce a selectable instrument-adapted contrast layout in InkProf.
5. Try ChromIQ separately if desired. Its autosave and clearer events are useful architectural ideas even if the same low-level error remains.

## Sources

- Argyll printtarg: https://www.argyllcms.com/doc/printtarg.html (also installed documentation 3.5.0).
- Argyll chartread: https://www.argyllcms.com/doc/chartread.html (installed documentation 3.5.0, sections -T, -S, -B and -p).
- ChromIQ, revision 92e6ead0: workflow/measure_manager.py, workflow/chartread_engine.py, workflow/ti2_relayout.py.
- Same revision: native/chartread_helper/chromiq_chartread.c and native/instlib/i1pro_imp.c and PROVENANCE.md.
- Local measurement analysis: projects/matning-575-20260926-111725/analys-575-20260926.md.
