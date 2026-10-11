# Local and optional Python environment

> InkProf v1.0.1 preparation; installation troubleshooting updated 2026-10-11. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

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

To return to the project environment, give `PythonExecutable=".venv/bin/python"` (Windows: `.venv\Scripts\python.exe`). Automatic discovery does not save an absolute `.venv` path. `setupInkProf(CheckPython=true)` now imports the full analysis/report dependencies in the selected environment, including `scipy.spatial.cKDTree` and `scipy.sparse.linalg.svds`, without requiring terminal activation. Analysis operations also import their required packages before starting. Merely finding an installed package is not sufficient. A basic `inkprof.checkPython()` remains suitable for the standard-library measurement bridge.

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

## SciPy compiled-library failure on Apple Silicon

A reported M4 installation with Python 3.13, NumPy 2.2.6 and SciPy 1.15.3 failed while importing `scipy.spatial.cKDTree`. macOS rejected `_spropack.cpython-313-darwin.so` with `__DATA/__thread_bss ... zero-fill section type, but offset field is not zero`. The same error occurred in a fresh environment on the internal disk. This is an import/binary compatibility failure, before image refinement runs; it does not establish a fault in the printed chart or profiling algorithm. See [SciPy issue 25635](https://github.com/scipy/scipy/issues/25635).

The user's separate M4 test successfully imported `cKDTree` and `svds` with NumPy 2.2.6 and SciPy 1.16.3. New installations therefore pin `scipy==1.16.3` in `requirements-analysis.txt`, also included by `requirements-report.txt`. This evidence is an import test, not qualification of every macOS version or a completed physical profiling workflow.

InkProf stops the affected operation with `inkprof:PythonImport` and displays the selected Python path, repair commands and original error. Run the displayed commands on the affected computer. Packages are never installed automatically. For the default environment, run from the InkProf folder:

```sh
.venv/bin/python -m pip install --upgrade --force-reinstall --no-cache-dir --only-binary=:all: scipy==1.16.3
.venv/bin/python -m pip check
.venv/bin/python -c "from scipy.spatial import cKDTree; from scipy.sparse.linalg import svds; print('SciPy OK')"
```

Use the configured Python executable instead if it is outside `.venv`. On Windows use `.venv\Scripts\python.exe`. Restart MATLAB, then run:

```matlab
setupInkProf(CheckPython=true);
startInkProfApp();
```

Retry **From image** only after the check passes. If it fails, retain the displayed package error and Python path for diagnosis. Existing projects and measurement files are not changed by this check or package repair.

The published v1.0.0 archive retains its original dependencies. These safeguards and the new pin are post-release source changes; reinstalling its original requirements would restore SciPy 1.15.3.
