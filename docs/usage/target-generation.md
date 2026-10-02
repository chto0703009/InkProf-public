# Skapa ett target med InkProf 0.1.4

## Varning: externa utskrifter utan kontrastmarkörer

**Mål som skrivits ut utan kontrastmarkörer mellan patcharna kan ge problem vid radmätning med chartread**, särskilt när intilliggande patchar har snarlika färger. Det kan exempelvis ge fel om för få eller för många patchar. En korrekt importerad patchdefinition garanterar inte att det befintliga arket går att läsa tillförlitligt.

**Rekommenderat arbetsflöde:** importera patchdefinitionerna som TI1/TI2 i första hand, eller generell CGATS från ett annat program, och låt InkProf generera en ny TIFF16-utskrift med kontrastmarkörer och matchande TI2/JSON. Använd sedan just det nya utskriftspaketets TI2 vid mätningen. Kontrastmarkörer minskar risken för segmenteringsproblem men garanterar inte felfria svep.

En import eller omordning i programmet ändrar inte ett redan utskrivet ark. Om det befintliga arket mäts i ett annat program kan dess mätfil importeras separat med bevarad patchkoppling.


Första implementationen är ett MATLAB-API med två exportvägar. `createTarget` skapar generella Argyll-paket med TIFF16, TI1, TI2, geometribeskrivning och JSON. `createTiff16` använder en flersidig layoutmall med 580 positioner per sida med TIFF16, TI2, två CGATS-tabeller, JSON-kontroller och en villkorad TXF-kandidat. Ingen av funktionerna styr ännu ett mätinstrument eller skapar ICC-profiler.

## Val av importformat

**TI1/TI2 är förstahandsval. För RGB-patchdefinitioner från andra program rekommenderas generell CGATS när TI1/TI2 saknas.** CxF/PXF/TXF kvarstår som kompletterande alternativ. Ange RGB-skala för CGATS och kontrollera om filen faktiskt innehåller utskriftspositioner. Se [formatprioritering och begränsningar](cgats-import-export.md#rekommenderade-importformat-för-rgb-patchdefinitioner).

## Start

Kör från InkProf-mappen i MATLAB:

```matlab
paths=setupInkProf();
folder=fullfile(paths.Projects,'mitt-target');
inkprof.createTarget(folder, ...
    PatchCount=100, Randomize=true, Seed=42, DPI=300);
inkprof.previewTarget(folder);
```

Kräver MATLAB Base med Java och ArgyllCMS `targen`/`printtarg`. Provat med MATLAB R2025b Update 7 och ArgyllCMS 3.5.0 på macOS. Python, Image Processing Toolbox, SpectraLab och Camera-41 behövs inte för just targetdelen. Även mätning och framtida färgberäkningar ska vara självständiga från SpectraLab och Camera-41; interaktiv mätning använder InkProfs egen Python-brygga till Argyll. Ingen ChromIQ-kod används.

`setupInkProf` hittar källkod och projektmappar från sin egen plats. Koden kan därför flyttas eller klonas till en annan katalog. Funktionen lägger till `src` för den aktuella MATLAB-sessionen utan att ändra den globala sparade MATLAB-sökvägen. `examples/first_target.m` hittar också repot från scriptets egen plats och kan köras från en annan aktuell katalog.

Argyll hittas i ordningen: namngivna argumentet `ArgyllBin`, miljövariabeln `ARGYLL_BIN`, lokal konfiguration, datorns `PATH`, sedan vanliga macOS/Homebrew-kataloger. Ange annars den faktiska bin-katalogen:

```matlab
paths=setupInkProf(ArgyllBin='/usr/local/bin');
inkprof.createTarget(fullfile(paths.Projects,'annat-target'), PatchCount=200);
```

Datorspecifik verktygssökväg sparas i `local-config/settings.json`, som är Git-ignorerad. Ingen användarspecifik sökväg finns i MATLAB-koden. På en ny dator körs setup med den datorns Argyll-katalog, exempelvis `setupInkProf(ArgyllBin="C:\Tools\Argyll\bin")`. Windows `.exe` och sökvägar stöds av uppsättningen, men integrationstesterna är hittills endast körda på macOS. `SaveLocalConfig=false` gör uppsättningen utan att skriva konfigurationsfil; ange då `ArgyllBin=paths.ArgyllBin` vid export om katalogen inte redan kan hittas. `inkprof.paths()` visar aktuella mappar.

Kod och data flyttas separat: Git-projektet innehåller koden; `projects/` innehåller lokala utskriftspaket och måste kopieras eller säkerhetskopieras separat. Varje sådant paket har relativa interna filreferenser och sina egna källdata. Versions- och ursprungssökvägar i manifestet är proveniens, inte krav på att den gamla datorn eller platsen finns kvar.

## Importera PXF-, TXF- och CGATS-definitioner

```matlab
inkprof.createTarget('projects/gammal-patchlista-ny-karta', ...
    Source='tests/fixtures/i1profiler/chart-2033/Chart 2033 Patches.txf', ...
    Randomize=false, DPI=300);
```

PXF och TXF läses som RGB-patchlistor i den granskade CxF3/Prism-varianten med `ObjectType="Target"` och `ColorSpecification="Unknown"`. RGB-skalan är 255 för denna variant. Andra XML-färgspecifikationer avvisas tills de fått en verifierad adapter. Layoutattribut arkiveras, men **den gamla TXF-kartan reproduceras inte**. Utskriften får en ny Argyll-layout.

För den observerade i1Profiler-layouten med 575 patchar på en liggande A4-sida kan den kompakta Argyll-layouten väljas uttryckligen:

```matlab
inkprof.createTarget('projects/chart-575-A4', ...
    Source='Chart 575 Patches.pxf', CompactA4=true, ...
    Randomize=false, DPI=300);
```

Valet använder långstripsläge, ingen yttre marginal och en kompakt i1Pro-skala. För 575 patchar ger det 20 rader och 29 kolumner på en TIFF. Det är fortfarande en ny Argyll-layout; fysisk kompatibilitet med i1Profilers karta är inte verifierad.

## Återanvändbar sidmall för valfritt patchantal

575-targetet är förebild för formateringen, inte en begränsning av antalet patchar. `createTiff16` använder samma mall för PXF, TXF, TI1 och RGB-CGATS:

```matlab
paths=setupInkProf();
info=inkprof.createTiff16( ...
    fullfile(paths.Projects,'mitt-target.ti1'), ...
    fullfile(paths.Projects,'utskrift.tif'), ...
    DPI=300,Randomize=true,Seed=42);
```

Mallen har 29 kolumner × 20 rader med 8 × 8 mm patchar, stödlinjer, kolumner A–Z och 2A–2C samt 263 × 195 mm bildyta. Rubriken är InkProf RGB, centrerad i 20 punkter. Datum och tid står nere till vänster och sidnummer, exempelvis `1 (4)`, nere till höger. Radnumren fortsätter över sidgränser: 1–20, 21–40, osv.

- 575 patchar → en sida, fem utfyllnadsfält.
- 2033 patchar → fyra sidor, 287 utfyllnadsfält på sista sidan.
- Annat antal → så många fulla mallsidor som behövs. Högst 49 sidor med nuvarande TI2-radindex.

Standard är källordning. `Randomize=true` använder ett lokalt slumpflöde med sparat `Seed`; samma slutordning används i alla format. Utfyllnad är grå, markeras `isPadding` och är inte en källpatch. Den generella vägen fyller i radordning och lägger utfyllnaden sist. Ingen referensbild krävs.

Första TIFF-filen använder valt namn, till exempel `utskrift.tif`; följande heter `utskrift_02.tif` osv. En gemensam `utskrift.ti2` beskriver samtliga sidor. JSON och fysisk CGATS anger sida, rad och patchkoppling. Manifestet listar alla TIFF-filer och kontrollsummor. `info.tiffs` ger de fullständiga filsökvägarna.

CGATS kräver explicit `RGBScale`. Både `.tif` och `.tiff` stöds. TIFF16-värden kontrolleras mot TI2 på samtliga sidor. Om en kompatibel XML-mall finns kan en experimentell TXF-kandidat skrivas per sida, men mottagarlayout och fysisk mätning återstår att verifiera. MXF skapas först efter mätning.

Det äldre anropet med tre positionsargument `(source, reference, output)` finns kvar för att exakt återskapa det ursprungliga 575-targetets färgordning och fem utspridda utfyllnadsrutor. Det läget kräver 575 patchar och tillåter inte randomisering. För nya target används tvåpositionsanropet ovan.


TI1 kan importeras på samma sätt. RGB-CGATS-TXT kräver uttrycklig skala:

```matlab
target=inkprof.importTarget('Chart 2033 Patches.txt', RGBScale=255);
inkprof.createTarget('projects/precisionsvariant', ...
    Source='Chart 2033 Patches.txt', RGBScale=255);
```

Läsaren stöder första tabellen med SAMPLE_ID och RGB_R/G/B samt valfri SAMPLE_NAME. TI1 har skalan 100. Skalan härleds aldrig från observerat maxvärde. Dubbla RGB-värden behålls; dubbla eller tomma ID:n avvisas. Externa XML-entiteter/DTD tillåts inte.

## Val

Aktuella måttgränser och ändringsbara förslag hämtas från projektets JSON. Se [pappersförslag och mätsläde](target-paper-planning.md). Äldre fasta gränser på 320 × 280 mm gäller inte nya paket.

```matlab
paths=setupInkProf();
inkprof.createTarget(fullfile(paths.Projects,'target-256-A4L'), ...
    PatchCount=256, Paper="A4-landscape", Randomize=true, Seed=42, DPI=300);
inkprof.createTarget(fullfile(paths.Projects,'target-256-A3P'), ...
    PatchCount=256, Paper="A3-portrait", Randomize=true, Seed=42, DPI=300);
```

Ange antingen `Paper` eller egna `PaperSizeMm`, inte båda. Utan formatval används stående A4 som tidigare. Samma redan genererade patchlista kan få en ny layout genom `Source` med dess TI1-fil.

| Argument | Standard | Betydelse |
|---|---|---|
| PatchCount | 100 | `targen -f`, begärt totalt antal vid generering; verkligt antal registreras |
| GraySteps | 9 | `targen -g`, lika RGB-styrvärden längs gråaxeln, ingen garanti för neutral utskriftsfärg |
| WhitePatches / BlackPatches | 4 / 4 | Upprepningar vid generering |
| Paper | A4-portrait | A4-landscape eller A3-portrait är de två bredare valen |
| PaperSizeMm | Valfritt | Egen [bredd höjd] i mm, alternativ till Paper |
| MarginMm | 10 | `printtarg -M`, marginal inkluderad i TIFF |
| DPI | 300 | 72–1200, TIFF16 per RGB-kanal |
| PatchScale / SpacerScale | 1 / 1 | Argylls `-a` och `-A`, instrumentberoende skalning |
| CompactA4 | false | Kompakt ensidig 20 × 29-layout för 575 patchar på liggande A4; sätter papper, marginal och skalning |
| Randomize | false | `false` bevarar patchlistans ordning i den nya layouten; `true` använder printtarg |
| Seed | 1 | `printtarg -R` när randomisering är vald |
| TimeoutSeconds | 120 | Tidsgräns per process |

Första stödda geometrin är Argylls **`-ii1`**, i1Pro-familjens rektangulära radlayout. Programmet tillåter ännu inte andra instrumentgeometrier. En befintlig Scramble-flagga i TXF aktiverar inte automatisk omslumpning. Välj `Randomize=true` uttryckligt för en ny slumpad karta.

Aktuella måttgränser och ändringsbara förslag hämtas från projektets JSON. Se [pappersförslag och mätsläde](target-paper-planning.md). Äldre fasta gränser på 320 × 280 mm gäller inte nya paket.

## Det generella `createTarget`-paketet

- `source/`: oförändrat importoriginal eller genererad TI1.
- `target.ti1`: numeriska SAMPLE_ID 1…N, med koppling till original-ID i JSON. Argylls extra hjälptabeller skapas av `targen`.
- `target.ti2`: faktisk layout och kvantiserade RGB-värden från samma printtarg-körning som bilderna.
- `target*.tif`: utskriftssidor, RGB uint16. Bilderna har fysisk upplösning; automatisk omskalning ska stängas av vid utskrift.
- `argyll/`: oförändrade TI1/TI2/TIFF/CHT-mellanfiler från Argyll. Dessa har den ursprungliga lodräta orienteringen och ska inte skrivas ut. InkProf använder geometrin för att kontrollera den slutliga horisontella kartan.
- `target.json`: original-ID, namn, källvärden, skala, procentvärden, uppskattad XYZ och importerade layoutattribut.
- `layout.json`: varje TI2-position med original-ID, sida, strip, patchnummer i strip, rektangel i mm och RGB16. ID 0 är Argylls utfyllnad, inte en originalpatch.
- `manifest.json`: schemaversion, inställningar, verktygsversioner, argument, kontrollsummor och kompatibilitetsstatus.
- `verification.json`: verifieringsresultat.
- `target*-preview.png`: mindre skärmförhandsvisningar, inte utskriftsunderlag.
- `PRINTING.txt`: utskriftsanvisningar och begränsningar.

JSON är ett mellanformat. TI1 och TI2 är primära Argyll-underlag. TIFF16 återställer inte precision som saknas i ett importerat heltals-RGB-target. Vid ny TI1 utan egna XYZ används tydligt märkta sRGB/D65-uppskattningar enbart för layout/igenkänningsheuristik; inga RGB-styrvärden färgkonverteras. Uppskattningarna beskriver inte den verkliga skrivaren.

## Kontroller och reproducerbarhet

```matlab
report=inkprof.verifyPackage('projects/mitt-target');
```

Varje källpatch måste förekomma exakt en gång i TI2/CHT-kopplingen, även när färgvärden upprepas. Alla pixlar i den centrala halvan av varje rektangulär patch kontrolleras mot TI2:s RGB16-kod, även utfyllnad. Källvärden får avvika högst en halv 16-bitars kvantiseringsnivå (med liten numerisk tolerans). Sidmått, bitdjup och filkontrollsummor kontrolleras. CHT-rutor och TI2-positioner måste matcha entydigt.

Paketet skrivs först i en tillfällig grannmapp och flyttas till valt namn efter godkända kontroller. Befintliga paket skrivs inte över. Alla nödvändiga targetdata ligger i paketet; det kan flyttas. Ursprunglig extern sökväg sparas endast som proveniens och behövs inte för verifiering. Manifestet är en integritetskontroll, inte en digital signatur.

Slumpfrö och version bevaras tillsammans med faktisk patchmappning. För exakt återanvändning ska färdiga paket arkiveras: samma genereringsinställningar ensamma lovar inte identiska filer över verktygsversioner eller tidsstämplar.

## Kvar innan mätkompatibiliteten är klar

I det generella `createTarget`-paketet kommer TI2 och nativ TIFF/CHT från samma Argyll-körning. Den slutliga TIFF-bilden använder transponerade patch-/spacerpixlar utan omsampling, och rättvända kolumnbokstäver och radnummer ritas i det vita området. Patch-ID, SAMPLE_LOC, stripptillhörighet, RGB och läsordning är oförändrade; TI2:s PAPER_SIZE uppdateras till slutlig orientering. Native CHT avser endast native-bilderna i `argyll/`, inte de slutliga TIFF-filerna. InkProf verifierar de transformerade positionerna mot slutlig TIFF. Fysisk utskrift och radmätning med `chartread` återstår.

Det ensidiga 575-paketet från `createTiff16` använder i stället sin dokumenterade referensgeometri och skriver matchande TI2/CGATS/JSON direkt. En `*-candidate.txf` kan skapas där utan precisionstapp, men kandidatens mottagarlayout och fysiska mätning är inte verifierade. En äldre eller ursprunglig TXF får aldrig användas för att mäta en ny layout.

Mätning, MXF/CMXF-import, spektrala beräkningar, ICC-generering och ett fullständigt GUI tillkommer senare. `previewTarget` ger redan en enkel sidöversikt i MATLAB.

## Tester

```matlab
results=runtests('tests/testTargets.m');
assertSuccess(results);
```

Tester använder de verkliga 2033-patchfilerna, ett genererat target, upprepade färger, fraktionella styrvärden, flera sidor, randomisering, förflyttat paket, felaktiga filer och ändrade kontrollsummor. Argyll måste vara tillgängligt även vid integrationstesterna.

Argylls externa verktyg och deras genererade hjälptabeller används; ingen Argyll-binär distribueras i InkProf.

## Mätriktning och koordinater från 0.1.1

Aktuella måttgränser och ändringsbara förslag hämtas från projektets JSON. Se [pappersförslag och mätsläde](target-paper-planning.md). Äldre fasta gränser på 320 × 280 mm gäller inte nya paket.

Tidigare paket från 0.1.0 hade lodräta strips och måste genereras om för detta flöde; att vrida en skärmförhandsvisning är inte en rättelse av utskriftspaketet. Skriv endast ut target*.tif i paketets rot. Native mellanbilder i argyll/ ska inte skrivas ut.

### Koordinatkontrakt från 0.1.3

Argyll får numeriska stripindex (`-x0-9,@-9,@-9;1-999`) och alfabetiska patchindex (`-yA-Z, A-Z`). TI2 behåller Argylls `INDEX_ORDER STRIP_THEN_PATCH`, så exempelvis rad 12, kolumn C skrivs `12C` i SAMPLE_LOC. I layout.json finns samma råa `location`, samt `column="C"`, `strip="12"` och användarkoordinaten `coordinate="C12"`. Den skillnaden i skrivordning är explicit; det är samma patch och samma fysiska läsordning. Ingen fristående omnumrering görs efter randomisering.


## Experimentell TXF-kompatibilitet

`createTiff16` kan skapa `*-candidate.txf` för den ensidiga 575-layouten när alla RGB16-värden är exakt representerbara i den testade TXF-varianten. `exportTxfTarget` finns för separata experiment med generella Argyll-paket. Ingen av vägarna är kvalificerad för mätning av en befintlig utskrift förrän mottagarens faktiska rutnät och ett fysiskt mätprov har verifierats. Se [TXF-status](i1profiler-txf-export.md) och [första leveransens acceptanskrav](../planning/first-delivery-target-tiff16.md#nästa-komplettering-txf-för-mätning-i-i1profiler).


## Uppdatering 2026-09-26: fast 575-modell och neutrala namn

575-modellen behåller referensens 29 × 20 positioner, fem utfyllnadsfält, 8 × 8 mm patchar, stödlinjer och 263 × 195 mm bildyta. Kolumnerna är A–Z, 2A–2C och raderna 1–20. Bildrubriken identifierar InkProf, 575 patchar och datum. Källfilens namn och identitet finns i manifestet.

`createTiff16` normaliserar nu RGB-skalan vid referensmatchning och accepterar både `.tif` och `.tiff`. Paketet byggs och verifieras i en tillfällig grannmapp. Först efter godkänd kontroll publiceras filerna; befintliga filer skrivs inte över. Vid ett vanligt publiceringsfel tas filer publicerade av samma anrop tillbaka. Detta är inte en garanti för atomisk publicering vid strömavbrott eller processkrasch.

Publika statusfält heter nu `receiverLayoutVerified` och `receiverImportVerified`. Äldre sparade rapporter behåller sina tidigare fältnamn. Import/export av standardformat behålls; historiska referenser och formatens tekniska identifierare ändras inte.

Maskinspecifik konfiguration ska sättas på respektive dator med `setupInkProf(ArgyllBin="...")`. Den här datorn använder `/usr/local/bin`. `local-config` ska inte överföras från en dator med annan installation.

## RGB-avgränsning

Targetimport och TIFF16-utskrift begränsas till RGB. Rubriken börjar med `INKPROF RGB` på varje sida i både sidmallen och den generella Argyll-vägen. Ändringen gäller nygenererade paket; befintliga utskriftsfiler ändras inte. CMYK-target ingår inte.

CMYK i targetdefinitioner avvisas med `inkprof:ColorFormat` och meddelandet ”Fel färgformat: InkProf stöder endast RGB-target.” Kontrollen gäller XML-baserade target och CGATS/TI1. Den generella CGATS-läsaren kan fortfarande bevara CMYK-mätdata som utbytesdata; detta ger inte stöd för CMYK-target eller CMYK-utskrift.

## RGB-underlag för senare mätning med i1Pro 2

Export av target och mätunderlag kontrollerar tre RGB-kanaler och rätt numerisk skala före skrivning. Fyrkanalsdata avvisas med `inkprof:ColorFormat`; ingen CMYK→RGB-konvertering görs.

- **TI2:** gemensam patchdefinition för Argyll `chartread`, med samma RGB, ordning och sidindelning som TIFF16. Efter mätningen erhålls TI3. Fysisk mätning av mallen återstår att prova.
- **TXF:** experimentell kandidat per sida för mottagarprogrammets Test Chart-import. Sidmallens kandidat anger nu i1Pro 2 och procentparametrarna för 8 × 8 mm; detta behöver fortfarande verifieras i mottagaren och med instrument. Importbar XML är inte en garanti för identisk fysisk layout.
- **CGATS:** källtabell och fysisk patchtabell för datautbyte, inklusive sida/rad/utfyllnad. Generell CGATS är inte automatiskt ett färdigt instrumentstyrningsformat eller en ersättning för TXF/TI2.

Den generella dokumentfunktionen `exportCgats` bevarar fortfarande importerade CGATS-dokument, även sådana som innehåller CMYK-mätdata. RGB-begränsningen gäller när den exporterar ett InkProf-target och när utskriftens mätunderlag skapas. Detta bevarar möjligheten till förlustfritt datautbyte utan att tillåta CMYK-target i utskriftsflödet.

## Kontrastfält i Argyll-layout

`createTarget(...,SpacerMode="colored")` skickar `printtarg -c`. Övriga värden är `auto` (standard), `bw` (-b) och `none` (-n). `SpacerScale` styr -A. Ändrad layout kräver ny utskrift och matchande TI2. Kontrastprovet `projects/test-575-kontrast-rad13-17` använder problemfärger från den tidigare 575-utskriften; det är ett separat target med nya radnummer.

## Utskriftsstandard

Se [InkProf – standard för utskrift av mål](target-print-standard.md) för rubrik, datum/tid, sidnummer, rad- och kolumnetiketter, fysiska mått och mätunderlag. Det dokumentet samlar den gemensamma standarden för båda utskriftsrutinerna.

## Ny utskrift från TI2

`createTarget(folder,Source="original.ti2",Paper="A4-landscape",SpacerMode="colored")` importerar RGB-patcharna från en validerad CTI2. RGB-skalan är 0–100. SAMPLE_ID 0 är utfyllnad och förs inte över som källpatch. Övriga identiteter, RGB och eventuell uppskattad XYZ behålls; XYZ i TI2 är inte mätvärden. Ursprungliga positioner, metadata och hjälptabeller bevaras i `target.json` under `sourceLayout`, och originalfilen arkiveras under `source/`.

En ny layout skapas för utskriften med nya positioner och vid behov ny utfyllnad. Använd paketets nya `target.ti2` vid mätning av den nya utskriften. För att mäta ett redan utskrivet original används i stället `prepareChart` med originalets TI2, utan omlayout.
