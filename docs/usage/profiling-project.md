# Self-contained profiling project

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

A profiling job lives in one shared folder with `inkprof-project.json`. The JSON files for definition, layout, measurement and analysis keep their own roles; the project manifest brings them together and stores the history.

```matlab
paths=setupInkProf();
project=inkprof.createProject(fullfile(paths.Projects,'my-profiling-project'), ...
    Name="Printer / paper / print mode");
```

## Folders and workflow

| Folder | Contents |
|---|---|
| `sources/` | Imported definitions and other source material. |
| `targets/` | Saved definitions and complete TIFF/TI2/layout packages. |
| `measurements/` | Measurement sessions and re-readings. |
| `analyses/` | Optional place for derived analyses; they can also be saved next to the measurement. |
| `reports/` | PDF and check results; reports can also sit next to the measurement. |
| `profiles/` | Profiles and validation material. |

Save definitions in the project and open them with `inkprof.renderTarget`. The render dialog suggests the project's targets folder when the input belongs to the project. `inkprof.measureChart` creates measurement sessions in the project's measurements folder when the chosen TI2 is inside the project. The default place for an analysis is next to the measurement file. Give a PDF location inside the project.

## Automatic updates

The MATLAB APIs record each successful save of an RGB definition, TIFF16 package, chart preparation, measurement settings, measurement result, spectral analysis and PDF/check report. Older standalone folders keep working without being converted automatically. If a manifest cannot be updated after a save, a warning is shown; saved measurement data are not destroyed. In that case run `inkprof.updateProject(project)`.

Files copied manually, or created by direct Python/Argyll CLI calls, are registered afterwards with the same update function. No background file-system monitoring is installed. Profile generation and delivery are recorded in the project manifest and workflow when the operations complete.

```matlab
inkprof.updateProject(project,Step="external-files-imported");
```

The manifest contains the project ID, revision number, relative paths, document types, sizes and SHA256 of the files. Each step lists changed and removed paths. Earlier manifests are saved in `.manifest-history/`, which is not counted recursively in the file inventory. A lock prevents simultaneous writes, and the update is published via a temporary file.

Known dependency hashes between chart, TI3, measurement and analysis are matched to the project's files in `links`. Unmatched hash references are reported in `unresolvedLinkCount`. This is not automatically proof that the project lacks run inputs; a reference may, for example, point to an older origin. Manifest history is not a backup of older file contents. Do not delete raw data.

## Physical printing

TIFF/layout describes what was prepared. Information about the actual printer, paper, driver, print mode and colour management is recorded explicitly, and otherwise stays unknown. Update the whole printing record:

```matlab
printing=struct('status',"user-recorded",'printer',"...",'paper',"...", ...
    'driver',"...",'quality',"...",'colorManagement',"...",'notes',"...");
inkprof.updateProject(project,Step="physical-print-recorded",Printing=printing);
```

## Moving and existing work

The current 575-patch chain has been copied to `projects/Canon-575-20260927`, and the original folders have been preserved. All copied files were verified with SHA256.

Historical absolute paths in the raw data have not been rewritten, because that would change checksums. `relocations` maps their old root folders to relative paths inside the project; the PDF routine uses this mapping for the layout. New measurements are to be started from the copied TI2 file in the project's targets folder.

Take the whole project folder when moving to another computer. `inkprof.updateProject` can then update the inventory without depending on the old project root path.

## v1.0.0 project settings

Project details also records dye/pigment ink type, printer coating and coating settings. Matte paper can activate configurable extra dark patch sampling and shadow table emphasis. Read [matte shadow profiling](matte-shadow-profiling.md), [the current workflow](workflow-v1.0.md) and [gamut surface](gamut-surface.md). Certificates distinguish the saved build recipe from requested future patch counts.

## Delivered ICC versions

In **Project details → Profiling → Delivered ICC versions**, choose **v2**,
**v4.4** or **Both**. Older projects default to v2. New jobs record the selection
in their recipe and status; v4.4 is produced as an additional file, with conversion
hashes and structural checks. Argyll's v2 calculation candidate is always retained.

Export follows the current project selection. v4.4 delivers the converted profile
at the chosen ICC filename. Both delivers v2 there and a sibling
`<chosen-name>-v4.4.icc`. Changing only this selection invalidates export,
not raw measurements or profiling inputs. Existing-profile verification delivers
the imported original regardless of this profiling preference.

The v4.4 converter preserves colorimetric tables but remaps perceptual and
saturation tables. The certificate identifies the checked v2 candidate and
records the converted delivery separately; it does not claim independent
print verification of v4.4 perceptual behaviour. Check the v4.4 copy in the
application and rendering intent used for production. Structural checks are
not a complete ICC conformance certification.
