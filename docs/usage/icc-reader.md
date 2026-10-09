# ICC reader A1

> InkProf 1.0.0-rc.4, version marking updated 2026-10-09. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Implemented 2026-09-27. MATLAB Base uses InkProf's selected Python. The reader needs only the Python standard library.

```matlab
cd('/Users/christer/Desktop/InkProf')
setupInkProf();
[profile, jsonFile] = inkprof.readICC();
```

Choose an `.icc` or `.icm` file. The window shows the description, version, class, device colour space, PCS, tags and warnings. Cancelling the file chooser gives no result and saves nothing.

Script use:

```matlab
[profile, jsonFile] = inkprof.readICC('my-profile.icc', ...
    OutputFolder='my-project/profiles/inspections', ShowDialog=false);
```

The original profile is not changed. A unique JSON is saved under the project's `profiles/inspections` if the source is in an InkProf project, and under `projects/icc-inspections` otherwise. `OutputFolder` can be given explicitly. If there is a project manifest where the result is saved, it is updated; outside a project, the result stands alone. The original's path and SHA-256 are in the JSON. A1 does not copy the profile itself; unchanged profile import and Save as belong to A2.

## What is supported

Supported: the ICC v2/v4 header, the tag table, and desc/mluc/text/XYZ tags. Other tag types are listed but not decoded. Shared data ranges are allowed.

Rejected: truncated profiles, faulty table ranges, duplicated signatures and partial overlap. An error in a decoded tag is shown as a warning. Profiles larger than 256 MiB are rejected by an explicit resource limit.

`rgbOutputCandidate` means class prtr, RGB, and a Lab/XYZ PCS. It is not an approval for profiling. No LUT evaluation, full ICC conformance check or quality assessment is done. Non-RGB profiles can be inspected. The ICC profile ID is reported, but its checksum is not verified.

Verification: nine Python error-handling/format tests, MATLAB integration including the dialog, and three local Epson 3880 profiles (2.1/2.4/4.2) whose descriptions were compared with LittleCMS. No instrument measurement is needed.

## A2 – import and Save as

A1 was accepted by the user on 2026-09-27. A2 adds the buttons **Import into project** and **Save copy as…** to the same window.

### Import

Import into an existing InkProf project. If a new one is needed, create it first:

```matlab
paths = inkprof.paths();
project = inkprof.createProject(fullfile(paths.Projects,'my-profiles'));
[profileFile, record] = inkprof.importICC('', project);
```

An empty source path opens a file chooser. `inkprof.importICC()` also lets the user choose the project folder. Cancel leaves the project untouched.

The import gets a unique subfolder under `profiles/imported`, containing the original file name and `inspection.json`. The copy is validated before it is published, its hash is compared with the source, and the manifest is updated. The JSON uses a relative source path and keeps the original path as provenance. No automatic conversion or profile editing is done; even unknown tags are preserved byte for byte.

### Save as

```matlab
[savedFile, receipt] = inkprof.saveICC(profileFile);
```

This opens Save as.

- Renaming the file does not change the profile's internal description.
- An existing destination requires confirmation. In scripts, use an explicit path and, for an intentional replacement, `Overwrite=true`.
- Source and destination must not be the same file.
- A faulty source profile is rejected before an existing destination is replaced.

After copying, the SHA-256 is checked. If the source belongs to a project, an export receipt is saved under `profiles/exports` with destination, hash and time, and the manifest is updated. The export receipt documents the moment of export; it does not monitor later changes to external files.

A2's integration test checks import, hash-identical export, protection against accidental replacement, an invalid source, the manifest link, and that the imported profile can still be found after the project folder has been moved. User acceptance of A2 remains.
