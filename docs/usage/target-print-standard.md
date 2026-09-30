# InkProf – standard för utskrift av mål

## Varning: externa utskrifter utan kontrastmarkörer

**Mål som skrivits ut utan kontrastmarkörer mellan patcharna kan ge problem vid radmätning med chartread**, särskilt när intilliggande patchar har snarlika färger. Det kan exempelvis ge fel om för få eller för många patchar. En korrekt importerad patchdefinition garanterar inte att det befintliga arket går att läsa tillförlitligt.

**Rekommenderat arbetsflöde:** importera patchdefinitionerna som TI1/TI2 i första hand, eller generell CGATS från ett annat program, och låt InkProf generera en ny TIFF16-utskrift med kontrastmarkörer och matchande TI2/JSON. Använd sedan just det nya utskriftspaketets TI2 vid mätningen. Kontrastmarkörer minskar risken för segmenteringsproblem men garanterar inte felfria svep.

En import eller omordning i programmet ändrar inte ett redan utskrivet ark. Om det befintliga arket mäts i ett annat program kan dess mätfil importeras separat med bevarad patchkoppling.


Fastställd: 2026-09-26. Gäller nya mål från både den generella Argyll-layouten och InkProfs återanvändbara sidmall. Befintliga paket ändras inte retroaktivt.

## Patchdefinitioner, egna utskrifter och externa mätningar

InkProf styr layoutstandarden för sina egna utskrifter. Import ska bevara filens patchdefinition, ursprungliga layout och mätkoppling. Först när användaren skapar en ny utskrift från exempelvis en RGB-PXF skapas en separat InkProf-layout med matchande JSON och mätunderlag. Originalets layout och tidigare mätningar får inte skrivas över eller omtolkas.

**Kontrastmarkörer ska vara standard för nya mål avsedda för radmätning**, även vid senare mätning i i1Profiler. De ingår i layouten och det kompatibla mätunderlaget men räknas inte som källpatchar eller profilunderlag. Mottagarens stöd för layouten måste verifieras.

Redan uppmätta data, exempelvis en stödd MXF, ska kunna importeras och analyseras oberoende av vilket program som skapade utskriften och om kontrastmarkörer användes. Patchkoppling, RGB-värden, spektra, enheter och mätvillkor ska kontrolleras och bevaras.

Ett redan utskrivet externt mål utan kontrastmarkörer kan vara känsligare att radmäta med chartread. Mät då vid behov i ursprungsprogrammet och importera resultatet, eller skapa en ny InkProf-utskrift från patchdefinitionen. En ny TI2 kan inte lägga kontrastmarkörer på ett befintligt ark.

Se [specifikation och implementationsstatus: patchdefinition, layout och mätresultat](../decisions/008-target-layout-measurement-separation.md).

Alla format i projektets formatspecifikation ska kunna hanteras efter sitt innehåll, även om deras mål inte följer denna utskriftsstandard. Tillgängliga uppgifter om hur arket såg ut vid mätningen ska bevaras. Saknad information och ännu ej stödda formatvarianter ska redovisas uttryckligen.

TIFF-import och instrumentets läsning av en utskrift är skilda steg. Snarlika grannpatchar kan försvåra fysisk radmätning. Scrambling kan minska problemet men garanterar inte grannkontrast; det kräver en ny utskrift med exakt samma permutation i JSON och mätunderlag. Kontrastmarkörer behålls. En ensam TIFF får inte antas innehålla all patchidentitet eller mätmetadata.

## Rubrik och sidfot

| Del | Text och placering |
|---|---|
| Rubrik | **InkProf Quality Profiling RGB printer**, centrerat överst, **20 punkter**. |
| Datum och tid | Nere till vänster, `ÅÅÅÅ-MM-DD HH:mm`. Avser filens generering, i datorns lokala tid. Samma tid på samtliga sidor i paketet. |
| Targetinformation | Centrerat ovanför filsökvägen: källfilnamn, metod när den är känd, patchantal och en kort geometrisk nätsammanfattning från JSON-fältet `targetInfo`. |
| Målets fil | Centrerat längst ned: fullständig sökväg och TIFF-filnamn inklusive filändelse för aktuell sida. |
| Sidnummer | Nere till höger, `1 (3)`, `2 (3)`, `3 (3)`: aktuell sida följd av totalt antal sidor inom parentes. En sida märks `1 (1)`. |

Hela den slutliga sökvägen visas, inklusive TIFF-filnamnet, aldrig den tillfälliga byggmappens namn. Texten centreras och radbryts vid behov till två rader, normalt i 9 punkter och minst 6 punkter. Om hela sökvägen inte ryms avbryts genereringen tydligt utan trunkering. Vid flytt efter generering behålls den ursprungliga sökvägen i bilden.

Nuvarande rendering placerar rubrikens textruta centrerad omkring 9 mm från överkanten. Från 2026-09-28 centreras helsidiga måls sidfot 12 mm från underkanten, med 8 mm sidmarginal. Detta ger minst cirka 8 mm vit yta under även en tvåradig sökväg. Tidigare 3,5 mm gav klippt datumtext på användarens utskrift. Skrivarens verkliga utskrivbara yta behöver fortfarande kontrolleras. Sidfoten använder 9 punkter. Punktstorleken räknas om efter TIFF-filens upplösning. Rubrik och sidfot ska ligga i vit marginal utan att överlappa patchar eller andra markeringar.

## Rader, kolumner och mätbana

- Kolumnbokstäver står **ovanför patcharna**, från vänster till höger.
- Rader numreras uppifrån och ned. Den återanvändbara 29 × 20-mallen fortsätter radnumreringen mellan sidorna: 1–20, 21–40 och så vidare.
- Radnummer står till vänster, nära radens överkant. Radnumrens nominella texthöjd är 2 mm (tidigare 1,2 mm). Numren är mellangrå (RGB16: 32768, 32768, 32768) för bättre läsbarhet. I Argyll-layouten står de normalt 8 mm från vänster sidkant, närmare kanten om marginalen kräver det. Den fasta 29 × 20-mallen behåller sin placering 1,25 mm från kanten. Numren ligger nära radens överkant för att lämna den centrala mätbanan fri från text. Läsbarheten behöver bedömas på utskrift.
- Instrumentet förs längs radens mitt, med start och slut på vitt papper utanför patchområdet.
- Radgränser markeras med tydliga, heldragna grå stödstreck på **båda sidor** om patchfältet, i båda renderingsvägarna. Strecken markerar radens övre och undre kant, inte svepets mittlinje. Standard: 0,4 mm tjocklek, upp till 6 mm längd, RGB-grå 35 % av fullt vitt. Minst 6 mm lämnas vitt mellan streck och patch-/kontrastfält. Vid smala marginaler kortas strecken symmetriskt; om inte ens 1 mm ryms ges ett tydligt layoutfel. Mått och positioner sparas i `page-placement.json` respektive mallens layout-JSON. Äldre utskrifter och målpaket ändras inte.
- Misstanken att text eller markeringar bidrog till tidigare felläsningar är inte bevisad. Layoutkontroll ersätter inte fysisk mätverifiering.

Mallen visar kolumner efter Z som 2A, 2B och 2C; Argylls TI2 kan beteckna motsvarande kolumner AA, AB och AC. Kopplingen ska bevaras i layoutbeskrivningen.

## Centrering på sidan

Målområdet ska vara centrerat horisontellt och vertikalt i den tillgängliga ytan mellan rubrik/kolumnetiketter och sidfot. Centreringen omfattar patcharna och deras kontrastfält. Flytten görs i hela pixlar utan omskalning; positionsbeskrivningen i JSON uppdateras samtidigt. Argyll-renderingen reserverar 20 mm upptill och 22 mm nedtill. Argylls sidkapacitet minskas i motsvarande grad; patchar skalas inte. Sidfotens mått sparas i target-JSON under `printSettings`. TI2 behåller patchidentitet, radordning och RGB-värden; den absoluta sidplaceringen lagras i layout-JSON och `page-placement.json`. Äldre paket utan placeringsfil behåller sina ursprungliga koordinater.

I i1Pro 2-provet 2026-09-26 berodde första radens omsvep enligt användaren på att arket satt för långt till höger i släden. Efter korrigerad placering accepterades alla sju rader. Centrering ska ge utrymme för start och avslut på papper; omsvepet ska inte tillskrivas patchigenkänningen.

Den äldre beskurna 263 × 195 mm-bilden behåller 3,5 mm sidfotsavstånd inom bilden och måste placeras centrerad innanför papperets utskrivbara marginaler. Den är inte en helsidig A4-rendering.

29 × 20-mallen har fortsatt sin fasta geometri; generell automatisk centrering är införd i Argyll-renderingen.

## Bildformat, storlek och utskrift

- Utskriftsfilen är **RGB TIFF16**, 16 bitar per kanal, utan inbäddad ICC-profil. CMYK-target avvisas som fel färgformat.
- Normal upplösning är 300 ppi. Upplösning och fysiska mått ska anges korrekt i TIFF-filen.
- Målets totala bildyta, inklusive marginaler, får vara högst **320 mm bredd** horisontellt. Längden vertikalt anges av användaren och har inte längre en fast gräns på 280 mm.
- Liggande A4 är **297 × 210 mm**. Måtten avrundas till hela pixlar vid vald upplösning. Den återanvändbara sidmallen är **263 × 195 mm** och ska inte beskrivas som en fullstor A4-bild.
- Stående A3 kan använda hela den valda längden 420 mm. För TIFF16-dialogen är A4 liggande (297 × 210 mm) standard. Bredder över 320 mm avvisas.
- Skriv ut i **100 % faktisk storlek**, utan anpassning till sida och utan färgomvandling i utskriftsflödet. En profilfri fil i sig garanterar inte att utskriftsprogrammet undviker färgomvandling.
- Förhandsvisningsbilder är endast för skärmvisning; skriv ut TIFF16-filen.

Patchmått, kontrastfält och antal rader bestäms av den valda layouten och ska dokumenteras i paketet. De får inte ändras genom skalning vid utskrift. Nuvarande sidmall har 8 × 8 mm patchar; kontrastprovet för tidigare rader 13–17 har 10 × 8 mm patchar och 1 mm kontrastfält. Dessa är olika layouter, inte universella patchmått.

## Mätunderlag och spårbarhet

Varje utskrift ska ha en motsvarande definition av patcharnas RGB-värden, identitet, sida och position. Intern beskrivning är JSON; Argyll-utbytet använder TI1 för patchdefinition, TI2 för utskriftslayout och TI3 för senare mätresultat.

Randomisering ska återspeglas i TI2 och JSON. Utfyllnad ska skiljas från källpatchar. Använd alltid mätunderlaget som hör till den faktiskt utskrivna layouten; en importerad patchlista innebär inte att ursprungsprogrammets layout har återskapats.

Paketkontrollen ska kontrollera patchkoppling, RGB16-pixelvärden, geometri, upplösning och filhashar. En ändring av rubrik eller marginaler får inte ändra patcharnas värden eller storlek. Flyttas patchar måste positionsbeskrivningen uppdateras. Filkontroll och fysisk läsbarhet ska redovisas separat.

Dokumentera skrivare, papper, utskriftsprogram/drivrutin, medieläge och kvalitetsinställningar vid utskrift. Datumet i sidfoten är genereringstid; faktisk utskriftstid och mättid registreras separat vid behov.

## Implementation

Kontrastmarkörer är ett beslutat standardkrav. Gemensamt förval återstår: `createTarget` använder ännu `SpacerMode="auto"`, medan det provade kontrastmålet använder `"colored"`; den fasta 29 × 20-mallen saknar kontrastfält. Generell MXF-mätimport är ett specificerat flöde och ska verifieras per formatvariant.

Centrerad fullständig TIFF-sökväg är implementerad i båda renderingsvägarna, tillsammans med rubrik, datum/tid och sidnummer.

Standarden används av `inkprof.createTarget` och `inkprof.createTiff16`. Gemensam rubrik och sidfot renderas av `inkprof.internal.drawPrintFurniture` med Java2D i MATLAB med JVM. Patchdata genomgår ingen färgomvandling i textrenderingen.

Se [generera mål](target-generation.md) och [mäta mål](chart-measurement.md) för arbetsflöden.

Detaljerad struktur och provenance: [targetInfo i JSON och TIFF](target-metadata.md).
