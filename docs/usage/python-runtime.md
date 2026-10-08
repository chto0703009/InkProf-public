# Local and optional Python environment

> InkProf 1.0.0-rc.2, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Python is not needed for target generation in MATLAB. Python is used by the chartread bridge, spectral analysis, profiling and reports.

## Create the environment on each computer

Start from InkProf's root folder. On macOS/Linux:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-report.txt
```

On Windows:

```powershell
py -3 -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements-report.txt
```

The Python used to create the environment must be 3.11–3.13 for the full analysis and report workflow (the locked packages in `requirements-analysis.txt` and `requirements-report.txt`). `inkprof.checkPython` only enforces the bridge minimum, Python 3.10 or later, so a 3.10 environment can measure but is not qualified for analysis and reports. If needed, give the full path of the installed Python executable.

Never copy `.venv` or `local-config` between computers; both are ignored by Git. `requirements-report.txt` includes the analysis and report dependencies with version requirements. Reviewed dependency versions and licences are documented in `licenses/inventory.json`.

## Discovery and checking

`setupInkProf()` finds `.venv/bin/python` or `.venv/Scripts/python.exe` relative to InkProf's root folder. It does not run Python unless explicitly asked to, and it also works without Python.

```matlab
paths=setupInkProf();
disp(paths.PythonExecutable);
inkprof.checkPython();
```

An alternative installation can be chosen and saved locally:

```matlab
paths=setupInkProf(PythonExecutable="/full/path/to/python");
% Windows example: PythonExecutable="C:\Tools\Python\python.exe"
```

An explicit choice is checked before it is saved. The priority is:

1. explicit argument,
2. local setting,
3. the `.venv` in InkProf's root folder.

No automatic fallback via PATH is used at run time. An invalid local setting gives a clear error when Python is needed; replace it with a new explicit choice. Relative configuration paths are resolved from InkProf's root folder.

To return to the project environment, give `PythonExecutable=".venv/bin/python"` (Windows: `.venv\Scripts\python.exe`). Automatic discovery does not save an absolute `.venv` path. `setupInkProf(CheckPython=true)` checks the current environment without requiring any terminal activation.

## Calling bridge code

```matlab
result=inkprof.runPython("bridge/script.py",["--input","file with spaces.json"], ...
    RequiredModules=["json"]);
```

- The call uses a full executable path and separate process arguments, without a shell.
- The check verifies the Python version and the modules that the bridge function requires.
- Python is not loaded into MATLAB via `pyenv`.
- Paths with spaces work, and a terminal's activation of another environment does not affect the choice.
- The run has a timeout and reports errors from the process.

## ArgyllCMS on different computers

ArgyllCMS also uses the local configuration in `local-config/settings.json`. The priority is:

1. explicit ArgyllBin,
2. saved local choice,
3. ARGYLL_BIN,
4. automatic discovery.

Relative choices are resolved from InkProf's program folder. Automatic discovery is never saved as a fixed path.

On Apple Silicon the app looks for Homebrew under `/opt/homebrew`; on an Intel Mac under `/usr/local`. Both `opt/argyll-cms/bin` and `bin` are checked, even if MATLAB was started from the Finder without Homebrew in PATH. HOMEBREW_PREFIX and PATH are also supported. The folders must contain targen and printtarg, and setup checks the tools' version responses. Other operations check their own tools.

```matlab
setupInkProf();                       % local discovery/configuration
setupInkProf(ArgyllBin="auto");       % remove a saved override
setupInkProf(ArgyllBin="/any/Argyll/bin"); % validate and save locally
```

An unavailable older saved path without a source marker gives a warning, and discovery runs again. A new explicit but invalid choice gives an error and is not replaced by another installation.

Install ArgyllCMS on each computer. Copy only the project folder between computers, not local-config or the Python environment. Homebrew installation: `brew install argyll-cms`.

Sources: https://docs.brew.sh/Installation and
https://formulae.brew.sh/formula/argyll-cms
