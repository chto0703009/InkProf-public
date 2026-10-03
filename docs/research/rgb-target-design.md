# InkProf: antal patchar och täckning av RGB-rummet

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Datum: 2026-09-26. Första utredningen. Rekommendationerna är försöksförslag, inte verifierade kvalitetslöften. Inga nya utskrifter eller instrumentmätningar har genomförts för denna analys.

## Rekommendation

Behåll det befintliga 575-målet som ett första empiriskt underlag. För ett nytt standardförsök rekommenderas en budget på **882 mätpositioner**, med tydlig uppdelning mellan anpassning, oberoende kontroll och upprepningar. Välj slutligt patchantal efter uppmätt modellfel, gråbalans och variation — inte enbart efter en jämn fördelning i RGB.

882 är en praktisk budget, inte ett matematiskt optimum. Den aktuella A4-layouten med kontrastfält har 21 patchar per rad och 21 rader på en full sida: 441 positioner. Två sidor rymmer 882. De nyligen skapade 575-målen upptar 28 rader på två sidor, inklusive 13 utfyllnadspositioner. Ett fullt 882-mål kräver 42 rader: cirka 50 procent fler radsvep, trots samma antal pappersark. Detta är inte samma layout som den äldre 29 × 20-mallen.

## Vad ska täckas?

Styrvariabeln är u=(R,G,B) i [0,1]^3. Vi modellerar hela den låsta kedjan från RGB genom utskriftsprogram, drivrutin, medieläge, bläck och papper till spektrum eller XYZ. Antalet patroner gör inte detta till ett tolvdimensionellt styrproblem: InkProf kan här bara välja tre ingångsvärden.

Tre mål måste skiljas:

1. Geometrisk täckning av RGB-kuben, inklusive hörn, kanter, ytor och inre.
2. Tillräcklig upplösning i den faktiskt utskrivna färgrymden.
3. Noggrannhet där användaren prioriterar den, exempelvis gråbalans, skuggor och mjuka tonförlopp.

Likformigt RGB innebär inte likformigt Lab. R=G=B är en diagonal i styrvärdesrummet, inte bevis för neutral utskrift. Den uppmätta neutralbanan kan ligga vid olika kanalvärden. Punkter i diagonalens närhet behövs därför också. Provtagning av kubens ytor hjälper gränsbeskrivningen, men räcker inte som bevis för den verkliga gamutgränsen i en icke-linjär utskriftskedja.

Spektra kan integreras till XYZ och Lab utan ICC-profil när illuminant, observatör, skala och referensvit är definierade. För denna studie används inga sådana antaganden: jämförelsen nedan gäller enbart enhets-RGB.

## Vad gör Argyll och InkProf idag?

Argylls skrivarguide anger 400–1000 patchar som en allmän utgångspunkt för RGB, beroende på beteende och ambitionsnivå. Det är ingen garanti för vår skrivare. [1]

`targen` erbjuder OFPS, regelbundna kubpunkter och gråramp. En tidigare ICC/MPP kan styra perceptuell placering; utan sådan används en generell modell. `-f` anger totalbudget inklusive redan valda punkter. Profilbaserad neutralbetoning är relevant först när neutralbanan kan uppskattas. [2]

Nuvarande `createTarget` använder `-d2`, vita/svarta upprepningar, gråramp och `-f`. Standardvärdena i InkProf är 100 patchar, 9 gråsteg samt 4 vita och 4 svarta positioner. Detta är ett tekniskt standardvärde, inte ett godkänt profileringsrecept. Anpassning med tidigare profil, explicit kubfördelning och rollindelning för validering är ännu inte exponerade som färdiga användarval.

Blanda inte algoritmen för att välja RGB-punkter med randomisering av deras plats på papperet. Placering och kontrastfält hjälper mätningen; de tillför inte nya färgprov.

## Faktisk kontroll av 575-filen

Kontrollerad källa: `projects/Chart 575 Patches.pxf`.
SHA-256: `f54d05bb1c6b5898a3e30f8342a3361f166a4faa43aaad2d4ef9e67e32ad4fa3`.

Två jämförelsemängder skapades med installerad ArgyllCMS 3.5.0:

```sh
targen -d2 -e4 -B4 -g33 -m3 -f575 baseline-575
targen -d2 -e4 -B4 -g33 -m3 -f882 baseline-882
```

Detta är kandidater för geometrisk jämförelse, inte de slutliga rollindelade recepten. Båda kommandona har körts och deras faktiska patchantal kontrollerats. `-m3` lägger ett glest kubnät som ankare; det ersätter inte spridningen mellan ankarna. Grårampen och hörnen kan överlappa andra val, så faktisk unik mängd måste alltid räknas efter generering.

| Egenskap | Befintlig PXF 575 | Argyll-kandidat 575 | Argyll-kandidat 882 |
|---|---:|---:|---:|
| Mätpositioner | 575 | 575 | 882 |
| Unika RGB | 569 | 569 | 876 |
| Extra positioner med redan förekommande RGB | 6 | 6 | 6 |
| Kubhörn | 8/8 | 8/8 | 8/8 |
| Unika R=G=B | 23 | 33 | 33 |
| Unika punkter på kubens rand | 299 | 217 | 292 |
| p95 för avstånd till närmaste RGB-prov | 0,09672 | 0,09210 | 0,07761 |
| Största avstånd i probnätet | 0,11823 | 0,11644 | 0,10017 |

Avstånden är euklidiska i normaliserat RGB, inte ΔE, procent färgfel eller profileringsfel. Ett regelbundet nät med 33³=35 937 kontrollpunkter, inklusive kubgränserna, användes. För varje punkt beräknades närmaste avstånd till targetmängden. Dubbletter räknades efter avrundning till åtta decimaler. Nätets största avstånd är en uppskattning underifrån av det kontinuerliga värsta avståndet; mellan nätpunkterna kan större luckor finnas. Råresultat, kommandoutdata och reproduktionsskript ligger i `rgb-target-study/`.

Slutsats: 575-filen har goda grundegenskaper och är inte uppenbart olämplig. Ungefär hälften av dess unika punkter ligger på randen. Argyll-kandidaten med samma antal flyttar fler punkter till andra delar av kuben och har något mindre luckor enligt detta mått. 882 ger tydligare förbättring av täckningen. Inget av detta visar vilket target som ger lägst uppmätt ΔE00.

## Förslag till första standardrecept

Fördelningen nedan är InkProfs försöksförslag, inte en Argyll-rekommendation:

| Roll | Positioner | Användning |
|---|---:|---|
| Anpassning | 738 | Framåtmodell och första profil |
| Låst kontroll | 120 | Modellval och redovisad första kontroll; aldrig in i anpassningen |
| Extra upprepningar | 24 | Två extra kopior av 12 representativa anpassningspatchar |
| Summa | 882 | Två fulla sidor i aktuell layout |

Anpassningsmängden ska innehålla alla hörn, cirka 33 diagonalnivåer och ett glest kubnät. Komplettera med väl spridda punkter; fördelningen nära neutralområdet ska prövas snarare än låsas till en obevisad procentsats. Upprepningarnas 12 grundfärger bör omfatta vitt, svart, flera mellangrå och representativa kulörer. Fördela kopiorna mellan sidor och positioner. Tre exemplar per vald färg ger en grov variationsbild, inte en exakt osäkerhetsmodell.

Kontrollmängdens 120 färger väljs separat: förslagsvis 96 brett spridda och 24 längs eller nära diagonalområdet. Undvik RGB som redan finns i anpassningen. Dessa tal och placeringar behöver pilotutvärderas. Om kontrollmängden används för att styra nästa förbättring blir den utvecklingsdata; ett nytt orört sluttest behövs för den slutliga kvalitetsuppgiften.

Rollerna måste finnas i intern JSON och följas vid export till profilbyggaren. Att skriva alla 882 till en TI3 och låta `colprof` använda dem alla skulle förstöra denna uppdelning. Upprepade RGB ska ha egna prov-ID, gemensamt färg-ID och koppling till varandra. Kontrastfält och utfyllnad är separata layoutobjekt.

För den redan utskrivna 575-kartan: mät och använd den, bygg ett första underlag och skapa därefter ett separat kontrollmål. Spara kostnaden för en ny första utskrift; det finns ännu ingen evidens för att kasta bort 575-materialet.

## Hur väljs ett tillräckligt antal?

Ett fullständigt regelbundet nät kostar n³ prov: 5³=125, 7³=343, 9³=729 och 11³=1331. Sådana nät är begripliga jämförelsealternativ, men kräver fortfarande extra gråprov, upprepningar och kontroll. OFPS är en rimlig referens att jämföra med, inte automatiskt vinnaren för alla felmått.

Försök med växande, helst nästlade anpassningsmängder, exempelvis cirka 400, 575, 750 och 1100 unika färger. Nästlade betyder att tidigare prov behålls. Två separata targen-körningar med olika `-f` ger inte automatiskt nästlade mängder. InkProf måste äga kompletteringslistan eller välja dokumenterade delmängder ur en gemensam mätt mängd. De lokala 575- och 882-kandidaterna ovan är inte påstått nästlade.

Vid jämförelse ska skrivare, papper, inställningar, torktid och mätvillkor vara lika. Upprepade avläsningar av samma tryck mäter främst läsvariation; upprepade tryck behövs för utskriftsvariation. Fram- och retursvep på samma rad är användbara men ersätter inte nya tryck.

Redovisa median, p95 och max ΔE00 på kontrollmängden, samt gråbalans, ljushetsfel och tonförlopp separat. Spektralfel kan komplettera, med explicit skala. Rapportera stickprovsstorlek: med 120 kontrollfärger bestäms p95 av bara ungefär de sex största felen. Små skillnader i p95 kräver därför försiktighet och upprepade försök.

Stoppa förtätningen när de överenskomna kvalitetskraven uppfylls och nästa utökning inte ger en förbättring som går att skilja från tryck-/mätvariationen. Toleranser ska bestämmas utifrån användning; denna utredning hittar inte på ett generellt godkänt ΔE00-tal.

## Adaptiv fortsättning

När ett första uppmätt samband finns kan nästa RGB-punkter väljas med stöd av en preliminär modell. Beakta geometriska luckor, lokala kontrollfel, ändrad lutning/krökning och osäkerhet. Stor gradient ensam innebär inte stort interpolationsfel: en brant linjär funktion kan interpoleras exakt. Mättade områden med liten respons kan däremot göra inversen instabil.

Blanda riktad komplettering med fortsatt bred utforskning. Annars riskerar modellen att bara förbättra områden där den redan kan upptäcka sina egna fel. Neutralitet ska efter första mätningen styras av den uppmätta neutralbanan, inte enbart av R=G=B. Viktning i en anpassning kan inte ersätta saknade prover.

Fler patchar ökar inte skrivarens fysiska gamut. De kan förbättra beskrivningen av dess gräns och möjliggöra en bättre invers/gamutmappning. Att använda en preliminär profil för patchval är inte samma sak som att färghantera testutskriften: styrvärdena måste fortfarande skickas oförändrade genom den valda utskriftskedjan.

## Nästa implementation

1. Ett granskningskommando för target: unika färger, hörn, diagonal/rand, luckor och roller.
2. Explicit genereringsrecept i JSON: algoritm, verktygsversion, parametrar, originalpatchar och filhashar. Layoutens slumpfrö är inte i sig ett frö för targens punktgenerering.
3. Separata roller för anpassning, kontroll och upprepning genom hela kedjan TI1 → TI2 → mät-JSON → profilunderlag.
4. Valbar basgenerering och senare profilbaserad generering. Faktiskt antal och ankare valideras efter verktygskörning, inte bara från önskat `PatchCount`.
5. Först därefter automatisk komplettering och stoppkriterier.

Detta dokument ändrar inga produktionsförval och genererar inga nya utskriftsmål. Befintlig 575-PXF och de två lokala Argyll-kandidaterna är analysunderlag.

## Källor och anknytning

[1] [ArgyllCMS: Profiling Printers, Creating a print profile test chart](https://www.argyllcms.com/doc/Scenarios.html). Hämtad 2026-09-26.

[2] [ArgyllCMS: targen](https://www.argyllcms.com/doc/targen.html). Hämtad 2026-09-26; lokal verktygsversion 3.5.0.

Tidigare InkProf-underlag: [modell, invers och adaptiv mätning](InkProf-modell-inversion-och-adaptiv-matning.md), [utskriftsstandard](../usage/target-print-standard.md). Matematiken, budgetfördelningen och slutsatserna från lokala data ovan är denna utrednings egna analyser.

Efter denna utredning har en första [interaktiv geometrisk förtätning](../usage/rgb-target-designer.md) implementerats. Det är ett jämförelsealternativ till OFPS; ännu ingen uppmätt färgfelstyrning.
