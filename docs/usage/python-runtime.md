# Lokal och valfri Python-miljö

Python behövs inte för targetgenerering i MATLAB. Python används av den implementerade chartread-bryggan, spektralanalysen, profileringen och rapporterna.

## Skapa miljön på varje dator

Utgå från InkProfs rotmapp. På macOS/Linux:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-report.txt
```

På Windows:

```powershell
py -3 -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements-report.txt
```

Den Python som används för att skapa miljön måste vara 3.11–3.13 för hela analys- och rapportflödet. Välj vid behov den installerade Python-filens fullständiga sökväg. Kopiera aldrig `.venv` eller `local-config` mellan datorer. Båda är ignorerade av Git. `requirements-report.txt` inkluderar analys- och rapportberoenden med versionskrav. Granskade beroendeversioner och licenser dokumenteras i `licenses/inventory.json`.

## Upptäckt och kontroll

`setupInkProf()` hittar `.venv/bin/python` eller `.venv/Scripts/python.exe` relativt projektroten. Den kör inte Python om det inte uttryckligen begärs och fungerar även utan Python.

```matlab
paths=setupInkProf();
disp(paths.PythonExecutable);
inkprof.checkPython();
```

En alternativ installation kan väljas och sparas lokalt:

```matlab
paths=setupInkProf(PythonExecutable="/full/sokvag/till/python");
% Windows exempel: PythonExecutable="C:\Tools\Python\python.exe"
```

Explicit val kontrolleras innan det sparas. Prioriteten är explicit argument, lokal inställning, därefter projektets `.venv`. Ingen automatisk reservväg via PATH används vid körning. En ogiltig lokal inställning ger ett tydligt fel när Python behövs; byt den med ett nytt explicit val. Relativa konfigurationssökvägar tolkas från projektroten.

För att återgå till projektmiljön kan man ange `PythonExecutable=".venv/bin/python"` (Windows: `.venv\Scripts\python.exe`). Automatisk upptäckt sparar inte en absolut `.venv`-sökväg. `setupInkProf(CheckPython=true)` kontrollerar den aktuella miljön utan att kräva någon terminalaktivering.

## Anropa bryggkod

```matlab
result=inkprof.runPython("bridge/script.py",["--input","fil med blanksteg.json"], ...
    RequiredModules=["json"]);
```

Anropet använder en fullständig executable-sökväg och separata processargument utan skal. Kontrollen verifierar Python-version och de moduler den aktuella bryggfunktionen kräver. Den laddar inte Python i MATLAB via `pyenv`. Sökvägar med blanksteg fungerar och terminalens aktivering av en annan miljö påverkar inte valet. Körningen har timeout och rapporterar fel från processen.
