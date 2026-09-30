# TXF-export till i1Profiler: experimentell implementation

Status 2026-09-25: exportkod finns, och `createTiff16` kan lägga en experimentell `*-candidate.txf` bredvid den ensidiga 575-TIFF:en när RGB-värdena är exakt representerbara. **Samma utskrift är ännu inte kvalificerad för mätning i mottagarprogrammet.** Använd inte kandidatfilen som färdigt mätunderlag förrän dess importerade rutnät och ett praktiskt mätprov har verifierats.

Decimal-CGATS kan innehålla RGB16-värden som den testade heltals-TXF-varianten inte kan representera exakt. Då skapas ingen TXF-kandidat; paketets manifest förklarar precisionhindret. Ingen tyst avrundning görs.

## API

```matlab
paths = setupInkProf();
report = inkprof.exportTxfTarget( ...
    fullfile(paths.Projects,'import-A3-320x280'), ...
    fullfile(paths.Projects,'txf-kompatibilitetsprov'), ...
    Experimental=true);
```

Funktionen verifierar det befintliga utskriftspaketet och skriver till en ny separat katalog. Den ändrar varken TIFF, TI2 eller paketets manifest. Utan `Experimental=true` avbryts körningen.

En referens-TXF behövs för X-Rites privata Prism-struktur. Standard är `source/original.txf` i källpaketet; annars ange `Template='sokvag/till/referens.txf'`. Endast den observerade cc/xrp-serialiseringen stöds. Referensens övriga privata metadata och profilinställningar bevaras som mallinnehåll; de innebär ingen verifierad profilrekommendation. Mallen identifieras med SHA256 i rapporten.

Varje utskriftssida får en egen `page_NN.txf`, eftersom sista sidans radantal kan skilja sig. Alla faktiskt utskrivna patchar, även Argylls utfyllnad, tas med i ordning uppifrån och ned, vänster till höger. En separat JSON-karta sparar ursprungligt SAMPLE_ID, koordinat, sida, rad, kolumn, rektangel och RGB16. TXF-ID är lokala till respektive sida och får inte ensamma användas för att sammanfoga sidornas mätningar.

## Precision

För den prövade Prism-varianten måste RGB vara heltal 0–255. Exporten tillåter därför bara RGB16-koder som är exakt delbara med 257. Värden avrundas inte tyst. `inkprof:TXFPrecision` betyder att den befintliga utskriften inte kan beskrivas exakt med den provade varianten.

- Befintligt importerat 2033-target: alla patchar, inklusive utfyllnad, är exakt representerbara.
- Befintligt genererat 256-target: 242 patchar har minst en kanal som inte är exakt representerbar. Exporten avbryts.

Att TIFF är 16-bitars motsäger inte detta: en TIFF16 kan innehålla antingen 8-bitarsrepresenterbara eller finare RGB-styrvärden. Om ett framtida i1Profiler-flöde kvantiserar styrvärden måste det ske före generering av ett nytt sammanhängande TIFF/TI2/TXF-paket och innebära en ny utskrift.

## Praktisk granskning

I i1Profiler 3.8.5 öppnades användarens oförändrade PXF. Ett prov som behöll referensfilens struktur och använde 273 heltals-RGB-objekt öppnades också; programmet visade 273 patchar och rätt provnamn. Samma struktur med RGB-decimaler avvisades med ”Cannot load patch set file”. Kompakta initiala XML-prov avvisades också; det är inte belagt vilken ytterligare detalj i den kompakta strukturen som utlöste felet.

Programmet visade DEMO. Test Chart-försök gav ändrat filnamn men behöll den gamla geometrin; det räknas inte som lyckad layoutimport. Mätsteget var inaktivt. Användaren har tillfrågats om att återansluta licensdongeln. Original-PXF gick att öppna även i demoläget, så alla importfel får inte tillskrivas licensen.

## Kvarvarande verifiering

- Öppna den slutliga MATLAB-exporten i Test Chart och kontrollera att sidans rutnät och RGB verkligen används.
- Kontrollera objektordning mot sidans fysiska placering och hur i1Profiler namnger rader/kolumner.
- Fastställ hur Argylls färgade mellanrum ska hanteras. De observerade TXF-attributen beskriver inte godtyckliga separatorer mellan patchar. Patcharnas nominella mått räcker inte som bevis för samma fysiska karta.
- Verifiera randfält, marginaler, sista sida och utfyllnad. Programmet får inte generera om ordningen.
- Gör ett praktiskt radmätningsprov med i1Pro 2. Import och filkontroller är inte ett sådant prov.

Om Argylls layout inte kan uttryckas i i1Profiler krävs en gemensamt stödd layout och ny utskrift. Då ska InkProf tydligt skilja denna väg från att exportera mätunderlag för ett redan utskrivet ark.

## Slutligt importprov och kvarvarande layoutfel

Första sidan från MATLAB-exporten för 2033-targetet öppnades i Test Chart och identifierades som i1Pro 2 med 609 patchar. Referensmallens PaperFormat=16 fick programmet att använda Letter och två sidor trots angivna sidmått. Med PaperFormat=0 visades Custom Paper Size cirka 297 × 279,9 mm och en sida. Exportören använder därför nu 0.

**i1Profiler räknade ändå om rutnätet. Förhandsvisningen matchade inte InkProfs 21 kolumner × 29 rader.** Angivna NumberPatchColumns/Rows räcker alltså inte för att låsa den fysiska kartan. Filerna får inte användas för att mäta de befintliga utskrifterna. Det återstår att fastställa i1Profilers layoutregler och separatorhantering eller skapa ett nytt gemensamt target. Import är bekräftad för detta manuellt justerade prov, men exportören sätter fortsatt inga generella kompatibilitetsflaggor till true.

Kodtestet för flersidighet, läsordning, utfyllnad, RGB16-återläsning, krav på experimentflagga, precision och skydd mot överskrivning passerar. Ingen fysisk radmätning är utförd.

## Nytt prov med dongeln ansluten, 2026-09-25

Dongeln gjorde det möjligt att gå vidare till mätsteget och att spara ut både TIFF och TXF. Programmet rapporterade däremot `i1Pro 2 not found`; ingen fysisk mätning utfördes.

Återexport från i1Profiler 3.8.5 gav följande för första sidans 609 objekt:

| Prov | Patchmått efter återexport | Kolumner × rader |
|---|---|---|
| Anpassat papper, mallens procentvärden | 8,89 × 8,67 mm | 27 × 23 |
| Korrigerade procentvärden | 10 × 8 mm | 24 × 26 |
| Samma, med 30 mm högermarginal | 10 × 8 mm | 23 × 27 |
| InkProfs befintliga TIFF/TI2 | 10 × 8 mm | 21 × 29 |

609 RGB-objekt behöll sina värden och sin listordning i samtliga tre återexportprov. Det bevisar inte att deras fysiska positioner bevaras: i1Profiler räknar om rutnätet. Marginalprovet löste inte problemet.

För 10 × 8 mm i i1Pro 2-läget krävs även `PatchSizeWidthPercent=16.666666666666668` och `PatchSizeHeightPercent=0`. Exportören skriver nu dessa värden och begränsar den experimentella vägen till de verifierade patchmåtten. Nominella millimetervärden ensamma räcker inte. Mallens procentvärden avsåg ett annat instrument.

Argyll-targetets 1 mm färgade separatorer mellan patcharna är fortfarande inte representerade. En möjlig fortsatt undersökning är ett nytt gemensamt target utan separatorer (`printtarg -n`), med styrvärden kvantiserade före utskrift om i1Profiler kräver det. Detta är en oprövad väg och skulle kräva ny TIFF/TI2/TXF och ny utskrift.

De tillfälliga lokala proven i `work/` har rensats. Den maskinläsbara provsammanställningen och den dokumenterade slutsatsen finns kvar i versionshanterad dokumentation. Importhinder från demoläget är undanröjt; den kvarvarande begränsningen är layoutkompatibilitet samt praktisk instrumentverifiering. Exporten är fortsatt experimentell.

Efter korrigeringen passerade MATLAB-testet `testTxfExport` igen. Maskinläsbar provsammanställning med filhashar finns i `docs/research/i1profiler-interchange/licensed-txf-roundtrip-2026-09-25.json`.

## Ny kontroll av sidmallen 2026-09-26

`createTiff16`-kandidaternas kolumnordning har rättats efter import och bildåterexport. Fyra sidor matchar i RGB, patchstorlek och rutnät; mottagarens färgfält ligger dock 0,75 mm åt höger. Fysisk mätning återstår. Se [full verifiering](../research/i1profiler-interchange/txf-template-verification-2026-09-26.md). Äldre kandidater behöver genereras om.
