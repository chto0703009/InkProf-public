# RGB target: iterative refinement and the Argyll alternative

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Introduced 2026-09-26 as a geometric prototype. No measured colour model is included and no profile accuracy is promised.

## Open the window

```matlab
cd('/Users/christer/Desktop/InkProf')
paths=setupInkProf();
designer=inkprof.designTarget();
```

The window is in English. Choose **InkProf mesh refinement** or **Argyll OFPS**. The name is saved as the target name in the JSON and is suggested as the file name when saving. All numerical limits are user settings, not fixed point counts in the algorithm.

Enter the name in **Target name / file name** at the top left. A separate save area at the bottom shows **Not saved** and, after generation, the suggested file name. Generation does not save automatically. The **Save definition: TI1 + JSON…** button becomes available after generation (also after previewing the initial grid). The file dialog lets you choose both the folder and the final file name. After saving, the window closes. The paths are shown in MATLAB; no TIFF window is opened.

For the mesh method:

1. Enter **Initial levels per axis**: for example 5, 7, 9 or 11 gives 125, 343, 729 and 1331 cube points respectively, before extra grey points.
2. Enter **Maximum total patches**. The limit covers fitting, control and extra repeats. The initial grid plus extra grey points and a reserve for control/repeats must fit.
3. Choose **Preview initial grid**. The plot and table show the centroids of the tetrahedra as candidates, sorted by distance to the nearest fitting point. The cube view shows the existing fitting points.
4. If needed, enter **Max interior gap** in normalised RGB. Zero turns this threshold off. The maximum possible cube distance is sqrt(3), not 1.
5. **Initial gap ratio** is an optional geometric stopping criterion. Zero turns it off; otherwise the value must be greater than 1. The plot should be reviewed before the criterion is activated.
6. Choose **Refine / generate**. **Stop generation** interrupts the mesh method between additions without saving a half-finished target. Each new generation starts from the specified initial grid; a changed point limit reruns the same recipe. It is not a hidden continuation of another target.
7. **Save definition: TI1 + JSON…** opens a file dialog. Choose a new name; existing results are not overwritten.

The window default is 5 levels, at most 575 positions in total, 33 grey steps, 64 controls and 40 extra repeats (`designRGBTarget` keeps 12 repeats; see [Repeat patches and noise estimation](#repeat-patches-and-noise-estimation)). These are changeable starting values, not a demonstrated optimum. The controls and repeats do not count as new points in the refinement mesh.

## If the patch count is not enough

The error box now shows the chosen total, control and repeat counts, the full subtraction, how many fitting points are required and the minimum total limit needed. For the mesh method, cube points and additional unique grey points are counted before generation; grey points that already exist in the cube grid are not counted twice.

Example with 5 levels, 33 grey steps, 64 controls, 12 repeats and a total limit of 100:

```text
Available fitting points: 100 - 64 - 12 = 24
Required fitting points: 153 (5^3 = 125 grid points + 28 additional gray points).
Set Maximum total patches to at least 229 ...
```

229 is sufficient here for the initial grid and the extra roles; a larger limit is needed to actually add refinement points. With a total of 575, 64 controls and 12 repeats (the `designRGBTarget` defaults), 499 fitting points remain, which leaves room for 346 additions beyond the initial set's 153. With the window's 40 repeats, 471 fitting points remain, room for 318 additions.

Increase **Maximum total patches**, or reduce the initial grid, grey steps, **Control patches** or **Extra repeat patches**. The latter two can be set to zero for a pure mesh trial, but the cube and grey steps must still fit. Zero grey steps means no extra grey points beyond those already in the cube.

The Argyll alternative shows its existing reservation for eight corners and the chosen grey steps. This reservation is conservative because some points may overlap; the actual generated count is checked afterwards. No settings are changed automatically by the error box.

## What the iteration does

A Delaunay tetrahedral mesh is built over the unique fitting points in [0,1]^3 with MATLAB Base. The default method from algorithm version 2.0 is **interior**:

1. Compute the centroid of each tetrahedron as the mean of its four vertices.
2. Measure each candidate's distance to the nearest existing fitting point.
3. Sort the distances in descending order and add the candidate with the greatest distance.
4. Rebuild the triangulation and repeat.

All newly added points lie strictly inside the RGB cube. The initial grid's faces, edges, corners and grey points are kept unchanged. The method thus moves the refinement budget to the interior of the cube. It searches among the centroids of the tetrahedra, not continuously over the whole cube; it therefore does not guarantee that each new point is the centre of the largest possible void.

`parentTetrahedra` stores the four parent points for each new sample. `historyColumns` describes the history's columns and `sortedRefinementDistances` contains the candidate distances. `sortedEdges` and `sortedDistances` remain as separate edge diagnostics. The earlier edge-splitting alternative can be invoked with `Refinement="edge"` for comparisons and older experiments, but is not used by the window's default.

The method is inspired by mesh refinement, but is not an FEM solver or a physical error estimator. The candidate set changes when the triangulation is rebuilt; the candidate maximum need not decrease with each addition. Symmetric meshes can be triangulated differently between MATLAB versions. Point distribution, method version and parent relationships are therefore saved. Differences in RGB distance are not measured colour errors.

### Separate coverage measures

`coverage` describes the distance to the nearest fitting point on a fixed grid of 33³ sample positions. Samples on the surface of the cube and strictly inside it are reported separately with mean, 95th percentile and examined maximum. The number of fitting points on the surface and inside is also shown in the dialog. This is a reproducible sampling measure, not a proven maximum over a continuous volume. Controls and repeats are not included as support in the coverage measures.

## Stopping criteria

The algorithm stops when the fitting budget is used up or the largest candidate distance is at most the active distance threshold. An insufficient budget gives a clear error before generation. The API parameter `MaxEdge` retains its older name for compatibility reasons, but refers to candidate distance in `Refinement="interior"`. In the window the setting is called **Max interior gap**.

When gap detection is enabled, the ratio d(k)/d(k+1) is computed in the initial sorted spectrum of candidate distances. The largest ratio must reach the user's limit. The lower level d(k+1) then becomes a frozen distance threshold: the candidates above the level are refined until even the largest candidate distance reaches the level, or the point budget runs out. If no ratio satisfies the condition, the point limit and any manually specified threshold are used. If both thresholds are used, the larger applies, that is, the condition reached first.

Freezing the level avoids the algorithm continually moving its target to new, smaller distances. The gap's ratio, index, upper/lower level and whether it was used are stored in the JSON. The stopping reason is shown in the window. This first gap criterion needs to be compared with real verification errors later.

## Extra grey samples, controls and repeats

- The grey steps are placed on R=G=B, merged with the cube grid and duplicates are removed. This is control-value grey, not proof of a neutral print.
- The control points come from a deterministic sequence of radical inverses in bases 2, 3 and 5. They are chosen outside the fitting set and are never used for mesh refinement. This is a simple first control distribution, not the final perceptual grey/gamut check.
- Extra repeats copy an even selection of indices in the fitting set. They have their own sample IDs and `repeatOf` references. The selection is not yet an optimised distribution between white, black and different hues.
- The definition saves RGB as floating point. TIFF16 quantisation belongs to the later printing step.

The roles are saved as `fit`, `control` and `repeat`. All are printed and measured. **Profile building shall use the saved role file to separate training and controls.** A generic TI3 does not automatically contain this policy. The current generic measurement import does not automatically carry over the designer roles; the design JSON must be preserved and linked via the matching layout. The project's iteration workflow links roles and checks them before continued profiling; standalone imports require the correct matching data.

## The Argyll alternative

Choose **Argyll OFPS** to let targen choose the fitting points. The same total budget, control set size and number of repeats are used. The mesh parameters are disabled in the window. targen is run with print RGB, eight cube corners, the selected grey ramp and the desired fitting budget. The actual arguments and version information are saved. The generated set is analysed with the same Delaunay edge measure, but is not refined by InkProf.

### Argyll methods and preconditioning

The **Method** drop-down contains, in addition to InkProf's mesh method, Argyll's placement algorithms for full-spread patches (`targen`):

| Choice | targen | Space |
|---|---|---|
| Argyll OFPS (default, adaptive) | default | adaptive, perceptual when preconditioned |
| Argyll incremental far point | `-t` | device |
| Argyll quasi-random, device / perceptual | `-q` / `-Q` | device / perceptual |
| Argyll body-centred cubic, device / perceptual | `-i` / `-I` | device / perceptual |
| Argyll random, device / perceptual | `-r` / `-R` | device / perceptual |

**Pre-conditioning ICC** is passed to targen as `-c` and is optional. It is an existing RGB printer profile for the same or a similar paper, for example the paper manufacturer's profile or an earlier InkProf profile. targen uses it only to estimate perceptual distances, and then places more patches near the neutral axis and where the eye is sensitive. The profile is never used as measurement data.

The profile affects OFPS (adaptation 1.0 when a profile is present) and the perceptual methods. Perceptual methods without a profile give a notice, since Argyll's default model assumes a saturated device with high contrast. The profile is checked structurally: it must be an RGB printer profile with Lab or XYZ PCS. Its SHA-256 is saved in the JSON, and an exact copy is saved as `<name>-precondition.icc` next to the TI1 file.

Argyll cannot use ICC v4 profiles for lookups. All Argyll pre-conditioning and profile-import routes use the same `iccV2Compatibility` routine: **Create v2 copy / Cancel**, preservation of the original, and the common approximate v2 reconstruction from a 17³ relative A2B grid prepared with inverse Bradford media-white adaptation. The resulting v2 profile is cached by the original SHA-256 so every route uses identical ICC bytes. Same-engine LittleCMS forward and inverse validation results are recorded under `preconditioning.conversion`. This is an approximation, not an unchanged original profile; inverse and perceptual mapping are rebuilt. Synthetic samples never become measured training data.

**Optimized points (-G)** is the default in the window and gives slower but better optimised points. The combination of preconditioning + `-G` + extra grey steps (`-g`) corresponds to Torger's recommended workflow (*Printer profiling with Argyll and Colormunki*): `targen -v -d2 -c <precond.icc> -G -g<n> -f<n>`. According to him, the difference from the default spread is small with many patches. Preconditioning is the optimisation he considers worthwhile.

From MATLAB, without the window:

```matlab
d = inkprof.designRGBTarget(Method="argyll", PreconditionProfile="HFA_Baryta.icc", Optimized=true, ...
    MaxPoints=575, GraySteps=33);
```

`Adaptation` (`-A`, 0–1) and `NeutralEmphasis` (`-N`, 0–1) are available as function options.

The Argyll call is synchronous; an interruption is registered after the external call returns control. It is not the same immediate interruption as between the mesh method's iterations. The same target count does not automatically mean the same colour quality.

## Saved files and layout

If the file dialog specifies `mitt-mal.ti1`, only the following are created:

- `mitt-mal.ti1`: mathematical RGB points, without measured values or page layout.
- `mitt-mal.json`: name, parameters, roles, points, parent relationships, history, sorted edge distances, stopping reason and source information. `definition.ti1SHA256` links the JSON to the TI1.

Mesh and Argyll generation are saved in the same way. No TIFF or TI2 is created. DPI, page size, randomisation and seed are chosen in the separate TIFF16 window. Open the saved TI1 file there and keep the JSON next to it so that the mesh information can be read back with hash checking. The original's definition and JSON are not changed when a print is created.

The TIFF16 window creates a new package folder with TIFF16, TI2 and the print's JSON. The TI2 belongs to the actual page layout. The design's floating-point RGB is kept in the definition; the layout contains the RGB16 values. The earlier combined function `saveRGBDesign` remains for older scripts, but is no longer called from the mesh window.

## Programmatic calls

```matlab
d=inkprof.designRGBTarget(Name="RGB-mesh-575", ...
    Levels=5, MaxPoints=575, GraySteps=33, ...
    ControlCount=64, RepeatCount=12, ...
    MaxEdge=0, GapRatio=0);

saved=inkprof.saveRGBDefinition(d, ...
    fullfile(paths.Projects,'RGB-mesh-575.ti1'));

% Separately, when you want to create the print:
window=inkprof.renderTarget(saved.ti1);
```

`Refine=false` gives the initial grid without refinement. `Method="argyll"` selects targen. No instruments are started.

## Verification

Automatic tests check preserved starting points, midpoint relationships, RGB limits, budget, stopping, repeat references, separated controls, sorting, interruption, the Argyll alternative, TIFF16/TI2/JSON export and the dialog's basic flow. Physical measurement and comparison of profiles from the mesh method and OFPS respectively remain to be done.

Background: [investigation of RGB coverage](../research/rgb-target-design.md). MATLAB's [Delaunay triangulation](https://www.mathworks.com/help/matlab/ref/delaunaytriangulation.html) provides tetrahedral meshes and [edges](https://www.mathworks.com/help/matlab/ref/triangulation.edges.html) their edges. The gap and refinement policy above is InkProf's own prototype.

## Completed geometric example

A historical trial with the earlier edge-splitting method (version 1.0) gave 153 initial fitting points (5³ and extra grey steps), 346 midpoint additions and 499 final fitting points. With 64 controls and 12 repeats this became 575 measurement positions. The longest mesh edge decreased from 0.4330127 to 0.25. The stopping reason was the point limit. The run took about 6.8 seconds including dialog updates on the computer in question; this is not a platform-independent timing figure.

The example has been saved locally under `projects/RGB-mesh-575-demo.*` and `projects/RGB-mesh-575-demo-files/`. The package check passed. No physical measurement has been made of this new target.

## Cancel, save and page count

**Cancel** closes the window without saving. During generation, the button requests interruption at the next safe checkpoint and then closes the window; an ongoing external Argyll call must return first. No half-finished definition is saved. **Stop generation**, on the other hand, interrupts only the refinement and leaves the window open. (Cancelling in the separate TIFF16 window is described in [the TIFF16 dialog](tiff16-dialog.md#cancel-save-and-page-count).)

After a successful save, the mesh window closes automatically without opening the print window. On a save error it remains. Page count and preview belong solely to the separate TIFF16 step.

## Comparison with 575 positions, version 2.0

Same budget (499 fitting, 64 control, 12 repeat), initial grid 5³ and 33 grey steps. The density below is measured against 33³ sample positions; only the 29,791 strictly interior sample positions are included in the interior measures.

| Measure | Earlier edge splitting | Interior refinement |
|---|---:|---:|
| Fitting points on the surface | 246 | 98 |
| Fitting points inside | 253 | 401 |
| Mean distance inside | 0.07405 | 0.06641 |
| 95th percentile inside | 0.11561 | 0.09882 |
| Examined maximum distance inside | 0.13975 | 0.12614 |
| Mean distance on the surface | 0.05974 | 0.06942 |

This verifies the intended redistribution and better geometric coverage inside for this particular budget. It does not prove lower ΔE or universal superiority. No previously saved target file is changed automatically.

## Choice of interior placement, version 2.1

The **Interior placement** field gives three choices: **Centroids (default)**, **Sphere centers in tetrahedra** and **All interior sphere centers**. Argyll mode disables the choice.

The circumcentre is the point with equal distance to the tetrahedron's four vertices. The first sphere alternative accepts only centres within the tetrahedron itself. The second also accepts centres outside their tetrahedron, provided they lie strictly inside the RGB cube. Both keep centroids as fallback candidates. In all cases the largest candidate distance to the nearest fitting point is chosen.

The API choice is `InteriorPlacement="centroid"`, `"contained-circumcenter"` or `"circumcenter"`. The JSON saves the chosen method and `insertionKinds` for each fitting point as well as `candidateKinds` for final candidates. For circumcentres, `parentTetrahedra` identifies the four vertices of the defining sphere.

Centroids are kept as the default: the new alternatives did not improve all coverage measures. See the [comparison results](../research/interior-placement-comparison.md), including an independent test with 100,000 random RGB positions.

## Planned feedback from measurement errors

Measurement-driven refinement is implemented as a separate workflow: [error-driven refinement](error-driven-refinement.md), [verification feedback](verification-feedback.md), and [automatic profile iteration](automatic-profile-iteration.md). These link observations to device RGB, preserve earlier measurements and propose additional patches. The geometric target generator itself does not acquire measurement-error feedback simply by generating a mesh; use the matching refinement API and role/identity checks.

## v1.0.0 project settings

Project details also records dye/pigment ink type, printer coating and coating settings. Matte paper can activate configurable extra dark patch sampling and shadow table emphasis. Read [matte shadow profiling](matte-shadow-profiling.md), [the current workflow](workflow-v1.0.md) and [gamut surface](gamut-surface.md). Certificates distinguish the saved build recipe from requested future patch counts.

### Repeat patches and noise estimation

The window suggests 40 **Extra repeat patches** (previously 12). The repeats are distributed across the fitting colours and end up in other places on the sheet. The difference between them is the measure of print and measurement noise on which `inkprof.estimateMeasurementNoise` and its approximate `colprof -r` suggestion are based; at least 5 repeated colours are required, and 30–50 gives a stable estimate. The function `designRGBTarget` retains the default value 12 for backward compatibility.

## Patch budgets for a complete profiling job

The [best-practice appendix](profiling-best-practice.md) recommends roughly 1,500–2,000 patches for a careful full i1Pro2 profiling job, or about 800–1,000 when budget is tighter. A 300–600-patch pilot primarily checks the setup. Count fitting samples, repeats and controls consistently and review the generated total; these are not new software defaults. X-Rite recommends 1,586 or 2,033 patches in its own [i1Profiler RGB workflow](https://www.xrite.com/it-it/service-support/recommended_rgb_printer_profiling_with_i1profiler), while [Torger](https://www.torger.se/anders/photography/argyll-print.html) describes approximately 840 as a useful Colormunki compromise. Instrument, paper and print system differ; neither count proves the optimum for InkProf.

Use a suitable existing RGB printer ICC to guide perceptual Argyll target placement. This is preconditioning, not pixel conversion: the base fitting target remains device RGB and is printed without another profile transform. Preserve instrument patch geometry; X-Rite’s wider-patch suggestion is not a command to change an InkProf layout blindly. See [target printing](target-print-standard.md).
