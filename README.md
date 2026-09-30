# InkProf v0.9

**InkProf - When colours have to be right**

**InkProf - När färgerna måste bli rätt**

InkProf is an open-source MATLAB application for RGB printer profiling: colour targets, spectral measurements, ICC generation, independent print verification and traceable refinement. Each project has its own folder, a persistent JSON workflow, prerequisites and a readable results log. You can close the app while prints dry and resume the same project later.

The app saves TIFF16 targets for separate printing. Measurement is started in the app using a compatible spectrophotometer. ICC candidates are built with ArgyllCMS, checked numerically and assessed against a separately printed and measured verification target. After user approval, save the ICC file and PDF/HTML reports to locations of your choice. A rotatable CIELAB view shows the profile's predicted verification colours.

## Install and start

This is a **source release**, not a standalone executable. Install MATLAB, Python and ArgyllCMS separately.

- Tested on macOS with MATLAB R2025b (base MATLAB; no mandatory add-on toolboxes).
- Python 3.11-3.13 for analysis and reports; tested with 3.13.
- ArgyllCMS 3.5.0 was used in development. Configure its `bin` directory explicitly if it is not on PATH.
- Instrument measurement uses a POSIX bridge. Windows instrument operation has not been qualified.
- The current project app uses Swedish labels. English PDF documentation is included.

Download the v0.9 source archive or clone this repository:

```sh
git clone https://github.com/chto0703009/InkProf-public.git
cd InkProf-public
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-report.txt
```

From the repository folder in MATLAB:

```matlab
paths = setupInkProf(CheckPython=true);
% If needed: setupInkProf(ArgyllBin="/path/to/Argyll/bin",CheckPython=true);
startInkProfApp();
```

Choose **Nytt projekt** (new project) or **Öppna projekt** (open project). Create your own RGB target or import a definition you are entitled to use. Print the saved TIFF16 separately and use its matching target data for measurement. The app does not print, install profiles automatically or certify ISO conformity.

## Documentation

- [English presentation (PDF)](docs/usage/InkProf-presentation-English.pdf)
- [English profiling workflow and MATLAB guide (PDF)](docs/usage/InkProf-profiling-workflow-MATLAB-guide-English.pdf)
- [Svensk presentation (PDF)](docs/usage/InkProf-presentation.pdf)
- [Svensk MATLAB-guide (PDF)](docs/usage/InkProf-profileringskedja-MATLAB-guide.pdf)
- [Project app, step guards and recovery (Swedish)](docs/usage/project-workflow-app.txt)
- [Release notes](docs/releases/v0.9.md) and [public release scope](RELEASE_SCOPE.md)

The guides describe callable operations as well as the project workflow. Historical research notes may refer to private experiments or fixtures that are not part of this public release. The release notes and this README take precedence for installation and current scope.

## Quality and limitations

The workflow distinguishes training data, development data and independent checks. If a verification result is used to refine a profile, later final verification requires independent data. A successful profile build does not prove acceptable print quality. Physical instrument compatibility, repeatability, paper, drying and print settings must be checked for the actual setup. Basic measurement has been tried with an i1Pro 2; all device modes and platforms are not qualified.

## Tests

```sh
.venv/bin/python -m unittest discover -s tests -p 'test_*.py'
.venv/bin/python tools/check_license_inventory.py
```

In MATLAB, after setup:

```matlab
setenv('INKPROF_TEST_PYTHON',char(paths.PythonExecutable));
r = runtests('tests');
assertSuccess(r);
```

Tests depending on excluded third-party reference material are not shipped. The remaining suite uses generated or synthetic inputs. Automated tests are not a substitute for instrument and print qualification.

## Licence and attribution

Copyright (c) 2026 Christer Törnkvist. InkProf's own code and documentation are **GNU GPL version 3 or later** (`GPL-3.0-or-later`). See [LICENSE](LICENSE), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [licenses/](licenses/).

Third-party resources keep their own licences. ArgyllCMS is installed separately; the reviewed 3.5.0 tools report AGPLv3. MATLAB is proprietary and requires a separate licence. No MATLAB, Python or Argyll runtime is bundled. The unmodified CxF3 schema carries its own included licence. Other product names are descriptive; InkProf is not endorsed by their vendors.

### Warranty and responsibility

InkProf is provided as is, without warranties. Users are responsible for checking measurements, ICC profiles and print results before use. To the extent permitted by applicable law, the copyright holder is not liable for damage or loss arising from use. See GNU GPL v3, sections 15–17. This summary does not replace the licence.

InkProf tillhandahålls i befintligt skick utan garantier. Användaren ansvarar för att kontrollera mätningar, ICC-profiler och utskriftsresultat före användning. I den utsträckning tillämplig lag tillåter ansvarar upphovsrättsinnehavaren inte för skador eller förluster som uppstår genom användningen. Se GNU GPL v3, avsnitt 15–17.

 Report reproducible issues through [GitHub Issues](https://github.com/chto0703009/InkProf-public/issues), removing private measurements and personal data first.

Maintainer: Christer Törnkvist - christer@borgasundsfotografiska.se
