# Gemensam targetinformation i JSON och TIFF

Infört 2026-09-26. Import och generering använder samma toppnivåfält: **`targetInfo`**. Det gäller importerade PXF/TXF/CxF, TI1, TI2 och RGB-CGATS samt mål från Argyll och InkProfs nätförfining. Äldre filer skrivs inte om automatiskt.

## Gemensam struktur

- `schemaVersion`: metadataformatets version.
- `source.fileName`, `source.path`, `source.format`, `source.sha256`: källfilens ursprungliga namn, fullständiga sökväg, format och kontrollsumma. De ersätts inte av renderingsstegets tillfälliga filnamn. Före första sparning av ett eget mål saknas en fysisk källfil; vid sparning registreras den slutliga TI1-filen.
- `source.declaredMetadata`: uppgifter som faktiskt finns i källans CGATS-huvud eller XML-attribut. De hålls åtskilda från beräknade nätmått.
- `generation.method` och `generation.settings`: känd metod och parametrar. En vanlig import får `unknown` som metod om den inte kan beläggas. En filändelse bevisar inte genereringsalgoritmen.
- Egna nätförsök sparar också initialnivåer, ursprungligt nät, föräldrarelationer, iterationshistorik, gapvillkor och stopporsak under `generation`. Argyll-körningar sparar sina argument/versioner när de finns.
- `patchCount`, `uniqueRGBCount`: källpatchar och unika RGB. Layoutens utfyllnad ingår inte. Jämförelsen av unika färger använder tolv decimaler i normaliserat RGB.
- `network`: omfattning (`scope`), punktantal, unika punkter, affin dimension, antal kanalnivåer, om hela den kartesiska produkten finns och om kanalstegen är likformiga, antal kubhörn och diagonalgrå, samt antal Delaunay-kanter, största och genomsnittlig kantlängd. Ett rent gråmål är endimensionellt och får inga påhittade tredimensionella nätmått. För egna designer beräknas nätmåtten på anpassningspunkterna, utan kontroll och upprepning.
- `footerText`: den korta sammanfattning som renderas i TIFF.
- `upstream`: tidigare metadata när en återimport har ett tillhörande InkProf-design-JSON vars filhash stämmer. Metod och roller från ett sådant underlag bevaras; nätmåtten beräknas för de faktiskt importerade RGB-värdena. En identifierad men felmatchad sidecar avvisas.

Geometriska RGB-avstånd är inte uppmätta färgfel eller ΔE. Standardfältet säger inget om en okänd källfil faktiskt genererades med ett regelbundet nät.

## Var samma fält finns

`targetInfo` används i importens targetstruktur, `target.json`, renderingspaketets layout-JSON och manifest, designerfönstrets sparade JSON och nyskapad `chart.json`. Mätimport för sedan vidare fältet om sessionens chart-JSON har det. En verifieringsrapport behöver inte duplicera denna beskrivning.

TI1/TI2-filerna behåller respektive standardformat. Vid direkt återimport av en sparad designer-TI1/TI2 kontrolleras filhashen mot motsvarande `<namn>.json` innan genereringsmetadata används. Att en fristående fil saknar denna sidecar är inte ett fel: dess faktiska RGB och deklarerade metadata används, men okänd genereringshistorik hittas inte på.

## TIFF-sidfot

Ovanför den fullständiga TIFF-sökvägen står en centrerad sammanfattning:

`Source: Chart 575 Patches.pxf | imported PXF | 575 patches / 569 unique | RGB edge max …`

För nätförfining tillkommer startnät och antal tillägg, exempelvis `start 5^3, +346`. Detaljerna kan inte alla rymmas på papper; de finns i `targetInfo`. Informationsraden är normalt 7 punkter och anpassas ned till 6 om det behövs. Text kapas inte tyst; en alltför lång rad ger ett tydligt fel.

Informationsraden centreras cirka 8,8 mm från nederkanten. Sökväg, datum och sidnummer ligger cirka 3,5 mm från nederkanten. Sökvägen kan radbrytas till två rader. Argyll-renderingen reserverar 12 mm nedtill. Den fasta sidmallen behåller sina patchpositioner och bildmått; texten måste rymmas i dess befintliga marginal. All text kontrolleras mot befintliga bildpixlar före publicering.

Både `createTarget` och `createTiff16` använder samma metadatafält och formatteringsrutin. Nya utskrifter måste alltid mätas med sitt eget TI2-underlag.

Separat sparade nätdefinitioner använder `definition.ti1SHA256` i design-JSON. Äldre kombinerade paket med `print.ti1SHA256`/`print.ti2SHA256` kan fortfarande läsas. Vid rendering arkiveras även den verifierade design-JSON-filen bredvid källans TI1, så att roller och fullständig näthistorik finns kvar i utskriftspaketet.

## Planerad återkoppling från mätfel

Nästa etapp ska kunna koppla profilvalideringens ΔE00 och Lab-residualer tillbaka till enhets-RGB och nätversion, föreslå kompletteringar och behålla tidigare mätningar. Detta är ännu inte implementerat. [Plan och JSON-kontrakt](../planning/error-driven-refinement.md) beskriver separata profilrevisioner, permanent patchkoppling, mätvillkor, utvecklingsvalidering och låst slutkontroll. Den geometriska generatorn får inte beskrivas som felstyrd innan den kedjan finns.
