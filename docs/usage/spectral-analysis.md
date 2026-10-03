# Spektral analys med Python

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Implementerad 2026-09-26. MATLAB Base anropar en separat Python-process. Instrumentet används inte vid analysen.

## Installation per dator

Använd InkProfs befintliga konfigurerade Python eller projektets `.venv`. Analysens låsta paketuppsättning är provad med Python 3.13.6 på macOS Apple Silicon. Välj Python 3.11–3.13 för denna uppsättning; övriga operativsystem/versioner är inte kvalificerade genom detta test.

Från projektmappen, för den lokala miljön på macOS/Linux:

```bash
.venv/bin/python -m pip install -r requirements-analysis.txt
.venv/bin/python -m pip check
```

På Windows används `.venv\Scripts\python.exe`. Installation görs i den miljö som MATLAB faktiskt väljer. Vid behov anges `PythonExecutable` direkt till anropet. Se [Python per dator](python-runtime.md). Inga nya paket behövs för att enbart använda den befintliga chartread-bryggan.

## Kör från MATLAB

```matlab
paths=setupInkProf();
[file,folder]=uigetfile('*.json','Select measurement JSON',paths.Projects);
if ~isequal(file,0)
    result=inkprof.analyzeMeasurement(fullfile(folder,file), ...
        SpectralScale=100, Illuminant="D50", Observer="1931_2");
end
```

Välj en sparad `measurement-....json` av typen `inkprof.chart-measurement`, inte chart.json, target.json eller själva TI3-filen. TI3 importeras först med befintlig `inkprof.importChartMeasurement`. Direkt MXF-import är inte tillagd av denna funktion; formatadaptern måste först leverera den kanoniska mätstrukturen.

`SpectralScale` krävs uttryckligen. Värdet 100 betyder reflektans i procent; 1 betyder reflektans som bråktal. Skalan gissas inte från datans maximum. Välj den efter källformatets dokumentation och mätningens metadata. Funktionen är för reflektans, inte emissionsspektra.

Resultatet skrivs till en ny tidsmärkt JSON bredvid originalet. `OutputPath` kan ange annat namn i en befintlig mapp. Befintliga filer skrivs aldrig över. Originalets spektra, XYZ och Lab ändras inte.

```matlab
result=inkprof.analyzeMeasurement(measurementFile, ...
    SpectralScale=100, OutputPath=fullfile(outputFolder,'analysis-D50.json'));
xyz=result.data.xyz100;
lab=result.data.lab;
```

De härledda koordinaterna är inte en ICC-profil eller en konvertering till skrivarens RGB. Enhets-RGB behålls som styrvärden och tolkas inte som sRGB.

## Jämföra två analyser

```matlab
result=inkprof.analyzeMeasurement(secondMeasurementFile, ...
    SpectralScale=100, ReferenceAnalysis=firstAnalysisFile);
disp(result.comparison.mean);
disp(result.comparison.max);
```

Referensen är en tidigare analys-JSON. Matchningen använder patch-ID och fysisk plats, inte radordning. Samma patchuppsättning och RGB-värden krävs. Illuminant, observatör, våglängdsunderlag, vitpunkt och beräkningsmetod ska vara identiska. Mätvillkoret måste vara känt och överensstämma: M0, M1 eller M2. Okänt villkor hindrar jämförelsen men inte själva spektrumberäkningen. Rapporten bevarar om villkoret ursprungligen rapporterades eller tolkades.

Resultatet innehåller ΔE00 per patch samt medel, median, 95-percentil och maximum. Statistiken omfattar samtliga tillförda uppmätta rader, även eventuella kontroll- eller layoutfält. Detta är en jämförelse mellan mätningar, inte automatiskt ett prov på profilnoggrannhet. Anpassning av profiler och separat kontrollutskrift återstår.

## Beräkningskonvention

- Illuminanter: D50 (förval), D65 och A. Observatörer: CIE 1931 2° och CIE 1964 10°.
- Linjär interpolation till ett integrationsnät med högst 1 nm mellan punkter; ursprungliga mätvåglängder ingår. Trapezoidintegration på enbart uppmätt intervall.
- Ingen extrapolation av reflektans. Avkortat intervall varnas för och dokumenteras. Detta är inte ASTM E308 eller ett löfte om exakt samma siffror som Argylls metod.
- Gemensam normalisering så att perfekt diffus reflektor får Y=100. Ingen normalisering av enskilda patchars ljushet.
- Lab beräknas med den valda belysningens vitpunkt på samma intervall. Ingen kromatisk adaptation.
- Negativa eller icke-ändliga reflektansvärden avvisas. Reflektans över 1 bevaras med varning, eftersom bland annat fluorescens kan ge sådana värden. Inga värden klipps.
- Ingen kompensation för optiska vitmedel. Mätvillkor och beräkningsbelysning är olika saker; D50 betyder inte att mätningen gjordes i M1.

## JSON och spårbarhet

Jobbet har `schemaVersion=1`, `measurementPath`, `outputPath`, `spectralScale`, `illuminant`, `observer` och valfri `referenceAnalysisPath`. Python-CLI:

```bash
.venv/bin/python analysis/spectral_analysis.py analysis-job.json
```

Resultatets `documentType` är `inkprof.spectral-analysis` och `schemaVersion=1`. Det innehåller källsökväg och SHA256, ursprunglig chart-/TI3-hash när de finns, mätvillkor, targetInfo när den finns, programversioner, beräkningskonvention, vitpunkt och härledda data. Råspektrum ligger kvar i den oförändrade mätfilen som refereras med hash; analysfilen ersätter inte råmätfilen. För transport eller arkivering ska båda behållas.

Analysen publiceras som en fullständigt skriven ny fil. Fel ger processkod 2 och ett felmeddelande, som MATLAB visar via sin befintliga processhantering. Körningen väljer inte automatiskt en annan Pythoninstallation.

## Verifiering

Pythonproven omfattar fysisk vit/grå/svart, D50-vitpunkt, skalekvivalens, sex publicerade CIEDE2000-referenspar från Sharma/Wu/Dalal (2005), identitetsmatchning, oförenliga jämförelser, felaktiga spektra, enstaka patch, alternativa illuminanter/observatörer och skydd mot överskrivning. MATLAB-proven verifierar hela processanropet, sparning, referensjämförelse och oförändrad källfil.

```bash
.venv/bin/python -m unittest discover -s tests -p test_spectral_analysis.py -v
```

För MATLAB-processproven sätts `INKPROF_TEST_PYTHON` till den aktuella miljön och `tests/testSpectralAnalysis.m` körs. Ett separat prov på en historisk 143-patchmätning lyckades; resultatet ligger i lokalt `work/spectral-analysis-acceptance/`. Dess mätvillkor saknas i ursprunglig JSON och har därför lämnats okänt. Ingen fysisk mätning har gjorts i denna implementation.

Verifierad körning: 10 Python-analystester, 5 MATLAB-tester (analys och Python-anrop), 3 terminalmätningstester och 3 chartread-bryggtester passerade. Paketkontrollen `pip check` passerade. Dessa är utvalda tester, inte en körning av hela projektets testsamling.

## Återanvändbar PDF-rapport

Installera rapportberoenden i vald Pythonmiljö med `python -m pip install -r requirements-report.txt`.

```matlab
pdfFile=inkprof.exportMeasurementReport(measurementFile,analysisFile, ...
    fullfile(outputFolder,'measurement-report.pdf'));
```

Rapporten innehåller alla tillförda patchar med ID, koordinat (A4-format), utskriftssida, beräknade XYZ/Lab, ursprungliga XYZ, beräkningsskillnad dE00 samt en färgruta per patch. Mätning och analys matchas med SHA256 och patchidentiteter. Befintlig PDF ersätts inte. Körningen kräver chart.json bredvid mätfilen och använder ursprunglig layout.json när den är tillgänglig, annars TI2-sessionens sid-/radindelning. Kontrollmål med omnumrerade rader behöver tolkas enligt sin separata kontrollmappning.

Första versionen kräver sparade XYZ och analys D50/1931_2, numrerade rader och bokstavskolumner. Den är avsedd för InkProfs vanliga radlayouter. Beräkningsskillnaden är inte profilnoggrannhet. Spektraltabeller ingår inte i PDF:en; spektra bevaras i mätfilen. Färgrutorna beräknas från analysens XYZ och vitpunkt, adapteras med Bradford till sRGB/D65 och klipps till sRGB-intervallet. De är ungefärliga förhandsvisningar, inte skrivarens RGB-styrvärden eller färgreferenser. Rapporten skapas i Python med ReportLab och medföljande portabla Vera-teckensnitt; inga macOS-specifika typsnitt krävs.

### Grovkontroll mot TI2

`exportMeasurementReport(..., TargetWarningDeltaE=20)` lägger till kolumnen **dE TI2**. Värden över gränsen får `!` och röd understrykning. Förvalet 20 är en ändringsbar praktisk uppmärksamhetsgräns, inte en standard eller tolerans för profilnoggrannhet. Antal varningar visas på rapportsidan. Kolumnen **dE ber.** behåller den separata jämförelsen mellan Python- och Argyll-beräkning.

TI2-estimaten hämtas ur chart.json och matchas med ID, position och RGB. XYZ antas följa TI2-skalan 100. `APPROX_WHITE_POINT` behandlas uttryckligen som uppskattningarnas referensvit och adapteras med Bradford till D50 före ΔE00. Detta är ett diagnostiskt antagande, inte en certifierad referens. Saknas XYZ eller entydig referensvit visas kontrollen som otillgänglig; RGB konverteras inte godtyckligt till Lab.

En separat `.target-check.json` bredvid rapporten sparar gräns, antaganden, identiteter, ΔE00 och flaggor. Inga mätvärden raderas eller ersätts. Stora skillnader kan bero på fel rad, fel layout eller på att TI2:s uppskattningar inte beskriver skrivarens färgåtergivning.
