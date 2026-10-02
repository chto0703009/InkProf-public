# C3 – analys av en uppmätt verifieringsutskrift

Implementerad 2026-09-28. MATLAB Base är gränssnitt, Python/Colour och
ArgyllCMS profcheck utför analysen. Inget instrument öppnas av analysrutinen.

```matlab
setupInkProf();
[report, reportFile] = inkprof.checkVerificationTarget();
```

Välj först C2-paketets **verification.json**, sedan mätningens sparade
**measurement-….json**. Den oförändrade TI3-revisionen med samma basnamn,
chart.json och source.ti2 ska finnas kvar i mätmappen. JSON är InkProfs interna
spårbarhetsunderlag; extern TI3/MXF importeras via det ordinarie mätflödet först.

För upprepad analys:

```matlab
[report, reportFile] = inkprof.checkVerificationTarget( ...
    verificationFile, measurementFile, ...
    PrintSettings=struct('application','Adobe Photoshop', ...
                        'evidenceStatus','Screenshots pending'));
```

`ShowDialog=false` ger samma sparade rapport utan fönster.
`PrintSettings` är användarens beskrivning, **inte en verifiering**. Ange bara
uppgifter som faktiskt är kända. Fönstrets filter visar samtliga patchar,
unika patchar, gråskala, färger, challenge, upprepningar eller modellbedömt
nåbara unika färger. Raderna sorteras med störst ΔE00 först.

## Jämförelse och spårbarhet

- Patch-ID, koordinat, RGB och fullständighet kontrolleras mot C2-definitionen.
  Efter omordning kan referensens `id` skilja från utskriftens TI2-ID.
  Då används den explicita kopplingen `placement.sampleId`; analysen gissar
  inte identitet från färglikhet eller radordning. Rapportens `sampleId` är
  referens-ID och `measurementSampleId` är mätfilens ID. Kopplingen måste vara
  en-till-en, och koordinat samt RGB måste fortfarande stämma. Äldre underlag
  utan `placement.sampleId` kräver samma ID i referens och mätfil.
- SHA256 kontrolleras för ICC, TI2, chart.json och TI3-revision. Ändras en
  indatafil under analysen avbryts rapporteringen.
- Argyll profcheck integrerar spektrala data med D50/1931_2, med samma valbara FWA/D50-kompensation som profilreceptet.
  Uppmätt Lab hämtas med sex decimaler. Samma Argyll-metod används i profilens
  träningskontroll; den separata generella spektralintegratorn används inte här.
- Primärt ΔE00 jämför **önskat absolut D50-Lab** mot uppmätt Lab. Skillnad mot
  profilens förutsägelse är ett separat diagnostiskt värde.
- Huvudstatistiken innehåller alla unika patchar inklusive challenge, men inte
  deras extra upprepningar. Gruppstatistik skiljer ut challenge och gråskala.
  Modellbedömt nåbar betyder inte bevisad fysisk gamut. Dark betyder önskat
  L* < 25; highChroma betyder önskat C*ab ≥ 40. Grupper kan överlappa.
- Gråbalans redovisas som medelavvikelse L*, a*, b* med tecken och uppmätt
  C*ab för de avsedda neutrala patcharna.
- Separata upprepade patchar jämförs med sina original. Den variationen
  inkluderar både utskriftsposition och mätning. Fram-/återsvepens jämförelse
  bevaras separat i JSON och avser repeterbarhet, inte färgnoggrannhet.

Varje körning skapar `checks/<uuid>/verification-check.json`, en Markdownrapport
med samtliga patchar och `profcheck.log` under verifieringsmålet. Projektmanifestet
uppdateras. Källornas sökvägar och hashvärden sparas. Inga mätningar eller ICC-filer
skrivs över.

## Beslut och kvarvarande kontroll

Nuvarande C3 ger status `insufficient-evidence` och `qualityValidated=false`.
Det är avsiktligt: rapporten är diagnostisk. Den ändrar inte profilens status till
godkänd. Automatisk acceptans och profilrangordning är inte implementerade.
Före slutbeslut behövs verifierad utskriftskedja och överenskomna gränser för
färgfel och gråbalans. ISSUE-001 om mätbrus/invers kvarstår.

C2-TIFF är redan konverterad med printerprofilen, absolut kolorimetriskt, utan
svartpunktskompensation. Den ska inte konverteras igen vid utskrift. Photoshop
**Printer Manages Colors** och ett gråat **Off** i drivrutinen bevisar inte att
kedjan är utan ytterligare konvertering. Den aktuella körningen 2026-09-28
sparar dessa användarrapporterade val som overifierade; skärmdumpar inväntas.
En annan utskriftsmetod kan kräva ett nytt, okonverterat mål.

Verifieringsmål som används för senare modellförbättring blir träningsunderlag;
ett nytt separat slutkontrollmål krävs då.

C3 sparar också `iteration-feedback.json`, `iteration-feedback.md` och `feedback.log` för fortsatt diagnostik. För egna gränser och återanalys av ett befintligt resultat, se [verifieringsåterkoppling](verification-feedback.md).

Tabellens `Measured vs desired (dE00)` avser uppmätt mot önskad färg. `Model vs measurement (dE00)` avser modellens förutsägelse mot uppmätt färg. Den senare hette tidigare `dE00 predicted`, vilket kunde misstolkas som förutsagt fel mot målet. JSON-fältet `predictedDeltaE00` behålls för kompatibilitet och betyder fortfarande modell mot mätning.
