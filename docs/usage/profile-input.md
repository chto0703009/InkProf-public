# B1 – välj och lås profileringsunderlag

**MXF-import:** kompletta mätvärden betyder inte att utskriftsuppgifterna är fullständiga. Kontrollera skrivare, pappersprodukt, drivrutinsinställningar, färghantering och mätvillkor; behåll obekräftade uppgifter som unknown. Se [varning och regler för komplettering](measurement-file-import.md#varning-mxf-kan-behöva-kompletterande-uppgifter).

Implementerad 2026-09-27; användaracceptans återstår. A1 och A2 är användargodkända.

```matlab
cd('/Users/christer/Desktop/InkProf')
setupInkProf();
[folder, input] = inkprof.prepareProfileInput();
```

Välj uttryckligen en mätrevision (measurement-JSON). Dialogen visar filnamn och hash, antal RGB-patchar, spektralband, XYZ, mätvillkor med proveniens, registrerade utskriftsuppgifter och diagnostik. Ange namn och välj **Lock profile input** eller **Cancel**. Ingen senaste fil väljs automatiskt.

TI3/MXF kan också väljas och normaliseras då genom befintlig mätimport. För TI3 behövs den matchande målbeskrivningen; om den inte hittas i samma mapp anges den med `TargetFile`. Detta importsteg sparar en separat mätomgång även om den efterföljande låsningen avbryts. MXF använder sin egen layout.

```matlab
[folder, input] = inkprof.prepareProfileInput(measurementFile, ...
    ProjectFolder=projectFolder, Name="Epson 3880 - corrected 575");
```

För skript finns `ShowDialog=false`, vilket uttryckligen godkänner att låsa den angivna revisionen efter kontroller. Det kringgår inte kontrollerna.

B1 kontrollerar mätningens fullständighet, chart-hash, motsvarande revisions-TI3, patchidentiteter, RGB-värden och överensstämmelse mellan JSON och TI3. Radriktningsdiagnostiken räknas om. Misstänkt omvänd rad blockerar. Om färgbaserad diagnostik saknas kan en positionerad MXF användas som alternativt identitetsunderlag: den bevarade originalfilens hash kontrolleras, filen importeras på nytt och dess patch-ID, positioner och RGB jämförs med den valda revisionen. Original-MXF följer med i den låsta mappen. Detta sparas som `layoutEvidence`; `rowDirectionCheck.available` förblir false och fysisk svepriktning betraktas inte som verifierad. Utan något av dessa underlag blockeras låsningen. Diagnostiken är heuristisk och omfattar bara de fullständiga rader som metoden kan pröva. Den certifierar inte alla patchars färgriktighet. Normal färgavvikelse mot målfilens uppskattningar är inte i sig ett profilfel eller blockeringsskäl. Ursprungliga fram-/bakåtsvepsvarningar redovisas som historisk mätkvalitet och kan föregå accepterade punktkorrigeringar.

En unik mapp under `profiles/inputs` innehåller:

- `measurement.json`, `chart.json` och `source.ti3`: ögonblicksbilder av valt underlag.
- `profiling.ti3`: endast källpatchar, utan utfyllnad; bibehållen ordning och mätvärden.
- `profile-input.json`: namn, relativ filkoppling, SHA-256, källrevision, kvarhållna datarader, mätvillkor, utskriftsuppgifter och diagnostik.

Manifestet uppdateras. Låst betyder en separat, hashidentifierad revision som rutinen inte skriver över; det är inte ett filsystemskrivskydd. Kommande byggsteg måste verifiera hashvärdena före användning. Ursprungliga absoluta sökvägar är proveniens, medan snapshotfilerna finns tillsammans i den nya mappen.

Detta skapar ingen ICC-profil. Val av spektral kontra XYZ-baserad beräkning och fullständigt utskriftsrecept hör till B2. Okänt papper eller andra saknade utskriftsuppgifter förblir okända.

Den rättade 575-revisionen `measurement-20260927-154833490-rows22-23.json` har provats i ett tillfälligt testprojekt: 575 källpatchar och inga misstänkt omvända rader. Testprojektet raderades efter kontroll; ingen permanent profilkörning har valts åt användaren.

## Fönster och vänteläge

B1 visar statusmeddelanden under kontroll och sparning. Bekräftelsefönstret visas överst och får fokus innan funktionen väntar på **Lock profile input** eller **Cancel**. Det är inte modalt mot hela MATLAB-skrivbordet. Funktionen återkommer först när ett val görs; kryssknappen motsvarar Cancel.

Om en äldre körning väntar bakom andra fönster: avbryt med Ctrl+C i MATLAB, stäng endast fönstret `InkProf - Select profile input`, kör `rehash` och starta om. Ingen profilinput publiceras innan låsningen bekräftats. Fönstrets accept/cancel-vägar har separata automatiska GUI-tester.
