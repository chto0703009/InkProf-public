# ICC gamut surface

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

The **View gamut** button becomes available when the current iteration has a valid ICC profile. It opens a separate rotatable surface in CIELAB D50. The existing 2D/3D sample-point views remain available and retain their own meaning.

Both measurement certificate export paths include this surface: independently print-verified certificates and certificates for numerically checked iterations without separate print verification. HTML defaults to 2D at L*=50 and offers a selector for 3D L*/a*/b*. In 3D, drag to rotate or enable automatic rotation. PDF contains an exact mesh-plane intersection at L*=50, with a* horizontal and b* vertical. The comparison point viewer still defaults to 2D at L*=50.

The surface is calculated with the installed external ArgyllCMS `iccgamut` executable using `-d 5 -ff -ia -pl`: forward A2B, absolute colorimetric, CIELAB D50. The detail parameter is a sampling setting (approximately Delta E), **not an accuracy tolerance**. No convex hull of the measured patches is substituted. The display uses clipped sRGB previews, so the monitor cannot reproduce every colour on the surface.

This is the gamut described by the ICC model, not a new measurement, a quality score, an ISO conformance result, or proof of what every print can reproduce. The printer, paper and ink combination, profiling data and model all affect the result. Existing approval and verification requirements are unchanged.

## Traceability and portability

The export stores `gamut-surface.json` (Lab vertices, zero-based triangle indices and sRGB previews), the original Argyll `.gam`, and the tool log. `final-report.json` records the mesh file checksum and the source ICC SHA-256. Renderers reject a changed mesh or a mesh from another ICC. The named delivery ICC may have different metadata; the surface remains linked to the checked project original.

App-only viewing uses a temporary directory and does not change workflow state. During generation a progress dialog remains visible. If the tool or profile cannot produce a surface, the certificate states that it is unavailable, with a reason; no substitute figure is invented. The app shows an error. This optional visualization does not cancel otherwise valid certificate export.

The HTML viewer is included in the report and does not need a network connection or a third-party web viewer. External delivery bundles carry all underlying files. ArgyllCMS remains a separately installed program under its own licence; no Argyll source is incorporated.

References: [ArgyllCMS iccgamut](https://www.argyllcms.com/doc/iccgamut.html), [Argyll GAM file format](https://www.argyllcms.com/doc/File_Formats.html#gam).

Tested on macOS with MATLAB R2025b and ArgyllCMS 3.5.0. Windows and Linux have not been tested.

## Neutral lightness reference

All 3D Lab views show a contrasting L* reference through a*=b*=0, labeled from 0 to 100. It remains visible over surfaces or points. Interactive report and fixed certificate figures use the same reference. The line is a coordinate guide, not a measured neutral ramp or a claim that every point lies inside the printer gamut. Existing reports require regeneration to receive it.
