# MATLAB Base, Python och spektral profilering i InkProf

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Datum: 2026-09-26. Status: granskning och rekommenderad fortsättning; ingen ny beräkningsmotor är implementerad genom detta dokument.

## Rekommendation

Behåll MATLAB Base som användargränssnitt och projektledande lager. Använd Python för nya spektrala beräkningar, modellpassning och begränsad numerisk optimering. Behåll ArgyllCMS för instrumentkommunikation och som första ICC-profilmotor och jämförelsereferens. JSON förblir intern datamodell; TI1/TI2/TI3 är utbytesformat.

Nästa konkreta leverans bör vara en verifierbar beräkningskedja från befintliga uppmätta spektra till XYZ, Lab och jämförelser. Därefter kommer ICC-profilering och oberoende validering. Egen spektral inversmodell och optimering under flera ljuskällor är senare steg.

Pythonvalet motiveras främst av tillgången till etablerade numeriska bibliotek utan MATLAB-tillägg. Språkbytet i sig förbättrar varken mätdata eller nätfördelning. Fungerande MATLAB-kod behöver inte skrivas om enbart för enhetlighet.

## Vad finns redan, och kräver det MATLAB-tillägg?

Lokal kodgranskning omfattade MATLAB-koden, Pythonstarten och chartread-bryggan. `matlab.codetools.requiredFilesAndProducts` kördes i R2025b Update 7 på 60 MATLAB-filer inklusive setup. Analysen redovisade **enbart MATLAB** som nödvändig produkt, med 60 identifierade beroendefiler. Rapporten finns lokalt i `work/review-python-20260926/matlab-dependencies.json`.

Det är en statisk analys, inte bevis för alla dynamiska körvägar. Datorn har flera tillägg installerade; acceptansprov på en installation med endast Base återstår. Analysen säger inte heller något om externa Python- eller Argyll-beroenden.

MATLAB Base har redan [Delaunay-triangulering](https://www.mathworks.com/help/matlab/ref/delaunaytriangulation.html), [spridd interpolation](https://www.mathworks.com/help/matlab/ref/scatteredinterpolant.html), linjär algebra och [fminsearch](https://www.mathworks.com/help/matlab/ref/fminsearch.html). Det senare söker ett lokalt minimum utan explicita bivillkor. [lsqnonlin](https://www.mathworks.com/help/optim/ug/lsqnonlin.html) tillhör däremot Optimization Toolbox. Spektral integration kräver inte i sig ett tillägg; den kan uttryckas med vanliga matriser.

Den nuvarande Python-bryggan använder standardbiblioteket. InkProf har redan val av Python per dator, kontroll av körmiljö och anrop som separat process. Det är en lämplig grund att bygga vidare på.

## Kritisk granskning av den inskickade texten

Texten identifierar värdet av att behålla spektra, men kodexemplen är inte produktionsklara. Följande behöver rättas innan de kan användas som förebild.

| Påstående eller konstruktion | Bedömning och konsekvens |
|---|---|
| ICC/LittleCMS är otillräckligt för hela arbetsflödet | De ersätter inte spektral analys, men är fortfarande relevanta för vanlig ICC-baserad färgkonvertering. Spektral analys och ICC-leverans kan samexistera. |
| Spektrum → XYZ → sRGB ger skrivarens RGB | sRGB är en definierad färgrymd, inte Canons enhets-RGB. Skrivarvärden kräver skrivarprofil eller en uppmätt inversmodell. |
| D50-XYZ skickas till standardanrop för sRGB | Vitpunkt måste anges och kromatisk adaptation hanteras. Standardanropen får inte antas förstå att indata avser D50. |
| Ett spektralvärde vid 500 nm används som Lab-vitpunkt | Fel typ av storhet. Lab-konverteringen behöver vitpunktens kromaticitet, inte ljuskällans effekt vid en våglängd. |
| Lab under flera ljuskällor räknas med standardvitpunkt | Varje beräkning behöver uttrycklig och konsekvent referensvitpunkt. Annars blir även ΔE missvisande. |
| Fyra slumpmässiga bläckkurvor summeras linjärt | Detta är ingen kalibrerad modell för övertryck. Noll bläck ger i exemplet svart, inte papper; ökade positiva vikter gör det ljusare. Klippningen skapar dessutom konstgjorda platåer. |
| CMYK-vikter optimeras för Canon | InkProf styr RGB i det aktuella arbetsflödet. De interna bläckkanalerna är inte åtkomliga genom detta gränssnitt. |
| Samma RGB-referens definierar originalet under alla ljus | Tre färgkoordinater bestämmer inte ett unikt reflektansspektrum. Referensspektrum eller ett uttryckligt antagande krävs. |
| Viktad summa av ΔE kallas SMI och ger garanti | Det är ett valt optimeringsmått, inte därmed ett verifierat standardiserat metameriindex. Lokal optimering garanterar inte globalt optimum eller ett fysiskt utskriftsresultat. |
| F11 representerar LED-belysning | F11 avser en fluorescerande standardljuskälla. Verklig LED-belysning måste beskrivas av en passande eller uppmätt spektralfördelning. |

Colour anger att [`XYZ_to_Lab`](https://colour.readthedocs.io/en/develop/generated/colour.XYZ_to_Lab.html) tar vitpunkt som xy eller xyY och normalt använder D65. [`sRGB_to_XYZ`](https://colour.readthedocs.io/en/develop/generated/colour.sRGB_to_XYZ.html) och [`XYZ_to_sRGB`](https://colour.readthedocs.io/en/develop/generated/colour.XYZ_to_sRGB.html) kräver att vald vitpunkt och adaptation förstås. En variabel kallad `cmyk_profiles` blir inte CMYK eller en ICC-profil genom att innehålla sRGB-tal.

Colour-dokumentationens illuminanttabell använder nyckeln [`FL11`](https://colour.readthedocs.io/en/v0.3.16_b/generated/colour.SDS_ILLUMINANTS.html), inte exemplets `F11`. Nycklar och API ska kontrolleras mot den version som faktiskt låses och testas.

## Rätt matematisk utgångspunkt

För ett icke-fluorescerande reflektansprov r och en ljuskälla E beräknas relativ kolorimetri diskret som

```text
k = 100 / sum(E_i * ybar_i * delta_lambda_i)
X = k * sum(r_i * E_i * xbar_i * delta_lambda_i)
Y = k * sum(r_i * E_i * ybar_i * delta_lambda_i)
Z = k * sum(r_i * E_i * zbar_i * delta_lambda_i)
```

Perfekt diffus reflektor får Y=100. Referensvitpunkten beräknas med r=1 på samma våglängdsunderlag. Biblioteksanrop som använder XYZ på skalan 0–1 ska få motsvarande skalning. Detta är relativ kolorimetri; det är inte automatiskt absolut luminans eller fullständig beskrivning av färgupplevelsen.

Våglängdsintervall, interpolationsmetod och extrapolation måste dokumenteras. 400–700 nm och 380–730 nm får inte behandlas som identiska fullständiga spektra. [`sd_to_XYZ`](https://colour.readthedocs.io/en/develop/generated/colour.sd_to_XYZ.html) erbjuder olika beräkningsmetoder och normaliseringar; vi behöver välja och testa en uttrycklig konvention.

Optiska vitmedel gör återbelysning mer komplicerad: uppmätt spektral respons kan bero på mätljusets UV-innehåll. M0/M1/M2 ska bevaras och får inte blandas som likvärdiga prov. En enkel reflektansintegral får inte utlovas som exakt prognos för godtycklig belysning på fluorescerande papper.

## Modellen för vår RGB-skrivare

Den relevanta framåtmodellen är

```text
u = (R, G, B), 0 <= u_j <= 1
F(u; papper, utskriftsläge, drivrutinsinställningar) = uppmätt spektral respons
```

Den omfattar hela den låsta utskriftskedjan. Antalet patroner ger inte motsvarande antal styrbara variabler. Börja med en empirisk RGB-modell från mätningar. Spektra kan modelleras direkt eller genom en lågdimensionell bas, exempelvis SVD/PCA med Base eller NumPy. Val av modell, antal komponenter och regularisering ska avgöras med separat validering. Begränsningar för rekonstruerade spektra måste ta hänsyn till om datan innehåller fluorescens; blind klippning till 0–1 är inte en universell lösning.

En senare invers kan söka RGB som minimerar färgfel under ett eller flera specificerade ljus, med RGB-gränser och regularisering. För ett känt reflektansoriginal kan båda proven beräknas under samma ljus och jämföras. Om originalet endast är RGB måste uppgiften i stället formuleras som ett valt färgåtergivningsmål; dess verkliga metameri är okänd.

Med tre styrvariabler kan vi inte lova oberoende kontroll av färgen under flera ljus. En förbättring under ett ljus kan försämra en annan. Förbättring ska därför redovisas per ljuskälla och verifieras med nya utskrifter.

Lokal Taylor-utveckling med approximerad Jacobian är rimlig som numerisk metod. Kombinera med begränsade steg, skalning och regularisering när inversen är illa konditionerad. Snabb konvergens bevisar inte att modellen är riktig. SciPys [`least_squares`](https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.least_squares.html) erbjuder bounds, numeriska Jacobianer och robusta förlustfunktioner. Funktionen behöver en residualvektor; en viktad summa av ΔE ska inte utan eftertanke behandlas som samma minsta-kvadratproblem. Varken godkänd solverstatus eller låg träningsavvikelse ersätter fysisk validering.

## Arbetsfördelning

| Del | Rekommenderat ansvar |
|---|---|
| Fönster, filval, preview och presentation | MATLAB Base; engelska texter |
| Befintlig definition, layout och TIFF16 | Behåll fungerande implementation |
| Instrument och radavläsning | Argyll chartread via InkProfs egen Python-brygga |
| Spektral kolorimetri och ΔE00 | Python, NumPy och Colour Science, med referensprov |
| Modellpassning och begränsad invers | Python/SciPy när validerade data finns |
| ICC-generering och profiluppslag | Argyll colprof och xicclu som första motor |
| Data, identiteter och spårbarhet | Versionssatt JSON; formatadaptrar vid import/export |

En vanlig ICC-profil använder kolorimetrisk PCS. Det betyder att profilens standardtransform inte bevarar hela spektrumet, inte att mätningarnas spektra behöver kastas. ICC beskriver [XYZ/Lab-baserad PCS och spektrala utvidgningar](https://www.color.org/iccmax/connection1/); [iccMAX](https://www.color.org/iccmax/) har spektrala möjligheter. iccMAX bör inte införas som krav innan utskriftskedjans stöd och behov är visade.

[Argyll colprof](https://www.argyllcms.com/doc/colprof.html) är första profilreferens. [profcheck](https://www.argyllcms.com/doc/profcheck.html) kan jämföra profil och TI3, inklusive CIEDE2000 med `-k`. Vi behöver skilja profilens framåtmodellfel från en verklig kontrollutskrift genom profilen: de senare proven testar även invers, rendering intent och faktisk utskriftskedja.

## Portabel Python och datakontrakt

Återanvänd separata processer och befintlig sökvägskonfiguration. MATLAB skickar ett versionssatt JSON-jobb och får resultatfil, status och logg tillbaka. Använd inte maskinbundna Python-sökvägar i sparad projektdefinition. Relativa resurser, programkonfiguration och källdata ska skiljas åt. Skriv resultat atomärt och bevara indata oförändrade.

Behåll den fungerande mätbryggan utan nya tunga beroenden. Lägg analysens paket i en separat definierad och testad beroendegrupp. Lås Python- och paketversioner först efter prov på stödda datorer; aktuell minimiversion i InkProf är inte automatiskt tillräcklig för nya bibliotek. Colours granskade [utvecklingsmetadata](https://github.com/colour-science/colour/blob/develop/pyproject.toml) anger Python >=3.11,<3.15 för 0.4.7. Det är inte ett besked att installera utvecklingsgrenen eller att den är testad i InkProf.

JSON behöver bära patch-ID, enhets-RGB och skala, fysisk position och sidnummer, råspektrum med våglängder/enheter, instrument/mätvillkor, upprepningar, källfil och hash. Härledda resultat sparas separat med ljuskälla, observatör, vitpunkt, skalning, integrationsmetod, programversioner och källreferens. Modellresultat ska dessutom ha tränings-/valideringsroller, parametrar, residualer och konvergensstatus. Befintligt targetInfo ska återanvändas, inte dupliceras med avvikande metadata.

## Genomförande och acceptans

1. **Fastställ kolorimetrikontraktet.** Inventera riktiga JSON/TI3/MXF-spektradata och identifiera saknade metadata. Bevara okända fält som okända; gissa inte M-läge, skala eller belysning.
2. **Bygg Python-analys som första nya motor.** Läs en befintlig mätning och ge spårbar XYZ/Lab. Testa vit/svart/neutral, procent kontra 0–1, olika spektralintervall, felaktiga data och publicerade ΔE00-referensfall. Jämför med Argyll när förutsättningarna verkligen är samma; förklara metodskillnader innan toleranser godtas.
3. **Bygg ICC-baslinjen.** Skapa TI3 från validerad intern data, generera RGB-profil med Argyll och rapportera ΔE00 på separata kontrollpatchar. Testa sedan en fysisk utskrift med profilen. Gråskala, maximum och percentiler redovisas tillsammans med medelfel.
4. **Bygg empirisk modell och återkoppling.** Jämför enkla modeller innan komplexitet tillförs. Förtäta områden med påvisat modellfel och otillräckligt stöd, enligt plan för felstyrd förtätning. Använd upprepningar för att skilja mätbrus från modellfel. När kontrollprov används för att välja nästa nät behövs nya orörda slutkontroller.
5. **Pröva flerljusoptimering.** Först när referensspektrum eller ett definierat färgåtergivningsmål finns. Rapportera kompromisser, känslighet och verklig mätverifiering; kalla inte ett eget mått standardiserat metameriindex.

Geometriskt avstånd i RGB är ett täckningsmått. ΔE00 efter mätning är ett färgfel. Osäkerhet i en modell är ett tredje mått. De behöver skilda namn och fält, även om de senare kombineras för att välja nya patchar.

## Avgränsning av denna granskning

Officiell dokumentation har granskats för MathWorks, SciPy, Colour Science, ICC och ArgyllCMS. Den inskickade koden har granskats som förslag, inte godkänts genom körning. Inga nya Python-paket har installerats, ingen fysisk mätning har körts och ingen spektral optimeringsmotor har lagts in. Rekommendationen kompletterar projektplanen; den ersätter inte befintliga fungerande mät- och targetflöden.
