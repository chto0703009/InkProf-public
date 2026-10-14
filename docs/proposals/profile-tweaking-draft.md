# Utkast: global och lokal färgjustering av ICC-profiler

Datum: 2026-10-13  
Status: framtida möjlighet, inte implementerad eller verifierad

## Syfte

Ge InkProf möjlighet att prova färgjusteringar globalt eller inom ett avgränsat område. Användaren ska kunna välja en kulör i en färgcirkel och påverka den över alla L*-nivåer, inom ett ljushetsintervall eller inom ett lokalt område av ljushet, kroma och kulör.

Funktionen ska skilja en avsiktlig ändring av återgivningen från skrivarprofilens uppmätta karakterisering. Originalprofil och mätningar bevaras. En ändrad återgivning utökar inte skrivarens fysiska gamut och är inte automatiskt en förbättring av färgnoggrannheten.

## Föreslagna justeringar

| Omfattning | Exempel |
| --- | --- |
| Kulörområde över alla L* | Flytta blått försiktigt mot cyan genom hela ljushetsområdet. |
| L*-begränsad justering | Ändra blått endast i mellantonerna. |
| Kromabegränsad justering | Påverka mättade färger och skydda neutrala eller svagt färgade områden. |
| Lokalt färgområde | Välj ett område vid exempelvis L*=50 och låt påverkan avta mjukt i tre dimensioner. |
| Tonkurva | Ändra ljushet eller kontrast globalt eller inom vald kulör. |

Lab/LCh är en naturlig första arbetsrymd. LCh-kroma är inte samma sak som perceptuell mättnad. Andra arbetsrymder, exempelvis OKLab eller IPT, kan undersökas som jämförelse, särskilt för blå-lila färger. Val av arbetsrymd, vitpunkt och eventuell kromatisk adaptation måste dokumenteras.

## Mjukt avgränsad påverkan

En möjlig första modell använder en vikt w(L*, C*, h) mellan 0 och 1. Vikten kombinerar mjuk avtoning i ljushet, kroma och cirkulärt kulöravstånd. Användarens valda ändringar av ljushet, kroma och kulör appliceras proportionellt mot vikten.

Modellen är en implementeringsidé, inte en fastställd algoritm. Den behöver:

- kontinuitet över färgcirkelns skarv vid 0/360 grader,
- skydd för neutrala färger, där kulörvinkeln är instabil,
- mjuka kanter utan abrupta gradientövergångar,
- kontroll av negativa kromavärden och andra ogiltiga värden,
- granskning av överlappande justeringar och deras ordningsberoende,
- kontroll av svartpunkt, vitpunkt, gamut och sammanfallande färger.

Även mjuka justeringar kan skapa oönskade kompressioner eller veck i transformen. Kontinuitet ensam räcker därför inte som kvalitetskontroll.

## Tre exportvägar

### 1. Separat abstrakt ICC-profil

En abstrakt profil uttrycker en färgändring inom PCS, exempelvis Lab till justerad Lab. Detta är den rekommenderade första experimentvägen: originalprofilen bevaras och korrigeringen kan sparas, jämföras och återställas separat.

ICC definierar abstrakta profiler för subjektiva färgändringar. LittleCMS dokumenterar exempel på Lab-baserade redigeringar. InkProf behöver utveckla konstruktion, sampling, export och validering av den önskade transformen; befintligt stöd för färgkonvertering innebär inte att editorn redan finns.

### 2. Ny skrivarprofil med inbakad korrigering

Argyll `colprof -p` kan applicera abstrakta profiler på utgångstabellerna efter gamut mapping. Olika korrigeringar kan anges för kolorimetrisk, perceptuell och saturation. Exempelvis kan endast den perceptuella utgångstabellen ändras.

Detta är ett nytt profilbygge från tillgängligt underlag, inte en generell färdig funktion för att redigera vilken befintlig ICC-fil som helst. Argylls dokumentation anger att gamut mapping inte tar hänsyn till den efterföljande abstrakta justeringen. Effekter nära gamutgränsen måste därför granskas särskilt.

Ändra inte den uppmätta framåtmodellen enbart för att skapa en önskad utskriftsåtergivning. Redovisa vilka tabeller och intents som ändrats. Det befintliga certifikatet kan inte automatiskt överföras som verifiering av varianten.

### 3. DeviceLink för en bestämd källa och destination

Argyll `collink -p` kan inkludera en abstrakt korrigering i en DeviceLink. Detta passar en specifik bild eller ett definierat flöde, exempelvis Adobe RGB till en viss Epson-profil.

InkProf kan undersöka att använda länken för att generera utskriftsdata. Den resulterande filen ska inte få ytterligare oavsiktlig ICC-konvertering. Användning av DeviceLink i externa program beror på deras stöd. Källprofil, destinationsprofil, intent, BPC och betraktningsvillkor ska registreras där de är tillämpliga.

## Mätstyrd korrigering som separat läge

Argyll `refine` skapar en abstrakt korrigeringsprofil genom att jämföra önskade färger med uppmätta färger. Det kan undersökas som ett eget läge, skilt från subjektiv manuell färgredigering. Verktyget har stöd för dämpning och begränsning mot destinationsgamut.

Manuellt önskad återgivning och mätbaserad korrigering ska ha separata etiketter, spårbarhet och bedömningsgrunder.

## Föreslagen användarvy i InkProf

Placering: under `Refinement tools`, som ett tydligt experimentellt verktyg för återgivningsjustering.

1. Välj originalprofil och källprofil eller provbild.
2. Markera kulörområde i färgcirkeln.
3. Välj alla L*-nivåer eller ett begränsat intervall; ange kromaintervall.
4. Justera kulör, kroma och ljushet samt avtoningens bredd.
5. Granska urvalets påverkan och före/efter för bild och gradienter.
6. Spara ett separat korrigeringsrecept och skapa en provvariant.
7. Skriv ut och granska innan varianten används för leverans.

En förhandsvisning ska ange vilken transform och vilket intent den visar. Den är inte bevis för utskriftens verkliga färger.

## Provfall: blågradient på Epson 3880

Användaren har rapporterat att skal-refinement förbättrade blågradienten marginellt men att problemet kvarstår på Epson 3880, medan gradienten blev bra på Canon 2600. Orsaken är inte fastställd.

Ett prov kan undersöka om lokal kromakompression eller en liten nyansändring minskar den synliga övergången. Det kan fungera genom att välja andra utskriftsfärger, utan att lösa en fysisk begränsning. Testet ska jämföra original och variant på samma papper med samma driverinställningar, och mäta färger före, vid och efter övergången.

## Verifiering och spårbarhet

- Kontrollera identitetsläget: noll justering ska ge identisk transform inom deklarerad numerisk tolerans.
- Kontrollera cirkelskarv, neutralskydd, regional avtoning och gradienternas kontinuitet.
- Jämför numeriska ramper i hög precision och 16/8 bit; skilj kvantisering från andra ojämnheter.
- Kontrollera exporterad ICC och använd transformen genom den avsedda CMM-kedjan.
- Genomför fysisk provutskrift och bedöm även områden utanför det valda urvalet.
- Spara originalets hash, korrigeringsparametrar, arbetsrymd, exportmetod, ändrade intents och verktygsversioner.
- Ge varje variant egen identitet och markera om den är experimentell, numeriskt kontrollerad eller fysiskt verifierad.

## Prioritering

Börja med en separat mjuk lokal transform, förhandsvisning och sparat recept. Prova abstrakt ICC eller DeviceLink i ett kontrollerat flöde. Inbakning i leveransprofil bör komma senare, efter att diagnostik och utskriftsprov visar nyttan.

## Källor

Kontrollerade under diskussionen 2026-10-13. Källorna stödjer exportvägarna; de verifierar inte den föreslagna InkProf-funktionen.

- [ICC: abstrakta profiler i profilspecifikationen](https://www.color.org/ICC_Minor_Revision_for_Web.pdf)
- [LittleCMS: Color Abstractor, Lab-redigeringar](https://littlecms.com/img/abstractor/manual.pdf)
- [ArgyllCMS: colprof, abstrakta profiler i utgångstabellerna](https://www.argyllcms.com/doc/colprof.html)
- [ArgyllCMS: collink, abstrakt profil i DeviceLink](https://www.argyllcms.com/doc/collink.html)
- [ArgyllCMS: refine, mätstyrd abstrakt korrigering](https://www.argyllcms.com/doc/refine.html)
