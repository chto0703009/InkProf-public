# ICC gamut surface

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

The **View gamut** button becomes available when the current iteration has a valid ICC profile. It opens a separate rotatable surface in CIELAB D50. The existing 2D/3D sample-point views remain available and retain their own meaning.

Both measurement certificate export paths include this surface: independently print-verified certificates and certificates for numerically checked iterations without separate print verification. HTML defaults to 2D at L*=50 and offers a selector for 3D L*/a*/b*. In 3D, drag to rotate or enable automatic rotation. PDF contains an exact mesh-plane intersection at L*=50, with a* horizontal and b* vertical. The comparison point viewer still defaults to 2D at L*=50.

The surface is calculated with the installed external ArgyllCMS `iccgamut` executable using `-d 5 -ff -ia -pl`: forward A2B, absolute colorimetric, CIELAB D50. The detail parameter is a sampling setting (approximately Delta E), **not an accuracy tolerance**. No convex hull of the measured patches is substituted. The display uses clipped sRGB previews, so the monitor cannot reproduce every colour on the surface.

This is the gamut described by the ICC model, not a new measurement, a quality score, an ISO conformance result, or proof of what every print can reproduce. The printer, paper and ink combination, profiling data and model all affect the result. Existing approval and verification requirements are unchanged.

## Traceability and portability

The export stores `gamut-surface.json` (Lab vertices, zero-based triangle indices and sRGB previews), the original Argyll `.gam`, and the tool log. `final-report.json` records the mesh file checksum and the source ICC SHA-256. Renderers reject a changed mesh or a mesh from another ICC. The named delivery ICC may have different metadata; the surface remains linked to the checked project original.

App-only viewing uses a temporary directory and does not change workflow state. Saving a selected patch proposal registers new project artifacts. During generation a progress dialog remains visible. If the tool or profile cannot produce a surface, the certificate states that it is unavailable, with a reason; no substitute figure is invented. The app shows an error. This optional visualization does not cancel otherwise valid certificate export.

The HTML viewer is included in the report and does not need a network connection or a third-party web viewer. External delivery bundles carry all underlying files. ArgyllCMS remains a separately installed program under its own licence; no Argyll source is incorporated.

References: [ArgyllCMS iccgamut](https://www.argyllcms.com/doc/iccgamut.html), [Argyll GAM file format](https://www.argyllcms.com/doc/File_Formats.html#gam).

Tested on macOS with MATLAB R2025b and ArgyllCMS 3.5.0. Windows and Linux have not been tested.

## Neutral lightness reference

All 3D Lab views show a contrasting L* reference through a*=b*=0, labeled from 0 to 100. It remains visible over surfaces or points. Interactive report and fixed certificate figures use the same reference. The line is a coordinate guide, not a measured neutral ramp or a claim that every point lies inside the printer gamut. Existing reports require regeneration to receive it.

## Select an area for additional measurements

In the MATLAB **View gamut** window:

1. Rotate the surface to expose the area, then click **Select area**. Click the coloured surface; a white marker identifies the selected mesh vertex. Select several positions around an indentation if needed. **Rotate view** restores dragging; **Clear selection** removes all markers.
2. Review the selected printer R/G/B percentages and **ΔE76 offset** in the side table. These are device values, not the clipped sRGB display colours. The offset is the distance between the mesh vertex and its nearest sampled forward ICC colour; it is **not measured print error**.
3. Set **Neighbour radius** (default 3 RGB percentage points per channel), **Minimum spacing** (default 1), and **Maximum new patches** (default 100). The proposal explores a 3×3×3 RGB neighbourhood for each selected area, clipped at the device cube boundary. Already-measured training colours and near duplicates are excluded; the requested budget is an upper limit.
4. Click **Review patches / create TIFF16**, uncheck unwanted rows, then **Create TIFF16 target**. Review the paper plan. InkProf saves the proposal and the unmanaged print package in a new project `refinements/` folder. Controls and development patches are assigned before measurement; extra controls and configured matte-shadow samples can increase the printed total.
5. In app **step 15 → From gamut selection**, use the latest selection (or select its `proposal.json`). This registers a new immutable print package for the workflow and includes pending C2 patches when applicable. Print **this step-15 package**, measure in **step 16**, then build the next profile in **step 17**.

The mesh comes from Argyll's envelope and does not carry original device RGB coordinates. The interactive window therefore associates vertices with nearest forward samples from 65-level RGB cube faces and a 17-level interior grid, in absolute CIELAB D50. This is an approximate association; its distance and sampled Lab are retained in the saved anchors. A picked point is not proof of a profile defect, and extra measurements cannot extend the physical gamut. Assess the rebuilt profile with a fresh independent verification print.

ICC files outside a successful InkProf profile job can be inspected and selected, but cannot create a project refinement target. Report viewers retain their existing rotation-only behaviour.
