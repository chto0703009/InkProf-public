# Structure of Chart 2033 Patches.txt

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Investigated 2026-09-28. The RGB values in this file are on the 0–255 scale.

The first 1872 patches form a complete Cartesian grid with 12 R levels, 13 G levels and 12 B levels. The R/B step is approximately 23.18/255 = 9.09 percentage points and the G step is 21.25/255 = 8.33 percentage points. This is general densification without knowledge of the individual printer's errors.

There are 2033 patches in total but 2027 unique RGB values. Of the 161 additional rows, six repeat grid points and 155 lie outside the base grid. The whole file contains 43 exactly neutral RGB rows. 41 of the unique additional points are neutral and complement black/white to form a denser grey ramp. The purpose of the remaining additions cannot be determined from the file alone; no proprietary algorithm is inferred.

For our local centres, the nearest RGB distance is 5.154 percentage points around O6 and 2.235 around U5. Within ±3 percentage points per channel there are zero and one points, respectively. There is no point in the narrow R interval 48.038–49.804 percent with G/B within ±10 percentage points of the ramp's G=85.490 and B=42.745.

The 2033 target therefore covers more densely than 575 in general, but does not reliably capture the observed narrow transition. Misdirected densification may place a small number of samples where information is actually missing. It has not been shown here what profile quality the 2033 target would give after printing and measurement.

## Prior knowledge before measurement

The user's question concerns the designer's experience-based prioritisation before any measurement, not merely a post-hoc check against our error region. The file shows regular base coverage and dedicated grey sampling. It does not show why the axes were given 12/13/12 levels; this cannot be attributed to green sensitivity without a further source. The remaining additions need to be mapped before they are called skin tones, shadow samples or gamut samples. For InkProf, such general starting priorities should be kept separate from measurement-based adaptive densification, and their origin should be stated.

## InkProf's proposed starting distribution

See [Starting target for new paper – 2033 patches](../planning/new-paper-2033-target.md)
for a separate trial proposal based on iteration 2. It does not describe the
distribution in the imported file analysed above and is not yet
implemented as a default mode.
