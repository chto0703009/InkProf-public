# Chartinläsning och interaktiv radmätning

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

## Varning: externa utskrifter utan kontrastmarkörer

**Mål som skrivits ut utan kontrastmarkörer mellan patcharna kan ge problem vid radmätning med chartread**, särskilt när intilliggande patchar har snarlika färger. Det kan exempelvis ge fel om för få eller för många patchar. En korrekt importerad patchdefinition garanterar inte att det befintliga arket går att läsa tillförlitligt.

**Rekommenderat arbetsflöde:** importera patchdefinitionerna som TI1/TI2 i första hand, eller generell CGATS från ett annat program, och låt InkProf generera en ny TIFF16-utskrift med kontrastmarkörer och matchande TI2/JSON. Använd sedan just det nya utskriftspaketets TI2 vid mätningen. Kontrastmarkörer minskar risken för segmenteringsproblem men garanterar inte felfria svep.

En import eller omordning i programmet ändrar inte ett redan utskrivet ark. Om det befintliga arket mäts i ett annat program kan dess mätfil importeras separat med bevarad patchkoppling.


Status 2026-09-26: Terminal-flödet och MATLAB-bryggan har läst ett sjuraders kontrastmål med i1Pro 2 och importerat alla 143 källpatchar. Den nya modala dialogen är testad med simulerad process och syntetiska mätdata; grundflödet är också fysiskt provat framåt med i1Pro 2. Parläget med medelvärdesbildning återstår att prova fysiskt. Den interaktiva PTY-bryggan använder POSIX. InkProf är endast testat på macOS; Linux är inte testat och Windows väntar på en separat konsoladapter.

## Mätvariation, medelvärde och hanteringskontroll

Beslutad arbetsprincip 2026-09-29. Vid korrekt kalibrering, placering och avläsning med i1Pro 2 utgår vi tills vidare från att instrumentets brusbidrag är mindre än utskriftens variation. Detta är ett arbetsantagande utifrån användarens erfarenhet, inte ett här fastställt instrumentvärde. Instrumentbidraget behöver därför inte styra den aktuella profiliterationen, men antagandet ska kunna omprövas vid systematiska avvikelser eller bristande repeterbarhet.

**Kontroll ska föregå medelvärdesbildning:**

1. Kontrollera patchidentitet, position, mätvillkor och fullständighet för varje avläsning. Jämför upprepningarnas färgvärden innan ett medelresultat accepteras.
2. Vid stor skillnad: markera för granskning eller ommätning. Ett medelvärde får inte dölja fel placering, fel rad, fel patch eller misslyckat svep. En stor skillnad är en varningssignal, inte ensam bevisning för ett hanteringsfel; även utskriftsvariation kan bidra.
3. För godkända upprepningar med samma mätvillkor och våglängdsgrid används ett lika viktat **medelspektrum**. XYZ och Lab beräknas därefter från medelspektrumet med dokumenterad illuminant och observatör. Medelvärde av Lab eller ΔE00 ersätter inte denna spektrala beräkning.
4. Bevara de enskilda spektra, patchkopplingar, jämförelser, varningar och accepterade/uteslutna avläsningar i JSON, tillsammans med hur medelvärdet bildades. En accepterad ommätning ska inte radera tidigare evidens.

Upprepade mätningar av samma fysiska patch beskriver främst avläsningens repeterbarhet. Separata tryckta patchar med samma RGB innehåller dessutom positions- och utskriftsvariation. Båda är användbara men ska hållas isär i metadata. Samma RGB från olika utskriftstillfällen får inte automatiskt slås ihop utan kontroll av papper, inställningar och eventuell drift.

I den senaste C2-mätningen var medelavståndet mellan tolv par separat tryckta upprepningar **0,37 ΔE00**, maximalt **0,68**. Detta kan användas som observerad variationsnivå för utskrifts- och mätkedjan. Det är **inte** en standardavvikelse, en statistisk konfidensgräns eller en universell tolerans. Värdet ska inte subtraheras från varje färgfel och ersätter inte den konfigurerbara varningsgränsen för upprepningar.

Små skillnader mellan iterationer, exempelvis 0,6 mot 0,7 ΔE00, används som diagnostisk information och ska inte ensamma avgöra profilval när båda resultaten är praktiskt tillräckliga. Prioritera stora, återkommande lokala modellavvikelser. Se även [verifieringsåterkoppling](verification-feedback.md).

Detta avsnitt dokumenterar arbetsprincipen; tillägget ändrar inte mätkoden. Befintlig parmedelvärdesbildning och varningar ska inte tolkas som att automatisk uteslutning av felaktiga avläsningar eller separation av skrivar- och instrumentbrus redan är implementerad.

## Modal mätdialog i MATLAB

Gränssnittsspråk: engelska i mätdialog, resultatkarta, knapptexter och bekräftelser. Argylls originalmeddelanden visas oförändrade. Operativsystemets filväljare och MATLABs egna systemfel följer datorns/MATLABs språk.

```matlab
setupInkProf();
dialog=inkprof.measureChart();
```

Välj målfil (TI2) i fönstret och ange inställningarna innan **Start measurement**. Ingen instrumentprocess startas när fönstret öppnas. En ny sessionsmapp skapas vid start; sparade mätningar skrivs inte över. En känd målfil kan också förväljas:

```matlab
dialog=inkprof.measureChart(fullfile(paths.Projects,'mitt-target','target.ti2'));
```

### Tre mätlägen

Dialogen har exakt tre val under **Scan mode**:

1. **Single direction** (`ScanMode="single"`): en avläsning per rad, vänster till höger. Använder chartread `-B`.
2. **Alternate rows** (`ScanMode="alternating"`, förvalt): rad 1 framåt, rad 2 tillbaka, rad 3 framåt osv. En avläsning per rad. Använder chartread `-b` för riktningsigenkänning. Den visade riktningen är vägledning; sensorrörelsen kontrolleras inte separat.
3. **Forward + reverse average** (`ScanMode="paired"`): samma fysiska rad läses först framåt och sedan tillbaka. Därefter fortsätter nästa fysiska rad. Båda avläsningarna bevaras och medelvärdesbildas patch för patch.

I läge 3 blir sju fysiska rader fjorton logiska chartread-pass. Den ursprungliga `chart.json` och `source.ti2` bevaras. En separat `paired/`-session innehåller det dubblerade underlaget. Returpassets RGB, identitetskoppling och förväntade XYZ ligger i omvänd fysisk ordning; chartread använder `-B` eftersom riktningen redan uttrycks i underlaget. Dialogen visar den fysiska raden och fasen, exempelvis **Page 1 · Row 1 · FORWARD scan (1/2)** och **REVERSE scan (2/2)**. Ingen ny utskrift behövs. Argylls rålogg använder de logiska passnumren.

`paired-plan.json` kopplar varje runtime-position till originalets patchindex, sida, rad och svep. De ursprungliga avläsningarna sparas i `paired/chart.ti3` och separata mät-JSON-filer. Den fysiska riktningen är instruerad, inte oberoende verifierad av en rörelsesensor. Fel rad/riktning kan därför fortfarande kräva omläsning vid chartreads varning.

Efter fullständig mätning skapas `chart-mean.ti3` och en mät-JSON för originalmålet. Varje spektralband medelvärdesbildas med vikterna 0,5 och 0,5. XYZ medelvärdesbildas linjärt under samma mätvillkor; det motsvarar medelvärdet före samma linjära spektralintegration. Lab medelvärdesbildas inte; detta flöde kräver XYZ och spektra. Originaldata och parens index sparas även i `pairedReadings`, tillsammans med spektral RMS-skillnad per patch i ursprungliga TI3-enheter. Stora skillnader visas som numeriska jämförelsedata; ingen universell godkännandegräns antas. Ett ofullständigt par får inte bli ett komplett medelresultat.

Vanlig omläsning ersätter fortfarande det valda logiska passet. Den andra halvan av paret är en separat post och skrivs inte över. Tidigare sparade mätningar och den ursprungliga layouten förblir oförändrade. Parläget är numeriskt och dialogmässigt simuleringsprovat; fysisk verifiering med i1Pro 2 återstår. För närvarande kräver det kompletta TI2-rader i vänster–högerordning, med nummer för rader och bokstäver för kolumner.

Övriga inställningar:

- **Scan tolerance:** skickar `-T`; förvalt 1. Avser konsistens inom patchen.
- **Instrument port:** 0 väljer chartreads standard, ett positivt nummer skickas som `-c`.
- Mätläge, tolerans, port och målfil låses vid start. Mätläge och faktiska chartread-argument sparas.

### Resultatkarta efter sparning

Efter lyckad sparning och import öppnas automatiskt ett separat resultatfönster. Varje ruta visar kolumnbokstav och radnummer, exempelvis A1, B1 eller U7. Sidval finns för flersidiga mål. Klick på en ruta visar dess SAMPLE_LOC, patch-ID, RGB-styrvärden och tillgängliga uppmätta XYZ/Lab- och spektralvärden. Utfyllnad markeras separat; saknade mätningar markeras som saknade.

Rutornas färger kommer från målfilens RGB-värden och är en skärmförhandsvisning, inte en kolorimetrisk rendering av uppmätt XYZ eller ett mått på färgnoggrannheten. Mätvärdena visas separat och behåller TI3-skalan. Kartan är schematisk i rad-/kolumnordning, inte en utskriftsfil med fysiska patchmått och kontrastfält.

Den valda rutans värden visas tydligt ovanför mätdetaljerna: **Measured Lab** när ändliga Lab-värden finns direkt i mätdata, annars **Target RGB (%) — indication only**. RGB är målfilens styrvärden på skalan 0–100, inte uppmätt färg. Ingen dold omräkning av spektrum görs. Spektrum kan integreras till XYZ och Lab utan ICC-profil, men då måste illuminant, standardobservatör och referensvit vara definierade; detta är inte en del av förhandsvisningen.

En sparad mätning kan öppnas igen med `inkprof.previewMeasurement(sessionFolder)`. Då väljs den senaste sparade mät-JSON-filen i sessionen. Om resultatfönstret inte kan visas finns den sparade mätningen ändå kvar; ett visningsfel klassas inte som ett mätfel.

### Mätdialogen

Logg och instrumentfrågor uppdateras automatiskt. Ingen manuell `poll` eller `sendKey` behövs. För en redan förberedd, ny session används `inkprof.MeasurementDialog(sessionFolder)`.

- **Kalibrera:** placera instrumentet på vitreferensen och välj knappen när den blir aktiv.
- **Starta svep:** använd instrumentknappen eller dialogknappen; skicka inte en extra start medan instrumentet arbetar.
- **Läs om / försök igen:** används efter felmeddelande. Invänta ny radprompt innan nästa svep.
- **Föregående rad / Nästa rad / Nästa olästa:** väljer rad, startar inte svepet. För omläsning av en redan läst rad: välj den och svep igen.
- **Godkänn avvikelsen:** aktiveras endast vid varning om oväntat färgsvar och kräver bekräftelse. Omläsning är förstahandsvalet.
- **Spara och avsluta:** aktiveras när chartread rapporterar att alla rader är lästa. Import sker först efter lyckat processavslut och kontroll av att definitionen är oförändrad. Resultatet finns i `dialog.Result` och som mät-JSON i `dialog.Folder`.
- **Öppna resultatmapp:** visar mätfilerna i datorns filhanterare.
- **Stäng / avbryt:** begär bekräftelse om mätningen pågår; osparade avläsningar kan då gå förlorade. Fönstrets stängknapp har samma beteende.

Dialogen är begränsad till nya sessioner och fullständig sparning. Återupptagning/delmätning finns kvar i Terminal-flödet. Okända eller ofullständiga instrumentfrågor visas i loggen utan automatiska tangenttryckningar. En komplett import bekräftar patchtäckning, inte färgnoggrannhet. Det modala flödet har provats fysiskt med i1Pro 2 framåt; parläget med medelvärdesbildning återstår att prova med instrumentet.

## JSON är intern modell

InkProf använder **JSON internt**. TI2 och TI3 är adaptrar för kommunikationen med ArgyllCMS, inte den interna projektmodellen:

```text
Godkänd TI2 från utskriftspaketet → chart.json
chart.json → temporärt/återskapat chart.ti2 → chartread
chartread → chart.ti3 → validerad measurement-*.json
```

`prepareChart` är första importadaptern till mätsteget. Den accepterar CTI2 med RGB-värden, unika patchpositioner och konsekventa rad-/sidantal. PXF, TI1 och RGB-CGATS ska först användas till att skapa ett TIFF/TI2-paket. En patchlista ensam anger inte den fysiska karta som ska mätas. ”Godkänd” betyder här validerad filstruktur och patchkoppling, inte att papper eller instrument har verifierats.

## Förbered en session

```matlab
paths=setupInkProf();
sessionFolder=fullfile(paths.Projects,'matning-001');
chart=inkprof.prepareChart( ...
    fullfile(paths.Projects,'mitt-target.ti2'),sessionFolder);
```

För ett generellt `createTarget`-paket ligger underlaget i paketmappens `target.ti2`. För `createTiff16` har TI2 samma basnamn som första TIFF-filen. Välj alltid underlaget från den faktiska utskriften.

Sessionen innehåller `chart.json` och en oförändrad `source.ti2` som proveniens. Den importerade filen behövs inte på sin gamla plats. JSON innehåller patch-ID, SAMPLE_LOC, RGB i procent, utfyllnadsmarkering, rad-/sidparametrar och ursprungliga hjälptabeller/metadata. Dessa bevarar exempelvis kalibreringsdata. Rektanglar i millimeter kan inte härledas generellt från TI2 och påstås därför inte finnas i denna adapter.

Separat utbyte kan göras med `inkprof.exportChartTi2(chartJson,outputPath)`. Inga befintliga utdata skrivs över.

## Rekommenderat: mät i ett separat terminalfönster

Uppdaterat 2026-09-26: Python äger nu hela den interaktiva mätsessionen. MATLAB öppnar ett terminalfönster på macOS; chartread får terminalens in-/utmatning direkt. Inga `poll()` eller `sendKey()` behövs i detta flöde. Kalibreringsbesked, mätresultat och varningar visas automatiskt. Return och andra tangenter skrivs i **terminalfönstret**, inte i MATLAB.

Stoppa först en eventuell äldre `ChartReadSession` med `s.stop()` och kontrollera att den avslutats. Bara en instrumentprocess ska köras.

```matlab
run=inkprof.startMeasurement(sessionFolder);
```

Kalibrera och mät enligt chartreads dialog. Vid radprompten används instrumentets knapp för mätning. Skicka inte också en extra tangent som startar nästa mätning.

### Ommätning av en rad

Chartread har redan detta stöd. Vid radprompten: använd `b` för föregående rad och `f` för nästa rad tills rätt radnummer visas, och läs den raden igen. `n` väljer nästa olästa rad. Tangenternas betydelse är beroende av den aktuella dialogen: vid en varning kan Return godkänna en misstänkt mätning. Följ därför alltid texten som visas.

För att avsluta med sparning väljer du `d` vid radprompten och följer eventuella följdfrågor. Spara även en delvis uppmätt karta innan du avslutar om du vill fortsätta senare. `q`/Esc eller att stänga terminalen kan förlora osparade avläsningar.

Efter att Python rapporterat `saved_unvalidated`, gå tillbaka till MATLAB:

```matlab
result=inkprof.finishMeasurement(run);
disp(result.complete);
```

MATLAB kontrollerar chart- och resultathash, kopplar patchar och sparar mätdata i intern JSON. `complete=false` betyder att alla källpatchar ännu inte finns. Ett framgångsrikt processavslut innebär inte i sig en fullständig eller kvalitetsgodkänd mätning.

För att fortsätta en sparad session eller mäta om rader i en färdig karta:

```matlab
run=inkprof.startMeasurement(sessionFolder,Resume=true);
% Mät och spara i terminalen.
result=inkprof.finishMeasurement(run);
```

Resume skickar `-r` till chartread och kräver samma chart-JSON som tidigare. Föregående TI3 kopieras till `before-<runId>.ti3` innan chartread startas. Ett ändrat resultat kopieras till `result-<runId>.ti3`. MATLAB importerar den körningens snapshot, inte en eventuell gammal TI3. Inom en pågående chartread-körning ersätter en radomläsning radens värden; mellanliggande avläsningar som aldrig sparats kan inte återställas av InkProf. Full revisionshantering med användarval är fortfarande en senare funktion.

Varje körning har `terminal-run-<runId>.json` med status, argument, version, hash och resultatväg. Tillstånden är `ready`, `running`, `saved_unvalidated`, `no_new_result`, `failed` eller `interrupted`. Oförändrad TI3 vid Resume räknas inte som ett nytt mätresultat. Om terminalen avbryts hårt kan status bli kvar som `running`; ingen automatisk import sker då.

För stabil, direkt terminalkontakt fångar denna version **inte rå dialogtext till en separat transkriptfil**. Dialogen finns i terminalfönstret; körningsmetadata och TI3-snapshots sparas. Äldre bryggans transkript gäller bara den äldre vägen.

På Linux: använd `OpenTerminal=false` och kör den returnerade `.command`-filen från en egen terminal. Automatisk terminalöppning är implementerad för macOS; Windows återstår. Lokala sökvägar i startfilen genereras på aktuell dator och ska inte versionshanteras som portabla inställningar.

```matlab
run=inkprof.startMeasurement(sessionFolder,OpenTerminal=false);
disp(run.launcher);
```

Python-test har verifierat terminalanslutning, numerisk TI2, sparning, Resume, tidigare resultat, ändrat chart och avvisning av körning utan terminal med en simulerad process. MATLAB-test täcker startförberedelse, resultatimport och manipulerad resultathash. Det är inte fysisk kvalificering av den nya mätvägen. Radigenkänningsproblemen för den utskrivna 575-kartan återstår att undersöka med riktig chartread.

## Äldre gränssnitt: ChartReadSession (felsökning)

Skapa den lokala Python-miljön enligt [Python-anvisningen](python-runtime.md). Ingen extern Python-modul behövs. Stäng andra program som använder spektrometern innan start.

```matlab
s=inkprof.ChartReadSession(sessionFolder);
events=s.poll(10);
```

`poll(10)` väntar upp till tio sekunder på nästa händelse. `poll()` läser direkt tillgängliga JSON-händelser och visar Argylls råa dialogtext. Anropa den löpande för att se kalibrerings- och mätningsinstruktioner. MATLAB-kommandoprompten förblir tillgänglig medan processen körs. Denna första version har ännu inget grafiskt mätfönster och tolkar inte fri konsoltext som garanterade tillstånd.

Svara endast enligt den aktuella chartread-dialogen:

```matlab
s.sendKey(char(13));  % Return när dialogen efterfrågar det
s.poll();
% s.sendKey('d');     % endast när chartread erbjuder avslut med sparning
```

Spektral sparning är chartreads standard; bryggan skickar inte `-n`. Den skickar inte heller automatiska kalibreringssvar eller kommandon som godkänner varningar. Instrumentport kan väljas med `Port=1` osv. om Argylls aktuella instrumentlista kräver det; listan och instrumentanslutningen måste kontrolleras lokalt. Specifik filter-/mätvillkorskonfiguration är ännu inte införd i API:t.

`stop()` avbryter processen och kan förlora osparade avläsningar. Att rensa sessionsobjektet stänger kontrollkanalen och avslutar barnprocessen. Ett avslut eller en befintlig TI3 rapporteras **inte** som en validerad, komplett mätning.

## Resultat och återupptagning

När chartread avslutats och sparat TI3:

```matlab
result=inkprof.importChartMeasurement(sessionFolder);
disp(result.complete);
```

Importen kontrollerar CTI3, RGB, patchidentiteter och styrvärden mot JSON. Den sparar en ny JSON-snapshot och en kopia av TI3 utan att skriva över föregående resultat. `complete` avser täckning av källpatcharna. Ofullständiga resultat sparas med `complete=false`. Anonyma paddingrader med ID 0 räknas inte som källpatchar. Spektra och metadata bevaras; inga saknade spektra eller mätvillkor hittas på och ingen spektral skala normaliseras automatiskt.

```matlab
s=inkprof.ChartReadSession(sessionFolder,Resume=true);
```

Resume kräver tidigare TI3 och samma JSON-checksumma som föregående körning. Den tidigare TI3-filen säkerhetskopieras före körning. En sessionslåsning hindrar två bryggor från att använda samma session samtidigt. Använd bara en aktiv instrumentanslutning även när olika sessioner finns.

Varje körning sparar argument, verktygets versionsutskrift, rå dialoglogg och en checksumma som kopplar den genererade TI2-filen till intern JSON. Utan uttryckligt Resume avvisas start om TI3 redan finns.

## Verifiering och begränsningar

- MATLAB-test: JSON-import, TI2-återexport med både MATLAB- och Python-adapter, partiell/fullständig syntetisk TI3, fel RGB och styrning av en simulerad barnprocess.
- Python-test: PTY-dialog, enskilda tangentkommandon, avslut och skydd mot att skriva över befintlig TI3.
- Praktiskt grundprov med i1Pro 2 har genomförts: kalibrering och sju rader med 143 källpatchar, XYZ och spektra, via Terminal och MATLAB-bryggan/dialogen. Kopplingen till TI2 har kontrollerats. Det nya läget med två svep och medelvärde, samt robusthet vid radomläsning, kabelavbrott och återupptagning, kräver fortsatt fysisk verifiering.
- Använd inte syntetiska testresultat som instrumentmätningar.

Källor: [chartread](https://www.argyllcms.com/doc/chartread.html), [TI3](https://www.argyllcms.com/doc/ti3_format.html). Lokal hjälp verifierad för ArgyllCMS 3.5.0.

## Egen punktomläsning och självständighet

InkProf har inget körberoende till SpectraLab eller Camera-41. Separat punktomläsning är implementerad med Argyll `spotread`, stabil patchkoppling, bevarade original och accepterade sparade revisioner. Granska och spara kandidaten; att mäta en gång till ersätter inte automatiskt den använda revisionen. Chartreads radomläsning och återupptagning är ett annat flöde och kräver fysisk verifiering. Se [beslut 007](../decisions/007-independent-inkprof.md).

## Rättning efter första startprov, 2026-09-26

Python-adaptern satte felaktigt citattecken runt numeriska TI2-data. Argyll avvisade då RGB_R som text. Adaptern skriver nu numeriska data utan citattecken och bevarar citattecken för identiteter. Det verkliga 575-chartet har därefter passerat Argyll 3.5.0:s inläsning i externt XYZ-inmatningsläge, utan instrumentmätning. Start och avslut visas nu av MATLAB-kontrollen. Ursprungliga PXF/TIFF/TI2/layout-filer har inte ändrats.

## Tolerans och läsriktning

`startMeasurement(...,ScanTolerance=1.5,Direction="forward")` skickar `-T 1.5 -B`. Standard är tolerans 1 och `Direction="auto"`. `Direction="both"` skickar `-b` och aktiverar tvåvägsigenkänning även för icke-randomiserade kartor. `forward` kräver framåtriktning i targetets patchordning. Auto följer Argylls val, vilket normalt stänger av tvåvägsigenkänning för icke-randomiserade target. Igenkänningen använder förväntade färgvärden och kan välja fel riktning om dessa är olämpliga.

Toleransvärdet skalar kontrollen av variation inom en patch; det är inte en direkt inställning av patchgränsens känslighet. Testa en parameter åt gången, utan att undertrycka varningar. Argument och inställningar sparas i körningsmanifestet.

Ett separat underlag för den befintliga 575-utskriftens rader 13-17 har skapats i `projects/test-575-rad13-17-T1p5`. Det innehåller 145 positioner, varav 143 källpatchar och två utfyllnader. Ordning, värden och radnamn bevaras; radintervallet i TI2-indexmönstret och antalet rader ändras till delmängden. Originalutskrift och tidigare mätning ändras inte. Ingen ny utskrift behövs. Första provet använder `ScanTolerance=1.5,Direction="forward"`. Fysisk förbättring är ännu inte verifierad.

## Mätvillkor: M0, M1 och M2

Se även [optiska vitmedel, OBA/FWA och OBC](optical-brighteners.md) för skillnaden mellan mätvillkor, D50-beräkning och fluorescenskompensation.

Dialogen skiljer på läsriktning och mätvillkor. För det nuvarande i1Pro 2-flödet är valet **M0 – i1Pro 2 without UV filter** förvalt. Alternativet **Instrument default – unspecified** lämnar M-villkoret ospecificerat. M1/M2 visas som en begränsning, inte som tillgängliga direkta mätlägen.

Argylls dokumentation anger att i1Pro 2:s UV-mätläge inte stöds. FWA-kompensation kan användas för beräkning under andra villkor, men det är ett separat bearbetningssteg och får inte märkas som en direkt M1/M2-avläsning. Generella `chartread -F`-alternativ bevisar inte att ett visst instrument stöder dem. InkProf skickar därför inget `-F`-kommando i detta i1Pro 2-flöde och gör ingen FWA-beräkning.

Inställningarna sparas i `measurement-settings.json` med mätdefinitionens hash, önskat villkor, läsriktning, tolerans och port. Varje ny importerad mät-JSON innehåller `measurementCondition`, där önskat (`requested`), filrapporterat (`reported`) och tolkat (`interpreted`) villkor hålls åtskilda. M0 kan tolkas från kombinationen i1Pro 2 i TI3 och en entydig körlogg som rapporterar inget UV-filter. Det redovisas då uttryckligen som en slutsats från instrument/drivrutin, inte som en M0-etikett i original-TI3. Om underlaget saknas lämnas villkoret okänt. Äldre sparade resultat skrivs inte om automatiskt.

Villkorsinformationen visas också när en ruta väljs i resultatkartan. Skärmfärgerna är fortfarande mål-RGB; valet av M-villkor ändrar inte skärmförhandsvisningen.

Källor: [Argyll: i1Pro 2 och instrumentbegränsningar](https://www.argyllcms.com/doc/instruments.html), [chartread: filterval](https://www.argyllcms.com/doc/chartread.html), [TI3: INSTRUMENT_FILTER](https://www.argyllcms.com/doc/ti3_format.html). Kontrollerat mot installerad ArgyllCMS 3.5.0-dokumentation och officiell webbplats 2026-09-26.


## Retry a failed calibration (2026-09-27)

If calibration fails, the calibration button becomes **Retry calibration**. Place the instrument on its own white reference and select that button. Repeated failures can be retried in the same session. Row navigation stays disabled until calibration succeeds and chartread presents a row prompt. During calibration the controls are disabled to avoid duplicate keypresses. This change handles chartread calibration failures; it does not add forced recalibration while chartread is waiting for a strip scan.

## Printed page changes (2026-09-27)

The current printed page and row appear in the measurement status. At a page transition, the dialog shows **Change to page X of Y**, the next printed row and its position on that page. Place that sheet in the guide and select **Page loaded**. This acknowledgement sends no key to chartread; press and hold the button on the i1 Pro 2 to scan afterwards. Navigation back across pages also requests the appropriate sheet. Forward/reverse paired passes use the physical page in the paired plan.

Page boundaries come from the imported TI2 `PASSES_IN_STRIPS2`, not from a fixed number of rows. For the 575-patch print with 21 + 7 rows, page 2 begins at printed row 22. Page 1 is assumed loaded initially. The software confirmation gates the dialog controls only: chartread still listens to the instrument hardware button, so do not trigger that button before changing the sheet. No page-change confirmation is required after all rows have been read.

## Paired rereads and warning after saving

In mode 3 the navigation buttons are **Previous scan**, **Next scan** and **Next unread scan**. They move between logical sweeps: row 1 forward, row 1 reverse, row 2 forward, row 2 reverse, and so on. Navigation alone changes no readings. Scanning a selected pass replaces only that pass. On saving, the latest forward and reverse readings for each physical patch receive equal weight; an additional reread is not a third sample in the mean.

After saving, the result window identifies physical rows where any patch differs by more than `PairedWarningDeltaE` (default **1.0 CIEDE2000**) between directions. This configurable threshold concerns repeatability, not the TI2 estimate comparison. Set it through `inkprof.measureChart(..., ScanMode="paired", PairedWarningDeltaE=1)`. Raw readings and diagnostic results remain in the saved measurement JSON. The comparison uses stored XYZ with D50/2. If the optional analysis packages are unavailable, the result explicitly warns that the comparison could not be computed; it never reports that as a passing check. Existing saved measurements are not rewritten.

## Remeasure one patch (i1 Pro 2, M0)

After saving, click a patch in the colour chart, then **Remeasure patch**.
Alternatively, open a saved measurement directly:

```matlab
fig = inkprof.remeasurePatch(measurementFile, "Q1");
```

`measurementFile` is a saved `measurement-*.json`, not a TI2 file. The dialog
uses English labels. Close other instrument sessions first and keep the same
print, backing and instrument. Press **Start spot measurement**, put the
instrument on its own white reference, and press **Calibrate**. A failed
calibration can be retried. Then place it stationary at the centre of the named
patch and click **Measure patch in the dialog window**. Keep the instrument
still until the result appears. Do not swipe or press the instrument button
in this workflow; the dialog sends the measurement trigger.

InkProf shows previous and new D50/2 Lab and their CIEDE2000 difference. This
checks change from the previous measurement, not profile accuracy. **Accept
replacement** creates a new complete measurement JSON and TI3 containing the
replacement. **Discard / Close** leaves the original measurement unchanged.
To take another candidate, close this attempt and reopen the patch dialog.

The selected physical coordinate is supplied by the operator: a spectrometer
cannot identify which printed patch it is placed on. The first implementation
requires i1 Pro 2 native unfiltered reflectance, interpreted as M0, without FWA.
Other conditions are rejected. It explicitly uses D50, the 1931 2-degree
observer and the original XRGA/XRDI/GMDI conversion standard. Wavelengths must
match exactly; no resampling is performed. Where the original instrument
serial can be recovered from its hash-verified transcript, a different serial
is rejected. Otherwise using the same instrument remains the operator's check.

Each attempt has its own `spot-rereads/<timestamp-uuid>/` directory containing
`request.json`, `run.json`, `transcript.txt` and, after a valid reading,
`candidate.json` and `comparison.json`. `decision.json` records acceptance or
discard. The project manifest is updated at preparation, review and decision.
Accepted revisions retain parent and candidate hashes, patch identity and old
values in `patchOverrides`. Parent measurements and raw forward/reverse scans
remain unchanged. The spot value replaces the final value; it is **not** a
third sample in the two-sweep average. Existing forward/reverse warnings are
historical evidence, explicitly labelled as such after replacements.

The implementation is independent of SpectraLab at runtime. The calibration/
reading workflow and strict spectral-block interpretation were adapted from
SpectraLab v1.2.1-dev `tools/spotread_manual_measure.py` and
`spectralab/+spectralab/+drivers/+spotread/Parser.m` (GPLv3). InkProf uses its own
PTY bridge and reflection settings, not SpectraLab's emissive configuration.
Argyll's [spotread documentation](https://www.argyllcms.com/doc/spotread.html)
defines the command-line interface. The transport uses POSIX features. InkProf has been tested on macOS only; Linux and Windows remain untested.

Automated tests use a fake instrument, including failed calibration, retry,
complete spectrum parsing, modal review and discard, immutable replacement,
wrong wavelengths and unchanged neighbouring patches. Physical spot
measurement still needs a user-run check with the actual instrument.

### Find patches with the largest repeatability differences

The saved-measurement window lists all available forward/reverse patch
comparisons, largest dE00 first, with physical coordinate, page and tolerance
status. The largest difference is selected initially. Clicking a table row
opens the correct page, highlights that patch and enables **Remeasure patch**.
Patches within tolerance remain selectable and can also be remeasured.
The values compare the two original sweeps, not the print against a profile.
Accepted spot replacements are marked **Spot replaced (old scans)**: the old
scan difference is retained as history rather than presented as a new spot
repeatability measurement. If paired comparisons are unavailable, the window
says so; it does not infer differences from nominal target RGB.

After a complete spot result, the bridge closes Argyll automatically. Some
instrument/Argyll combinations first report `Spot read stopped at user request!`
and ask `Hit Esc or Q to give up, any other key to retry:`. InkProf answers this
exit confirmation with a second quit; it must not initiate another reading.
The raw transcript remains available even if process shutdown fails. A timeout
alone therefore does not establish that no physical reading took place.

Before accepting a spot reading, the dialog replaces the transport log with a
six-row table showing previous and new L*, a*, b*, X, Y and Z. The change in
dE00 is prominent and is also included in the Accept button label. The saved
chart distinguishes **Scan dE00** (the original forward/reverse discrepancy)
from **Spot change** (accepted replacement versus previous final value).
Selecting a replaced patch shows its accepted spot Lab. Swatch colours still
represent the target RGB, so they do not change when measurement values change.

The deviation table uses fixed column widths, compact headings and values
rounded to three decimal places for display; stored values retain full
precision. The selected patch uses a red border when it contrasts with the
nominal displayed RGB, otherwise cyan or black/white. An additional inset
black/white outline provides contrast on the patch itself. This is a display
visibility heuristic, not a colourimetric assessment of the printed patch.

## Randomiserade mål och dubbelriktad medelvärdesmätning

Rättat 2026-09-28: TI2 kan lagra poster i SAMPLE_ID-ordning trots att utskriften är randomiserad. Paired-läget sorterar därför sin genomgång på SAMPLE_LOC (numerisk rad och bokstavskolumn), och behåller en explicit mappning till originalets JSON-index. Original-TI2, patch-ID och mätkoppling ändras inte. Tidigare kunde Start measurement stoppas av detta antagande före instrumentstart. Startfel visas nu också i en felruta, loggen och MATLABs kommandofönster.

Verifierat med syntetiska fram-/bakåtmätningar och medelvärden för både randomiserat och orandomiserat mål samt det faktiska C2-målets sju rader/fjorton pass. Ingen instrumentmätning ingick i regressionstesten.


### Starting a strip scan

**Start measurement** connects the instrument and begins the session. **Calibrate** responds to the white-reference prompt. There is no **Start scan** button: at the row prompt, press and hold the i1 Pro 2 instrument button and scan the displayed row, starting and finishing on white paper. Follow the displayed direction. **Reread / retry** clears an error prompt; wait for the row prompt and then use the instrument button again. **Page loaded** only acknowledges a sheet change and never sends a scan trigger.

InkProf-generated charts retain contrast markers as standard. External prints without markers can be harder for chartread to segment; this is not a universal prohibition on measuring charts without markers. If measured in another application, preserve the original MXF under the project's `sources` directory with a unique name. `inkprof.importMeasurement` creates a separate measurement session, preserving the imported source and mapping.


### Radnummer vid slumpad patchordning

Dialogens radnummer härleds från TI2-filens fysiska patchkoordinater i radordning, inte från posternas ordning i filen. Detta gäller enkelriktning och alternativ 2 (växelvis riktning), även vid Previous/Next och sidbyte. Alternativ 3 använder sin separata koppling mellan svep och fysisk rad. Ett visningsfel för slumpade TI2-filer rättades 2026-09-28; chartread kunde stå på rad 2 medan dialogen visade rad 1. Varnade läsningar från en sådan session ska inte accepteras som rätt rad.


### Hardware scan after page change (2026-09-29)

After changing the sheet, either select **Page loaded** or scan the indicated row
with the instrument button. A new **Strip read OK** also acknowledges the page
of that completed pass. The next prompt shows the current printed page, row and
direction; in paired mode, the first accepted forward scan on page 2 therefore
shows the reverse scan on the same row. Failed scans and Previous/Next navigation
do not acknowledge a page change. Historical successful scans are consumed only
once, so they cannot override a later manual page confirmation. The dialog cannot
verify which physical sheet is in the guide; the operator must still change it.

### Activity during patch remeasurement

Remeasure patch shows progress while preparing the attempt, connecting the spectrometer, calculating the comparison, saving the accepted revision and rebuilding the overview. Calibration and measurement show elapsed time in the status area. Progress closes before a user decision is required. The existing overview remains available until its replacement is ready, and repeated actions are blocked while processing. Closing records the decision and releases the instrument with visible progress.
