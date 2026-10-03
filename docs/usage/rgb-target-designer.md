# RGB-target: iterativ förtätning och Argyll-alternativ

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Infört 2026-09-26 som en geometrisk prototyp. Ingen uppmätt färgmodell ingår och ingen profilnoggrannhet utlovas.

## Öppna fönstret

```matlab
cd('/Users/christer/Desktop/InkProf')
paths=setupInkProf();
designer=inkprof.designTarget();
```

Fönstret är på engelska. Välj **InkProf mesh refinement** eller **Argyll OFPS**. Namnet sparas som targetnamn i JSON och föreslås som filnamn vid sparning. Alla numeriska gränser är användarinställningar, inte fasta punktantal i algoritmen.

Ange namnet i **Target name / file name** överst till vänster. Ett separat sparområde längst ned visar **Not saved** och, efter generering, det föreslagna filnamnet. Generering sparar inte automatiskt. Knappen **Save definition: TI1 + JSON…** blir tillgänglig efter generering (även efter förhandsvisning av startnätet). Fildialogen låter dig välja både mapp och slutligt filnamn. Efter sparning stängs fönstret. Sökvägarna visas i MATLAB; inget TIFF-fönster öppnas.

För nätmetoden:

1. Ange **Initial levels per axis**: exempelvis 5, 7, 9 eller 11 ger 125, 343, 729 respektive 1331 kubpunkter före extra gråpunkter.
2. Ange **Maximum total patches**. Gränsen omfattar anpassning, kontroll och extra upprepningar. Startnät plus extragrå och reserv för kontroll/upprepning måste rymmas.
3. Välj **Preview initial grid**. Diagram och tabell visar tetraedrarnas tyngdpunkter som kandidater, sorterade efter avståndet till närmaste anpassningspunkt. Kubbilden visar de befintliga anpassningspunkterna.
4. Ange vid behov **Max interior gap** i normaliserat RGB. Noll stänger av denna tröskel. Det maximala möjliga kubavståndet är sqrt(3), inte 1.
5. **Initial gap ratio** är ett frivilligt geometriskt stoppvillkor. Noll stänger av det; annars måste värdet vara större än 1. Diagrammet bör granskas innan kriteriet aktiveras.
6. Välj **Refine / generate**. **Stop generation** avbryter nätmetoden mellan tillägg utan att spara ett halvfärdigt mål. Varje ny generering utgår från det angivna startnätet; ändrad punktgräns kör om samma recept. Det är inte en dold fortsättning på ett annat target.
7. **Save definition: TI1 + JSON…** öppnar en fildialog. Välj ett nytt namn; befintliga resultat skrivs inte över.

Förvalet är 5 nivåer, totalt högst 575 positioner, 33 gråsteg, 64 kontroller och 12 extra upprepningar. Dessa är ändringsbara startvärden, inte ett påvisat optimum. Kontrollerna och upprepningarna räknas inte som nya punkter i förtätningsnätet.

## Om patchantalet inte räcker

Felrutan visar nu valda total-, kontroll- och upprepningsantal, hela subtraktionen, hur många anpassningspunkter som krävs och vilken totalgräns som minst behövs. För nätmetoden räknas kubpunkter och ytterligare unika gråpunkter före generering; gråpunkter som redan finns i kubnätet räknas inte dubbelt.

Exempel med 5 nivåer, 33 gråsteg, 64 kontroller, 12 upprepningar och totalgräns 100:

```text
Available fitting points: 100 - 64 - 12 = 24
Required fitting points: 153 (5^3 = 125 grid points + 28 additional gray points).
Set Maximum total patches to at least 229 ...
```

229 räcker här för startnätet och de extra rollerna; en större gräns behövs för att faktiskt lägga till förtätningspunkter. Med förvalet 575 återstår 499 anpassningspunkter, vilket ger utrymme för 346 tillägg utöver startmängdens 153.

Öka **Maximum total patches**, eller minska startnät, gråsteg, **Control patches** eller **Extra repeat patches**. De två senare kan sättas till noll för ett rent nätförsök, men kub och gråsteg måste fortfarande rymmas. Noll gråsteg innebär inga extra gråpunkter utöver dem som redan finns i kuben.

Argyll-alternativet visar sin befintliga reservation för åtta hörn och valda gråsteg. Denna reservation är konservativ eftersom vissa punkter kan överlappa; det faktiska genererade antalet kontrolleras efteråt. Inga inställningar ändras automatiskt av felrutan.

## Vad iterationen gör

Ett Delaunay-tetraedernät byggs över de unika anpassningspunkterna i [0,1]^3 med MATLAB Base. Standardmetoden från algoritmversion 2.0 är **interior**:

1. Beräkna tyngdpunkten i varje tetraeder som medelvärdet av dess fyra hörn.
2. Mät varje kandidats avstånd till närmaste befintliga anpassningspunkt.
3. Sortera avstånden fallande och lägg till kandidaten med störst avstånd.
4. Bygg om trianguleringen och upprepa.

Alla nytillkomna punkter ligger strikt inne i RGB-kuben. Startnätets ytor, kanter, hörn och gråpunkter behålls oförändrade. Metoden flyttar alltså förtätningsbudgeten till kubens inre. Den söker bland tetraedrarnas tyngdpunkter, inte kontinuerligt över hela kuben; därför garanterar den inte att varje ny punkt är centrum i det största möjliga tomrummet.

`parentTetrahedra` sparar de fyra föräldrapunkterna för varje nytt prov. `historyColumns` beskriver historikens kolumner och `sortedRefinementDistances` innehåller kandidatavstånden. `sortedEdges` och `sortedDistances` finns kvar som separat kantdiagnostik. Det tidigare kantdelningsalternativet kan anropas med `Refinement="edge"` för jämförelser och äldre experiment, men används inte av fönstrets förval.

Metoden är inspirerad av nätförfining, men är ingen FEM-lösare eller fysikalisk felestimator. Kandidatmängden ändras när trianguleringen byggs om; kandidatmaximum behöver inte minska vid varje tillägg. Symmetriska nät kan trianguleras olika mellan MATLAB-versioner. Punktfördelning, metodversion och föräldrarelationer sparas därför. Skillnader i RGB-avstånd är inte uppmätta färgfel.

### Separata täckningsmått

`coverage` beskriver avstånd till närmaste anpassningspunkt på ett fast nät med 33³ provlägen. Prov på kubens yta och strikt inuti redovisas separat med medelvärde, 95-percentil och undersökt maximum. Även antalet anpassningspunkter på ytan respektive inuti visas i dialogen. Detta är ett reproducerbart stickprovsmått, inte ett bevisat maximum över en kontinuerlig volym. Kontroller och upprepningar ingår inte som stöd i täckningsmåtten.

## Stoppvillkor

Algoritmen stannar när anpassningsbudgeten är förbrukad eller det största kandidatavståndet är högst den aktiva avståndströskeln. En otillräcklig budget ger ett tydligt fel före generering. API-parametern `MaxEdge` behåller sitt äldre namn av kompatibilitetsskäl, men avser kandidatavstånd i `Refinement="interior"`. I fönstret heter inställningen **Max interior gap**.

Vid aktiverad gapdetektion beräknas kvoten d(k)/d(k+1) i det initiala sorterade spektrumet av kandidatavstånd. Den största kvoten måste nå användarens gräns. Den lägre nivån d(k+1) blir då en fryst avståndströskel: kandidaterna ovanför nivån förtätas tills även det största kandidatavståndet når nivån, eller punktbudgeten tar slut. Om ingen kvot uppfyller villkoret används punktgränsen och eventuell manuellt angiven tröskel. Om båda trösklarna används gäller den större, alltså det villkor som nås först.

Att frysa nivån undviker att algoritmen hela tiden flyttar sitt mål till nya, mindre avstånd. Gapets kvot, index, övre/lägre nivå och om det användes lagras i JSON. Stopporsaken visas i fönstret. Detta första gapkriterium behöver jämföras med verkliga kontrollfel senare.

## Extra gråprov, kontroll och upprepningar

- Gråstegen läggs på R=G=B, förenas med kubnätet och dubbletter tas bort. Detta är styrvärdesgrå, inte bevis för neutral utskrift.
- Kontrollpunkterna kommer från en deterministisk sekvens med radikala inverser i baserna 2, 3 och 5. De väljs utanför anpassningsmängden och används aldrig till nätförfiningen. Detta är en enkel första kontrollfördelning, inte den slutliga perceptuella grå-/gamutkontrollen.
- Extra upprepningar kopierar ett jämnt urval av index i anpassningsmängden. De har egna prov-ID och `repeatOf`-referenser. Urvalet är ännu inte en optimerad fördelning mellan vitt, svart och olika kulörer.
- Definitionen sparar RGB som flyttal. TIFF16-kvantisering hör till det senare utskriftssteget.

Rollerna sparas som `fit`, `control` och `repeat`. Alla skrivs ut och mäts. **Profilbyggandet ska använda den sparade rollfilen för att skilja träning och kontroller.** En generell TI3 innehåller inte automatiskt denna policy. Nuvarande generella mätimport för inte automatiskt över designerrollerna; design-JSON måste bevaras och kopplas via den matchande layouten. Projektets iterationsflöde kopplar roller och kontrollerar dem före fortsatt profilering; fristående importer kräver rätt matchande underlag.

## Argyll-alternativet

Välj **Argyll OFPS** för att låta targen välja anpassningspunkterna. Samma totalbudget, kontrollmängdsstorlek och antal upprepningar används. Nätparametrarna stängs av i fönstret. Targen körs med print-RGB, åtta kubhörn, den valda grårampen och önskad anpassningsbudget. De faktiska argumenten och versionsinformationen sparas. Den genererade mängden analyseras med samma Delaunay-kantmått, men förtätas inte av InkProf.

Argyll-anropet sker synkront; ett avbrott registreras efter att det externa anropet lämnar tillbaka kontrollen. Det är inte samma omedelbara avbrott som mellan nätmetodens iterationer. Samma målantal innebär inte automatiskt samma färgkvalitet.

## Sparade filer och layout

Om fildialogen anger `mitt-mal.ti1` skapas endast:

- `mitt-mal.ti1`: matematiska RGB-punkter, utan mätvärden eller sidlayout.
- `mitt-mal.json`: namn, parametrar, roller, punkter, föräldrarelationer, historik, sorterade kantavstånd, stopporsak och källinformation. `definition.ti1SHA256` kopplar JSON till TI1.

Mesh- och Argyll-generering sparas på samma sätt. Ingen TIFF eller TI2 skapas. DPI, sidstorlek, randomisering och seed väljs i det separata TIFF16-fönstret. Öppna där den sparade TI1-filen och behåll JSON bredvid den så att nätinformationen kan återläsas med hashkontroll. Originalets definition och JSON ändras inte när en utskrift skapas.

TIFF16-fönstret skapar en ny paketmapp med TIFF16, TI2 och utskriftens JSON. TI2 hör till den faktiska sidlayouten. Designens flyttals-RGB behålls i definitionen; layouten innehåller RGB16-värdena. Den tidigare kombinerade funktionen `saveRGBDesign` finns kvar för äldre skript, men anropas inte längre från mesh-fönstret.

## Programanrop

```matlab
d=inkprof.designRGBTarget(Name="RGB-mesh-575", ...
    Levels=5, MaxPoints=575, GraySteps=33, ...
    ControlCount=64, RepeatCount=12, ...
    MaxEdge=0, GapRatio=0);

saved=inkprof.saveRGBDefinition(d, ...
    fullfile(paths.Projects,'RGB-mesh-575.ti1'));

% Separat, när du vill skapa utskriften:
window=inkprof.renderTarget(saved.ti1);
```

`Refine=false` ger startnätet utan förtätning. `Method="argyll"` väljer targen. Inga instrument startas.

## Verifiering

Automatiska tester kontrollerar bevarade startpunkter, mittpunktsrelationer, RGB-gränser, budget, stopp, upprepningsreferenser, åtskilda kontroller, sortering, avbrott, Argyll-alternativet, TIFF16/TI2/JSON-export och dialogens grundflöde. Fysisk mätning och jämförelse av profiler från nätmetoden respektive OFPS återstår.

Bakgrund: [utredning om RGB-täckning](../research/rgb-target-design.md). MATLAB:s [Delaunay-triangulering](https://www.mathworks.com/help/matlab/ref/delaunaytriangulation.html) ger tetraedernät och [edges](https://www.mathworks.com/help/matlab/ref/triangulation.edges.html) dess kanter. Gap- och förtätningspolicyn ovan är InkProfs egen prototyp.

## Genomfört geometriskt exempel

Ett historiskt prov med den tidigare kantdelningsmetoden (version 1.0) gav 153 initiala anpassningspunkter (5³ och extra gråsteg), 346 mittpunktstillägg och 499 slutliga anpassningspunkter. Med 64 kontroller och 12 upprepningar blev det 575 mätpositioner. Längsta nätkant minskade från 0,4330127 till 0,25. Stopporsaken var punktgränsen. Körningen tog cirka 6,8 sekunder inklusive uppdatering av dialogen på den aktuella datorn; detta är inte en plattformsoberoende tidsuppgift.

Exemplet har sparats lokalt under `projects/RGB-mesh-575-demo.*` och `projects/RGB-mesh-575-demo-files/`. Paketkontrollen passerade. Ingen fysisk mätning har gjorts av detta nya mål.

## Avbryt, spara och sidantal

**Cancel** stänger fönstret utan att spara. Under beräkning eller rendering begär knappen avbrott vid nästa säkra kontrollpunkt; ett pågående externt Argyll-anrop måste först återvända. Tillfälliga utskriftsfiler städas bort och inget nytt paket publiceras vid avbrott. **Stop generation** i nätfönstret avbryter däremot endast förtätningen och låter fönstret vara kvar.

Efter lyckad sparning stängs mesh-fönstret automatiskt utan att öppna utskriftsfönster. Vid sparfel ligger det kvar. Sidantal och förhandsvisning hör enbart till det separata TIFF16-steget.

## Jämförelse med 575 positioner, version 2.0

Samma budget (499 anpassning, 64 kontroll, 12 upprepning), startnät 5³ och 33 gråsteg. Tätheten nedan mäts mot 33³ provlägen; endast de 29 791 strikt inre provlägena ingår i inremåtten.

| Mått | Tidigare kantdelning | Inre förtätning |
|---|---:|---:|
| Anpassningspunkter på ytan | 246 | 98 |
| Anpassningspunkter inuti | 253 | 401 |
| Medelavstånd inuti | 0,07405 | 0,06641 |
| 95-percentil inuti | 0,11561 | 0,09882 |
| Undersökt maxavstånd inuti | 0,13975 | 0,12614 |
| Medelavstånd på ytan | 0,05974 | 0,06942 |

Detta verifierar avsedd omfördelning och bättre geometrisk täckning inuti för just denna budget. Det bevisar inte lägre ΔE eller universell överlägsenhet. Ingen tidigare sparad målfil ändras automatiskt.

## Val av inre placering, version 2.1

Fältet **Interior placement** ger tre val: **Centroids (default)**, **Sphere centers in tetrahedra** och **All interior sphere centers**. Argyll-läget stänger av valet.

Omsfärscentrum är punkten med samma avstånd till tetraederns fyra hörn. Det första sfäralternativet accepterar bara centrum inom den egna tetraedern. Det andra accepterar även centrum utanför sin tetraeder, förutsatt att det ligger strikt inne i RGB-kuben. Båda behåller tyngdpunkter som reservkandidater. I samtliga fall väljs största kandidatavståndet till närmaste anpassningspunkt.

API-valet är `InteriorPlacement="centroid"`, `"contained-circumcenter"` eller `"circumcenter"`. JSON sparar vald metod och `insertionKinds` för varje anpassningspunkt samt `candidateKinds` för slutliga kandidater. För omsfärscentrum identifierar `parentTetrahedra` den definierande sfärens fyra hörn.

Tyngdpunkter behålls som förval: de nya alternativen förbättrade inte alla täckningsmått. Se [resultat av jämförelsen](../research/interior-placement-comparison.md), inklusive ett oberoende prov med 100 000 slumpmässiga RGB-positioner.

## Planerad återkoppling från mätfel

Nästa etapp ska kunna koppla profilvalideringens ΔE00 och Lab-residualer tillbaka till enhets-RGB och nätversion, föreslå kompletteringar och behålla tidigare mätningar. Detta är ännu inte implementerat. [Plan och JSON-kontrakt](error-driven-refinement.md) beskriver separata profilrevisioner, permanent patchkoppling, mätvillkor, utvecklingsvalidering och låst slutkontroll. Den geometriska generatorn får inte beskrivas som felstyrd innan den kedjan finns.

## v1.0.0 project settings

Project details also records dye/pigment ink type, printer coating and coating settings. Matte paper can activate configurable extra dark patch sampling and shadow table emphasis. Read [matte shadow profiling](matte-shadow-profiling.md), [the current workflow](workflow-v1.0.md) and [gamut surface](gamut-surface.md). Certificates distinguish the saved build recipe from requested future patch counts.
