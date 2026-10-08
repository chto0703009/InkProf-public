# InkProf: placement of new interior RGB points

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Comparison 2026-09-26. Same budget: 499 fitting points, 64 checks and 12 repeats. InkProf starts with 153 points and adds 346. All InkProf variants keep 98 surface points and have 401 interior fitting points. Argyll has 190 surface points and 309 interior.

## Independent check with 100,000 random sample points

The same sample points are used for all methods; MATLAB twister with seed 20260926. The sample points are not used during generation. Distances are normalised RGB to the nearest fitting point, not ΔE. Checks and repeats are not included as fitting support. Lower is better.

| Method | Mean | 95th percentile | Largest distance found |
|---|---:|---:|---:|
| Argyll OFPS | 0.06695 | 0.09564 | 0.12648 |
| InkProf: centroids (default) | 0.06648 | 0.09910 | 0.13312 |
| InkProf: circumcentres within own tetrahedron | 0.06615 | 0.10535 | 0.13812 |
| InkProf: all circumcentres inside the cube | 0.06723 | 0.10305 | 0.13360 |

## Assessment

Using circumcentres only where they lie within their own tetrahedron gives about 0.5 percent lower mean distance than the centroid method on the independent sample. However, the 95th percentile becomes about 6.3 percent higher and the largest distance found about 3.8 percent higher. Argyll retains better coverage according to these two tail measures. The new placement is therefore a comparison option, not an unambiguous improvement. Centroids are kept as the default.

The regular 33³ grid showed a larger improvement in the mean than the independent random sample did. This shows that a single regular sample grid should not decide the choice of method. Both investigations are in the JSON file. No maximum examined is a proven maximum over the continuous cube.

## Implementation

InteriorPlacement="centroid" is the default. "contained-circumcenter" adds the circumcentre within its respective tetrahedron as a candidate, with centroids as a fallback. "circumcenter" allows circumcentres anywhere strictly inside the cube, even outside their defining tetrahedron. All candidates are ranked by distance to the nearest existing fitting point. Starting points are not moved and no new surface points are added.

A circumcentre is equidistant from the tetrahedron's four vertices. For Delaunay tetrahedra this gives an empty sphere, but a greedy sequence of such choices does not necessarily give the best distribution at a given final point count.

Algorithm version 2.1 stores InteriorPlacement, insertionKinds, candidateKinds and parentTetrahedra. For circumcentres, the four parents refer to the vertices defining the sphere; they need not enclose the point in the unrestricted variant.

A separate trial was also made with discrete farthest-point placement using 65 levels per axis, with the outer surface excluded (63³ interior candidates). It did not give better interior mean coverage than centroids and was not added as a user option.
