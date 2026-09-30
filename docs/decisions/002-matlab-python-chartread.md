# 002 - MATLAB, Python-brygga och radmätning med ArgyllCMS

Datum: 2026-09-25. Uppdaterat: 2026-09-26. Status: egen mätprototyp simuleringsprovad; fysisk verifiering återstår. Kompletterar projektplan v0.6 och [beslut 007](007-independent-inkprof.md).

## Uppdaterat beslut: terminalägd mätsession

Den rekommenderade implementationen är nu `startMeasurement` / `finishMeasurement`. Python startar chartread med direkt terminalkontakt och äger hela mätsessionen. MATLAB förbereder chart-JSON och validerar/importerar resultatet efteråt. Ingen löpande pollning eller tangentvidarebefordran krävs från MATLAB. Den äldre JSON-lines-/PTY-bryggan nedan behålls för felsökning och är inte längre det rekommenderade användarflödet.

Chartreads radomläsning och `-r` återanvänds. Python sparar tidigare TI3 före Resume och ett separat resultatsnapshot efter sparning. Körningsmetadata loggas, men den nya direkta terminalvägen sparar ännu inte rå dialogtext. Se [aktuell köranvisning](../usage/chart-measurement.md).

## Inriktning

InkProf behåller MATLAB Base som huvudplattform och äger själv spektrala data och beräkningar, utan körberoende till SpectraLab eller Camera-41. För interaktiv radmätning rekommenderas en liten separat Python-process som styr ArgyllCMS `chartread`. Bryggan avgränsas till processkommunikation och mätsessionens tillstånd. Den ska inte bli en andra implementation av färgberäkningar eller projektmodellen.

Python blir ett deklarerat beroende för denna integrerade mätväg. Import av redan uppmätta filer och analys i MATLAB ska kunna användas utan bryggan. Ingen ChromIQ-adapter krävs.

## Radmätning i ArgyllCMS

`chartread` stöder radvis mätning för instrument som har motsvarande stöd. Användaren för spektrometern över en rad patchar; Argyll hanterar instrumentkommunikation och identifiering av patcharna. Targetets geometri måste vara anpassad till instrumentet och mätläget.

Underlaget är en `.ti2`-fil som beskriver kartan. Resultatet sparas som `.ti3`, med spektrala data när instrumentet tillhandahåller dem. Verktyget stöder omläsning och återupptagning av en delvis uppmätt karta med `-r`. Exakt instrumentmodell, Argyll-version, operativsystem och mätläge måste verifieras praktiskt.

Kontinuerlig insamling under dragningen innebär inte automatiskt att MATLAB får varje patchvärde i realtid. Första målet är statusåterkoppling efter en godkänd rad och korrekt import av sparade mätdata. Liveöverföring av spektrum eller patchvärden är ett separat krav som måste provas; konsolmeddelanden är inte ett garanterat strömmande data-API.

## Ansvarsfördelning

| Del | Ansvar |
|---|---|
| InkProf i MATLAB | Projekt, targetdefinition, patchidentiteter, utskriftsrecept, användargränssnitt och profilförsök |
| InkProfs egna beräkningsrutiner (planerade) | Spektral kolorimetri, XYZ/Lab, ΔE00 och analys med spårbara indata |
| Python-brygga | Starta och övervaka `chartread`, hantera dess dialog, kommandon, loggar och sessionstillstånd |
| ArgyllCMS | Instrumentkommunikation, radmätning, patchidentifiering och ICC-generering genom respektive verktyg |

Endast Argyll-processen ska äga instrumentanslutningen i denna mätväg. InkProf ska inte samtidigt öppna en separat spotread-session mot samma instrument.

## Varför en brygga?

MATLAB kan starta externa program, men ett vanligt `system`-anrop väntar på att programmet avslutas. Det ger inte ensamt en komplett lösning för löpande, dubbelriktad kommunikation och ett responsivt användargränssnitt under mätningen.

Direkt processhantering från MATLAB är möjlig att undersöka. Bedömningen är ändå att en avgränsad Python-process blir enklare att underhålla, med hänsyn till tidigare arbete i SpectraLab. Språkvalet avgörs inte av färgmatematiken eller mätningens hastighet, utan av robust hantering av den interaktiva processen.

Bryggan behöver hantera kalibreringsbegäran, efterfrågad rad, godkänd eller misslyckad dragning, omläsning, avbrott och kontrollerat avslut. Ett avbrott ska inte rapporteras som en lyckad sparning utan kontroll av resultatfilen. Mätningar som bara finns i processens minne får inte antas vara säkrade på disk.

För `targen`, `printtarg` och `colprof` är behovet av en interaktiv brygga mindre. Vanliga processanrop kan räcka, med separat hantering av framsteg och avbrytning om gränssnittet kräver det.

## Gränssnitt mellan MATLAB och bryggan

Prototypen använder JSON-meddelanden över standardströmmar och POSIX-PTY mot chartread. Händelserna är `started`, `output`, `exited` och `error`. Rå konsoltext och resultatfiler bevaras. Windows-mätning stöds ännu inte.

Möjliga framtida semantiska händelser är ”kalibrering krävs”, ”rad B efterfrågas”, ”rad godkänd”, ”omläsning behövs”, ”resultat sparat” och ”session misslyckad”. Händelserna är bryggans kontrakt, inte befintliga standardmeddelanden från Argyll.

Originalfilerna `.ti2` och `.ti3`, verktygsversion, argument, sessionslogg och koppling till targetets identitet ska bevaras. InkProf i MATLAB ansvarar för validering och införlivande av mätdata. Om konsoltext behöver tolkas ska adaptern provas mot angivna Argyll-versioner, och okända meddelanden ska kunna granskas i råloggen.

## Erfarenheter från befintliga program

SpectraLabs `SpotreadInstrument.m` använder redan `ManualSafeBridge.m` och Python för ett interaktivt Argyll-flöde. Erfarenheter av processlivslängd, kalibrering, fel och diagnostik kan återanvändas, men inga anrop till SpectraLab ska krävas. `chartread` kräver däremot en egen sessionshantering för hela kartan; punktmätningens livscykel ska inte kopieras oförändrad.

ChromIQ har `workflow/measure_manager.py`, med en `MeasureManager` som styr `chartread`, tolkar meddelanden och hanterar fel. Det finns även en alternativ mäthjälpare med JSON-kommunikation. Detta är en historisk kodobservation. Fortsatt implementation ska använda vanlig ArgyllCMS och egen adapter, utan att leta rutiner i ChromIQ-koden. Ingen tredjepartskod har importerats genom detta beslut.

## Första praktiska verifiering

1. Dokumentera instrumentmodell, operativsystem, Argyll-version, Python-miljö och önskat mätläge.
2. Skapa och skriv ut en liten karta lämpad för instrumentets radmätning. Bevara `.ti2`, patchidentiteter och utskriftsrecept.
3. Kalibrera och läs flera rader med vanlig `chartread` för att fastställa att själva instrumentflödet fungerar.
4. Upprepa genom bryggan och MATLAB-gränssnittet. Prova omläsning och hantering av en misslyckad rad.
5. Avsluta med sparning och återuppta. Kontrollera vad som faktiskt sparas; prova kontrollerad felhantering vid förlorad anslutning.
6. Importera `.ti3` till InkProfs interna JSON och kontrollera patch-ID, enheter, spektral våglängdsaxel, mätvillkor samt att tidigare godkända värden bevaras korrekt.
7. Kontrollera att MATLAB-gränssnittet förblir responsivt och att fel eller ofullständiga sessioner aldrig visas som fullständiga mätningar.

Provet avgör bryggans detaljer. Radmätningen är i sig inget skäl att överge MATLAB.

## Källor

- [ArgyllCMS: chartread](https://www.argyllcms.com/doc/chartread.html)
- [ArgyllCMS: TI3-format](https://www.argyllcms.com/doc/ti3_format.html)
- [MathWorks: system](https://www.mathworks.com/help/matlab/ref/system.html)
- Lokal kod granskad 2026-09-25: SpectraLab `SpectraLab_v1.2.1-dev/spectralab/+spectralab/+drivers/SpotreadInstrument.m` och `+spotread/ManualSafeBridge.m`.
- Lokal kod granskad 2026-09-25: ChromIQ `workflow/measure_manager.py`.
