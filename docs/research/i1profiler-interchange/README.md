# Datautbyte mellan i1Profiler, InkProf och ChromIQ

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Datum: 2026-09-25. Status: underlag för implementation, inte implementerat formatstöd.

## Syfte och avgränsning

InkProfs [formatbeslut 004](../../decisions/004-argyll-primary-json-intermediate.md) anger JSON som intern modell och TI1/TI2/TI3 som primära utbytesformat. Dessa i1Profiler-kontrakt beskriver adaptrar till och från det arbetsflödet.

InkProf ska kunna återanvända target och mätningar från andra program och exportera data tillbaka. Import och export ska skilja mellan att bevara mätinnehåll och att återskapa ett programs hela arbetsflöde. En fil som går att öppna är inte automatiskt en förlustfri konvertering.

Detta paket innehåller fyra formatbeskrivningar:

- [PXF: patchuppsättning](pxf.md)
- [TXF: target och layout](txf.md)
- [MXF: styrvärden och mätningar](mxf.md)
- [CMXF: mätningar av ett target](cmxf.md)

De är praktiska läs-/skrivkontrakt för InkProf, inte fullständiga officiella X-Rite-specifikationer. **Källbelagt** betyder att uppgiften stöds av angiven dokumentation; **kodobserverat** avser den granskade ChromIQ-versionen; **föreslaget** anger hur InkProf bör fungera. En första [praktisk verifiering i i1Profiler 3.8.5](ui-verification-3.8.5.md) har nu gjorts: MXF-import, spektral CGATS-export och TIFF-export. InkProf-genererade filer har ännu inte kompatibilitetstestats.

Ett verkligt [referensfall med 2 033 patchar i PXF och CGATS-TXT](chart-2033-inspection.md) har granskats och visar en precisionsskillnad mellan filerna. Även [motsvarande TXF har nu granskats](chart-2033-txf-inspection.md): samma patchvärden som PXF, kompletterade med layoutparametrar. Fullständig fysisk rendering och mätkompatibilitet återstår att verifiera.

## Gemensam grund: CxF3

Mätimporten har nu även [tre granskade MXF-referensfall](mxf-examples-inspection.md). De visar både spektrala och enbart kolorimetriska data samt faktisk platsinformation för patchkoppling. Full export-/återimportverifiering återstår.

X-Rite publicerar CxF3:s XML-schema och dokumentation. Kärnan organiserar färgobjekt och deras värden i `Resources`. `CustomResources` använder egna namnrymder och kan tillföra programspecifik betydelse. XML-prefixet, exempelvis `cc`, är valfritt; namnrymdens URI och elementnamnet identifierar elementet. [S1, S2]

Exempel på namn som förekommer i underlaget är `CxF`, `ObjectCollection`, `Object`, `DeviceColorValues`, `ColorRGB`, `ColorValues`, `ReflectanceSpectrum` och `ColorSpecification`. Detta är en läskarta, inte ett komplett XSD. En hänvisning till en färgspecifikation behöver lösas innan skalor, våglängder eller mätvillkor tolkas. [S2, S3]

CxF3:s öppna kärna innebär inte att alla i1Profiler-tillägg är fullständigt offentligt specificerade. BabelColors AN-10 beskriver de fyra filrollerna, men bygger delvis på observationer och gäller äldre i1Profiler-versioner. Fullständigt stöd måste därför styrkas med versionsmärkta referensfiler. [S4]

## Föreslagen intern representation

Beräkningar mellan spektra, XYZ, Lab och andra representationer beskrivs separat i [återanvändning av färgberäkningar från SpectraLab och Camera-41](../colorimetry-reuse-camera41-spectralab.md). Filadaptrarna ska inte införa egna parallella färgberäkningar. Beräkningsrutinerna ska ingå i InkProf, utan körberoende till de andra projekten.

Följande namn är InkProfs föreslagna interna begrepp, inte XML-taggar eller externa API-kontrakt.

| Del | Information att bevara |
|---|---|
| Ursprung | Originalfil, kontrollsumma, producent, version, datum och importlogg. |
| Patch | Intern identitet, ursprungligt ID, namn och ordningsnummer. |
| Styrvärden | Kanalnamn, kanalordning, ursprunglig skala och normaliserade värden. |
| Layout | Sida, rad, kolumn, läsriktning, dimensioner och eventuell randomisering. Okänt anges som okänt. |
| Mätning | Koppling till patch, eget mät-ID, datum, instrument och upprepningsnummer. |
| Spektrum | Våglängdsvektor i nm, värden, storhet och skala. |
| Kolorimetri | XYZ/Lab samt belysning, observatör, normalisering och uppmätt/härlett ursprung. |
| Mätvillkor | Exempelvis M0/M1/M2/M3, geometri och XRGA/GMDI där det faktiskt framgår. |
| Utökningar | Oförstådda metadata och XML-resurser samt deras referenser till objekt. |

Flera mätvillkor och upprepningar ska lagras som separata mätningar. Samma RGB-värde kan förekomma på flera patchar: RGB-trippeln är därför ingen unik nyckel.

## Föreslagna konverteringsvägar

| Från | Till | Villkor och möjliga förluster |
|---|---|---|
| PXF | TI1 | Bevara patchar och styrvärden. Eventuella extra Argyll-tabeller genereras av ett verifierat verktygsflöde. |
| TI1 | PXF | Kodning och avrundning väljs uttryckligt för mottagaren. Uppskattad kolorimetri får inte bli mätdata. |
| TXF | TI2 | Kräver en verifierad översättning av layout och instrumentrelaterad information. Annars skapas ett nytt target; det gamla får inte användas för radmätning med den nya layouten. |
| TI2 | TXF | Kräver mer än en lista med RGB-värden; målprogrammets layout måste verifieras. |
| MXF | TI3 | Para styrvärden och mätningar säkert; exportera spektra när de finns. Separera mätvillkor vid behov. |
| TI3 | MXF | Kräver kända skalor, metadata och en utprovad i1Profiler-variant. Saknade spektra kan inte återskapas från XYZ/Lab. |
| CMXF + känt target | TI3/MXF | Kräver verifierad koppling till targetets styrvärden. |
| TI3/MXF | CMXF | En mätdataexport; styrvärdenas koppling måste sparas separat om den ska kunna återställas. |

Se även [Argyll-formaten](../argyll-ti1-ti2-ti3.md) och [CGATS](../cgats-format.md). Tabellen är InkProfs planerade beteende, inte en garanti för befintliga konverteringsverktyg.

## Gemensamma regler för läsning och skrivning

1. Identifiera XML-variant, namnrymd och datainnehåll; lita inte enbart på filändelsen. XML-läsaren ska inte hämta externa entiteter eller godtyckliga externa scheman.
2. Bevara originaldata. Normalisering är en spårbar operation; skalan får inte härledas enbart från största observerade värde.
3. Kontrollera ID, referenser, antal patchar, kanaler och mätningar. Ordning får användas för koppling endast när den aktuella variantens ordningskontrakt är dokumenterat och verifierat.
4. Saknade metadata förblir okända. Ange inte M0, ett instrumentnamn, en våglängdsstart eller ett intervall enbart för att mottagaren kräver ett värde.
5. Separera beräkningsbelysning/observatör från instrumentets mätvillkor. D50 och M1 betyder olika saker. XRGA-konvertering är inte ett byte av etikett.
6. Bevara alla tillgängliga spektra och mätvillkor i projektet. Vid export till ett mer begränsat format ska varje bortvald del redovisas.
7. Logga varje avrundning, omsampling, härledd XYZ/Lab-beräkning och ändrad ordning. Inför inte färgrymdskonvertering på enhets-RGB av misstag.
8. Okända XML-utökningar bevaras i originalet. De får endast följa med i en modifierad export om objektreferenserna fortfarande är giltiga; annars markeras de som ej överförda.

## Förlustrapport och verifiering

Varje föreslagen konvertering ska ge en rapport med bevarade data, härledda data, avrundning, bortfall, olösta metadata och vald målvariant. Skilj mellan **byteidentisk arkivering**, **semantiskt likvärdigt mätinnehåll** och **begränsad kompatibilitetsexport**.

Minsta framtida testuppsättning:

- En liten RGB-uppsättning med olika patch-ID:n, upprepade RGB-värden och en kontrollerad ordning.
- En layout med flera rader/sidor och en dokumenterad permutation.
- Mätfiler med olika mätvillkor, upprepningar, Lab utan spektra och spektra med explicit våglängdsinformation.
- En fil med ofullständiga metadata och en med okända utökningar: ingen tyst gissning tillåts.
- Läs → skriv → läs: jämför identiteter, värden, skalor, villkor och layout inom en i förväg angiven numerisk tolerans.
- Öppna exporten i den faktiska i1Profiler-/ChromIQ-versionen. Kontrollera patchantal, utvalda värden och fysisk läsordning, inte bara att filen accepteras.

Schema-validering kompletterar dessa prov men ersätter inte semantisk kontroll eller prov i mottagarprogrammet. Den första versionsbundna UI-granskningen verifierar vissa originalfiler och exportvägar, men inte en färdig InkProf-adapter.

## Kodobservationer i lokal ChromIQ

Granskad revision: `92e6ead022fd57f4ecb80bf03670361b1b882247`, 2026-09-25. Observationerna gäller denna kod, inte alla ChromIQ-versioner.

- `workflow/i1profiler_export.py`: RGB-exporten till PXF omvandlar TI1:s 0–100 till heltal 0–255. Detta kan ändra styrvärdena och är inte en förlustfri 16-bitarsväg. CMYK och flerkanal hanteras med andra grenar och delvis uppskattade specialvärden.
- `workflow/i1profiler_import.py`, `parse_pxf`: den granskade patchimporten extraherar RGB och går vidare till skalning; den är inte en fullständig bevarande import av XML-resurser, layout och mätningar.
- `workflow/reference_convert.py`, `cxf_measurement_to_ti3`: kopplar target och mätningar efter ordning, väljer en mätvillkorsgrupp, antar 10 nm intervall och 0–255 RGB. Den beräknar XYZ och skriver TI3 utan spektrala kolumner.

**Konsekvens för InkProf:** en TI3 från den sistnämnda vägen räcker inte för att återställa ursprungsspektra. Bevara original-MXF/CxF och använd en separat, verifierad spektral import. Antagandena ovan får inte bli generella formatregler i InkProf. Inget ChromIQ-program har ändrats eller körts för konvertering här.

Kodreferenser: [PXF-export](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/workflow/i1profiler_export.py), [PXF-import](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/workflow/i1profiler_import.py), [mätkonvertering](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/workflow/reference_convert.py).

## Källor och öppna frågor

- **S1:** [X-Rite: CxF-resurser och XML-schema](https://www.xrite.com/page/cxf-color-exchange-format). Publicerat schema finns; någon lokal XSD-validering har inte gjorts här.
- **S2:** [X-Rite: CxF3 Schema Overview](https://www.xrite.com/-/media/xrite/files/literature/misc/c/cxf3_schema_overview_en.pdf). Kärnresurser och egna utökningar. Webbsökningens indexerade utdrag var tillgängligt; direkt PDF-hämtning nekades vid granskningen.
- **S3:** [X-Rite: CxF Standard 3.0](https://www.xrite.com/-/media/xrite/files/literature/misc/c/cxf_standard_en.pdf). Indexerade exempel och lokal ChromIQ-kod har använts för elementnamn; full normativ fältgranskning återstår.
- **S4:** [BabelColor: AN-10, oktober 2013](https://babelcolor.com/index_htm_files/AN-10%20Exporting%20to%20the%20CxF3%20and%20i1Profiler%20file%20formats%20with%20PatchTool.pdf). Praktisk interoperabilitet för äldre versioner; ingen garanti för dagens program.
- **S5:** [X-Rite: i1Profiler release notes 1.6.3 och tidigare](https://www.xrite.com/es/service-support/releasenotesfori1profiler163andprevious). Bekräftar filroller och import-/exportalternativ.
- **S6:** [X-Rite: mätdata och CGATS-export](https://www.xrite.com/es/service-support/measure_single_colors_with_i1profiler). Alternativ väg för utbyte.

Före implementation behövs versionsmärkta originalfiler för alla fyra roller, dokumenterade målprogram och beslut om första stödda delmängden. Första målet föreslås vara RGB-reflektans; CMYK och flerkanal definieras och provas separat. Specifika XML-obligatorier, defaults och privata resurser ska därefter fastställas från XSD och referensfiler, inte uppfinnas.
