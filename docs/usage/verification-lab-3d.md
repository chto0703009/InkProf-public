# Rotatable Lab view of a verification target

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

`fig = inkprof.showVerificationLab(referenceFile)` opens an ordinary MATLAB figure that can be rotated and zoomed. The input is `verification.json` from a fully rendered C2 package. Without an argument, a file chooser opens. MATLAB Base is sufficient.

The points show `predictedLabD50Absolute`: the Lab the profile computes forward after its own inverse and RGB16 quantization have been applied. They are not the target's desired Lab, and they are not measured values. The point cloud shows the selected patches, not the printer's whole gamut or its surface.

The axes are a*, b* and L*. The display colours are converted from Lab D50 via Bradford to D65 and then to sRGB. Colours outside sRGB are clipped in the display only; the coordinates are not changed, and the original data are preserved. Rotation is active from the start. To see the coordinate, ID and Lab of a point, choose Data Tips in the figure toolbar.

Use `Visible=false` to export or check the figure without opening a window. The figure's `UserData` contains:

- the reference file,
- Lab values and coordinates,
- IDs,
- display RGB,
- a clipping flag.

## Marking the largest training error

`inkprof.showVerificationLab(referenceFile,FitReport=fitFile)` adds the point with the highest `deltaE00` in `profile-fit.json`. The report's profile hash must match the verification target's ICC.

| Mark | Shows |
|---|---|
| Black/yellow ring | the profile's prediction for the original training patch's RGB |
| Cross | that patch's measured Lab |
| Line | connects the two |

The Euclidean Lab length of the line is not ΔE00. The point is a separate diagnostic overlay and need not coincide with the new verification patches.

For candidate 3 in the 991 run, the maximum is 4.4397 ΔE00, at the earlier supplementary target U22. This is not the measurement result for the new print.

## Neutral lightness reference

All 3D Lab views show a contrasting L* reference through a*=b*=0, labeled from 0 to 100. It remains visible over surfaces or points. Interactive report and fixed certificate figures use the same reference. The line is a coordinate guide, not a measured neutral ramp or a claim that every point lies inside the printer gamut. Existing reports require regeneration to receive it.
