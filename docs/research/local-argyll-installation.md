# Local ArgyllCMS installation

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Checked 2026-09-25 following a path provided by Christer.

## Paths

- Installation root: `/Users/christer/Argyll_V2.3.1`
- Documentation index: `/Users/christer/Argyll_V2.3.1/doc/ArgyllDoc.html`
- Tool directory: `/Users/christer/Argyll_V2.3.1/bin`

`targen`, `printtarg` and `chartread` are present in the tool directory. These paths are local environment configuration, not hard-coded requirements for InkProf.

## Documented support for the first delivery

The local `doc/printtarg.html` describes:

- TIFF with 16 bits per channel through `-T`.
- TI2 as the accompanying description of control values and layout.
- Randomised patch placement as normal behaviour; `-r` disables the randomisation.
- `-R` for a specific random seed.
- Instrument-adapted layout, page size and margins.

This covers the central tool functions for InkProf's first planned delivery. It is documented support, not a completed verification of TIFF export or physical measurement.

## Version and run status

The directory name indicates V2.3.1 but the heading of the documentation index states **V2.3.0**, dated 27 June 2022. This discrepancy must be preserved in the environment inventory; the binary version must not be determined from the directory name alone.

Attempts to run `printtarg '-?'` and `targen '-?'` ended with **exit code 137 and no output**. The cause has not been established. The installation is therefore not yet verified as runnable on the current computer. No security settings or program files have been changed.

Before the implementation's integration tests, a working Argyll installation needs to be chosen or this installation troubleshot. After that, the actual tool version is recorded and a small TI1 → TIFF16 + TI2 sample is run.

## Use in InkProf

### Working installation found during implementation

On 2026-09-25, `/usr/local/bin/targen` and `/usr/local/bin/printtarg` were verified; they are symlinks to the Homebrew installation `/usr/local/Cellar/argyll-cms/3.5.0/bin/`. Both identify themselves as **3.5.0**. This installation runs target generation and TIFF16/TI2 export in InkProf's integration tests. MATLAB R2025b Update 7 is used. The earlier installation problems above remain as history; no security settings needed to be changed.

InkProf should be able to configure the path to Argyll and record the version used in the JSON manifest. The local documentation is used as a version-matched reference together with the tools' own help text when they can be started.
