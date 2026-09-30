# Första implementationen: verifieringsrapport

Datum: 2026-09-25. MATLAB R2025b Update 7, ArgyllCMS 3.5.0 från `/usr/local/bin`. Implementation i `src/+inkprof`, tester i `tests/testTargets.m`. Ingen ChromIQ-kod har lästs eller återanvänts under denna implementation.

## Utfört

Slutkörningen passerade samtliga **tio testfall**, inklusive portabilitet och slädens breddgräns:

1. Verkliga PXF/TXF/TXT med 2033 patchar: värden, ID:n, upprepade färger, importerade layoutattribut och skalor.
2. XML med DTD/entitet respektive dubbla ID:n avvisas.
3. Felaktigt CGATS-radantal och otillräcklig RGB-skala avvisas.
4. Generering, samma randomisering vid upprepad export, bevarad ordning som alternativ, utfyllnadspatchar, skydd mot överskrivning och upptäckt av ändrad paketfil.
5. Import av hela TXF-targetet, flera sidor, koppling till original-ID, byteidentisk källkopia och verifiering efter flytt av paketet.
6. Fraktionella CGATS-värden, upprepade färger, citerade namn och sökvägar med blanksteg, apostrof och dollartecken.
7. Relativa sökvägar efter byte av aktuell MATLAB-katalog; Java user.dir får inte styra dem.

8. Hela kodpaketet kopieras till en annan katalog och konfigureras/körs därifrån, från en oberoende aktuell mapp. Lokal Argyll-konfiguration sparas separat och projektsökvägen följer den nya placeringen. Detta prov har passerat.
9. Sidbredd över 320 mm avvisas; en export vid gränsen kontrolleras inklusive marginaler och pixelavrundning.
10. Namngivna format A4-landscape (297 × 210 mm) och A3-portrait (297 × 420 mm) exporteras och pixelverifieras. Motstridiga formatval och okända format avvisas.

MATLABs kodanalys gav ingen felindikering; en preallokeringsrekommendation för den korta logglistan är inte ett funktionsfel.

## Kvarliggande exempelpaket

| Paket under `projects/` | Källpatchar | Argyll-utfyllnad | Sidor | TIFF |
|---|---:|---:|---:|---|
| first-generated-100 | 100 | 5 | 1 | RGB16, 300 dpi |
| first-imported-2033 | 2033 | 4 | 5 | RGB16, 300 dpi |

100-patchtargetet använder randomisering med frö 42. Det importerade targetet använder TXF-patchordningen och en ny Argyll-layout utan slumpning. Första och sista sidans förhandsvisningar i 2033-paketet har också inspekterats visuellt.

Samtliga patchars kontrollerade inre pixlar stämmer exakt med RGB16-koderna härledda från TI2: **0 kodnivåers avvikelse**. Detta omfattar även Argylls utfyllnad. Det genererade targetets största kvantiseringsavvikelse från källvärdena är 0,5 kodnivå; TXF-targetets heltalsvärden på 0–255-skalan kan representeras exakt i 16 bitar (numeriskt restfel cirka 7,3 × 10⁻¹² kodnivåer).

Körningens `verification.json` och `manifest.json` i respektive paket innehåller detaljer och filkontrollsummor. `projects/` är avsiktligt undantaget från Git; källkod, tester och denna rapport ligger i Git-projektet.

## Återstående praktiska prov

Fysisk utskrift och radmätning har inte utförts. En experimentell TXF-kandidat kan nu skapas för exakt 8-bitarsrepresenterbara paket, men mottagarens fysiska layout är inte verifierad. Begränsningarna markeras i manifest och utskriftsanvisning. En äldre eller ursprunglig TXF får inte användas för att mäta en ny eller omplacerad TIFF.

Se [köranvisningen](target-generation.md) för API, paketstruktur och nästa steg.


## Rättad mätriktning i 0.1.1

Projektägaren klargjorde att 321 mm inklusive marginaler gäller **längs mätraden**. Tidigare implementation hade lodräta Argyll-strips; en kontroll av sidbredden ensam uppfyllde därför inte behovet. Från 0.1.1 genereras native-kartan med omvända sidaxlar. Patch- och spacerpixlar transponeras utan omsampling, radbokstäver ritas rättvända till vänster och patchnummer överst. Nativefiler arkiveras separat i argyll/. Slutlig TI2 har samma datatabell som originalet och uppdaterad PAPER_SIZE.

Samtliga tio tester passerar efter ändringen. Testerna kontrollerar att varje strip ligger horisontellt, att patchnummer växer åt höger, att A ligger ovanför B samt att TIFF-pixlar och TI2 fortfarande överensstämmer. Gränsprovet använder nu 321 mm och avvisar 322 mm.

Två korrigerade paket har skapats och deras förhandsvisningar har granskats:

- `projects/import-A3-horizontal`: användarens senaste importerade 2033-patchtarget, seed 42, stående A3, tre sidor, fyra utfyllnadspatchar, cirka 297,011 mm total bredd.
- `projects/target-256-A4-horizontal`: befintliga 256 patchar, seed 42, liggande A4, en sida, sjutton utfyllnadspatchar, samma totalbredd.

Alla kontrollerade inre patchpixlar stämmer exakt med TI2:s 16-bitarskoder. Detta verifierar filkoppling och orientering, inte ännu fysisk radmätning. De äldre paketen har inte skrivits över.


## Uppdaterad storleksgräns i 0.1.2

Projektägarens slutliga mått är 320 mm horisontellt × 300 mm vertikalt inklusive marginaler. Det ersätter den tidigare 321 mm-gränsen och tillför en separat höjdgräns. Pappersformat och utskriven målstorlek hålls isär. A3-papper ger en mål-TIFF på cirka 297 × 300 mm, med oanvänd pappersyta vid utskrift i 100 %.

Alla tio tester passerar, inklusive båda maxgränserna, större valt papper och horisontell läsordning. Paketet `projects/import-A3-320x300` har 2033 originalpatchar och fyra utfyllnadspatchar på fyra sidor. Samtliga TIFF-sidor är 3508 × 3543 pixlar vid 300 dpi, dvs. 297,0107 × 299,974 mm. Patchpixlar och TI2 matchar exakt. Första sidans förhandsvisning har granskats. Tidigare paket är kvar som historik och ska inte användas som exempel på den nya höjdgränsen.


## Koordinater i 0.1.3

Kolumnerna märks A, B, C från vänster till höger och raderna 1, 2, 3 uppifrån och ned. Radnumren fortsätter över sidgränser. Argylls indexmönster har ändrats samtidigt: SAMPLE_LOC skrivs rad först, exempelvis 12C, medan JSON även innehåller den läsbara koordinaten C12.

Alla tio MATLAB-tester passerar. Nya paket är `projects/import-A3-ABC-123` (2033 patchar, fyra sidor) och `projects/target-256-A4-ABC-123` (256 patchar, en sida). Båda använder randomisering med seed 42. Förhandsvisningarna har granskats visuellt: A börjar till vänster och rad 1 överst. TIFF16 och TI2 har verifierats tillsammans. Storleksgränsen 320 × 300 mm inklusive marginaler kvarstår. Fysisk radmätning återstår att verifiera.


## Storleksgräns i 0.1.4

Maxmåttet ändras till 320 × 280 mm inklusive marginaler och ersätter tidigare höjdgräns 300 mm. Alla tio MATLAB-tester passerar. Nya verifierade paket: `projects/import-A3-320x280` (2033 patchar, fyra sidor) och `projects/target-256-A4-320x280` (256 patchar, en sida). Kolumner A, B, C från vänster och rader 1, 2, 3 uppifrån kvarstår. Första A3-sidans förhandsvisning har granskats visuellt.


## Generell CGATS-import/export

Fyra nya CGATS-tester passerar, tillsammans med targetsvitens tio tester efter byte till den gemensamma parsern. Verkliga i1Profiler-filer för M0/M1/M2 lästes, exporterades och lästes tillbaka med alla 2040 × 36 spektralvärden oförändrade. Patchdefinitionen med 2033 RGB-värden klarar export och återimport utan värdeförlust. Flera tabeller, okända metadata, upprepade nyckelord och ID:n, tomma strängar och Lab ingår i testerna. Felaktiga radantal, ofullständiga tabeller, dubbla våglängder, motsägande spektralmetadata och icke-finita färgvärden avvisas vid respektive strukturell/numerisk kontroll.

API: importCgats, exportCgats och cgatsData. Se cgats-import-export.md. Exporten behåller källans dialekt; konvertering mellan CGATS.17 och CTI3 är inte implementerad. Ingen fysisk mätning eller import av de nya exporterna i i1Profiler/ChromIQ har verifierats.


## TXF-prototyp

En separat experimentell exportör och ett flersidigt test har lagts till. Praktisk granskning i i1Profiler 3.8.5 bekräftade import av heltals-RGB men avvisade motsvarande decimalprov. Ett MATLAB-exporterat target kunde öppnas med i1Pro 2; Custom Paper Size krävde PaperFormat=0. Rutnätet räknades om och matchade inte InkProfs layout. Funktionen är därför inte mätgodkänd. Se i1profiler-txf-export.md för reproduktionsunderlag och kvarvarande arbete.

Den ensidiga 575-exporten skriver nu TIFF16, TI2, käll-CGATS, fysisk layout-CGATS, JSON-manifest och en TXF-kandidat när värdena kan representeras exakt. Automatiska kontroller visar 575 källpatchar exakt en gång, fem utfyllnadspositioner, 20 × 29 rutor samt identiska TIFF/TI2-värden. `chartread` läser TI2 som 29 steg per rad och 20 rader. Detta är strukturell verifiering; `physicalMeasurementVerified` är fortsatt `false`.

### Förnyat i1Profiler-prov med dongel

2026-09-25: mätsteget och återexport fungerar. Korrigerade procentfält bevarar 10 × 8 mm, men i1Profiler ändrar 21 × 29 till 24 × 26 (23 × 27 med 30 mm högermarginal). Befintlig Argyll-utskrift är fortfarande inte kvalificerad för i1Profiler-mätning. Se `i1profiler-txf-export.md`. Instrumentet rapporterades som ej anslutet.


### 2026-09-26: regressioner för 575-modellen

Modellens referensfiler ligger nu i `tests/fixtures/targets/chart-575/`, så testerna inte är beroende av den ignorerade lokala projektmappen. `testTiff16` provar RGB-skala 255 respektive 100 med identiska bildpixlar, `.tiff` och manifestkontrollsummor, 29 × 20-geometri, fem utfyllnadsfält, 2A-etiketten, misslyckad TXF-export utan publicerade delfiler, kollisionsskydd och CompactA4-layouten. Genererade statusfält är formatneutrala. Fysisk mätning är fortsatt ej verifierad.


### 2026-09-26: samma mall för flera sidor

575-begränsningen gäller nu endast det äldre referensordningsläget. Den generella tvåargumentsvägen i `createTiff16` renderar valfritt positivt antal patchar med 580 positioner per sida och fortsatt radindex. Testsvitens fem `testTiff16`-fall passerade, inklusive 2033 patchar på fyra sidor, 287 utfyllnadsfält, fyra återlästa TXF-kandidater, identisk randomisering med samma frö och ett litet target med sju patchar. TI2 använder kommaseparerad `PASSES_IN_STRIPS2`, samma struktur som befintliga Argyll-filer. Sidantal, RGB-pixlar och patchidentiteter kontrolleras på alla sidor. Ingen fysisk radmätning har genomförts.
