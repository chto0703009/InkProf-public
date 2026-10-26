# Enhetlig lokal Pythonmiljö

Varje aktiv programinstallation har en egen `.venv`, med Python **3.13.6** och exakt samma fullständiga paketlista i `requirements.txt`. Miljöerna delar inga paketmappar och byggs om var för sig efter datorbyte. EXP använder samma miljöstandard, även om dess RAW-avkodning använder LibRaw direkt.

Kör programmets vanliga startkommando. En saknad eller ogiltig miljö ger dialogen **Prepare for this computer**. Ett datorbyte kan kräva ombyggnad; Python 3.13.6 förbereds vid behov enligt avsnittet nedan. Inga externa Pythonmiljöer väljs automatiskt som programruntime.

Gemensamma underhållskommandon från programmets kodmapp:

```matlab
setup_python_environment("check")
setup_python_environment("sync")
setup_python_environment("rebuild")
```

`sync` och `rebuild` skapar en ny miljö med den fullständiga paketlistan. Den gamla sparas som `.venv.backup_*` och återställs om installationen eller verifieringen misslyckas. Egna projekt och mätningar ändras inte. `requirements-tools.txt` och eventuella analys-/rapportfiler hänvisar till samma fullständiga lista.

Verifieringen kontrollerar Pythonversion, paketversioner, extra paket, importernas isolering, kompilerade moduler, PDF-skrivning/läsning och pip check. Camera-41 verifierar även sin befintliga numeriska referens. Resultatet och den installerade paketlistan finns i `local-config/python_environment.json` och `local-config/python-lock.txt`.

Vid paketändringar ska kravfilen, Pythonversionen och installationskontrollen hållas lika i alla aktiva program, följt av respektive programs regressionstester. ArgyllCMS och LibRaw är separata externa/native beroenden och ingår inte i `.venv`.

På Apple Silicon prioriteras ARM-Python framför Intel oberoende av MATLAB/Rosetta. Om Pythoninstallationen är universal görs den lokala miljöns interpreter ARM-specifik. ArgyllCMS väljs i första hand för den fysiska arkitekturen och universalverktyg startas uttryckligen som ARM. På Intel används Intel-versioner.

## Portable macOS preparation (2026-10-26)

Each installation keeps its own pinned Python 3.13.6 and isolated `.venv`. If no compatible base interpreter exists, **Prepare**, `setup_python_environment("sync")` or `"rebuild"` downloads a private interpreter into this installation's `.python/`. Apple Silicon uses ARM; Intel Macs use Intel. The uv 0.9.5 preparation download is SHA-256 verified before execution and removed afterwards. Internet access to PyPI and GitHub is required for first preparation. System Python, global executable links and PATH remain unchanged; no administrator installation is requested.

`identify` and `check` are read-only and never download or install. Existing environments are backed up and restored on a failed rebuild. The standalone interpreter uses linked venv executables on macOS so its libpython remains discoverable. Both `.python/` and `.venv/` are local runtime state, excluded from Git and recreated after moving to another computer. Projects and original measurements are preserved. Automatic interpreter downloads currently support macOS; other platforms require an explicit compatible BootstrapPython.

Implementation reference: https://docs.astral.sh/uv/guides/install-python/ . uv uses Astral python-build-standalone distributions. Python itself stays pinned; newer minor releases are not silently substituted.
