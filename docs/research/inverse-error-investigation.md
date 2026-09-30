# Inversfel i 575-profilen – undersökning 2026-09-27

## Slutsats

Två problem måste skiljas åt: färgfelet från en approximativ B2A-tabell och att framåtmodellen kan ge praktiskt taget samma Lab för olika RGB. En tätare B2A-tabell hjälper det första men löser inte det andra. Profilen är fortfarande en kandidat, inte utskriftsvaliderad.

## Underlag och metod

Epson 3880, Scandinavian Photo Glossy, 575 korrigerade patchar, spektral D50/1931 2°, ingen FWA. Projektmappens historiska namn innehåller Canon, men avser här Epson. Ursprungligt jobb: `45453c4b-b948-4183-96fd-103429a1c71c`.

Profilens SHA256: `c0b096f157696eacfffef8f89df9e1b7469f531102707d859d04edfeeee035e0`.

729 RGB-punkter (9³) med relativ kolorimetri, ingen BPC. För varje RGB beräknas Lab med A2B, RGB med inversen och sedan Lab igen. ΔE00 jämför de två Lab-värdena. RGB-avvikelsen är största absoluta kanalskillnaden i procentenheter av intervallet 0–1.

Tre varianter jämfördes med ArgyllCMS 3.5.0:

1. Ursprunglig profil: `colprof -qm`, lagrad B2A via `xicclu -fb -ir -pl`.
2. Separat experiment: `colprof -qm -bh -al -i D50 -o 1931_2`, tätare B2A. Alla tre A2B-taggar är byteidentiska med originalet och de 729 framåtvärdena identiska. Därmed isoleras skillnaden i inversen.
3. Numerisk inversion av originalets A2B via `xicclu -fif -ir -pl`.

Argyll dokumenterar [separat B2A-kvalitet](https://www.argyllcms.com/doc/colprof.html) och [lagrad respektive numeriskt beräknad invers](https://www.argyllcms.com/doc/xicclu.html).

## Resultat

| Metod | Medel ΔE00 | 95-percentil | Max ΔE00 | Max RGB-avvikelse, procentenheter |
|---|---:|---:|---:|---:|
| Ursprunglig B2A | 0,8819 | 2,5037 | 4,7791 | 52,5349 |
| Tätare B2A, high | 0,4809 | 1,5168 | 2,4055 | 52,3058 |
| Numerisk A2B-invers | 0,0507 | 0,3242 | 1,4351 | 51,9264 |

High minskar medelfelet cirka 45 % och maxfelet cirka 50 %. B2A-taggen ökar från 41 818 till 240 250 byte. Detta är ett positivt experiment, inte ett automatiskt byte av produktionsrecept.

De 386 randpunkterna har större medelfel (1,1222) än de 343 inre punkterna (0,6114) med ursprunglig B2A. De största RGB-avvikelserna återfinns bland undersökta gröna/cyana punkter med hög G.

## Konkret exempel: stor RGB-skillnad men liten färgskillnad

För ursprungligt RGB **(0; 1; 0,5)** ger A2B Lab **(77,318312; −49,138420; 33,889605)**.

- Lagrad B2A väljer RGB **(0,525349; 0,919676; 0,499655)**. Färgfelet är endast **0,4032 ΔE00**, trots 52,53 procentenheters skillnad i R.
- Numerisk inversion väljer **(0,506691; 0,988973; 0,501102)** med **0,000011 ΔE00**.

Det visar att modellen inom denna numeriska precision tillåter praktiskt taget samma färg vid mycket olika RGB. Det bevisar inte att skrivaren i verkligheten återger båda RGB lika. Interpolation, mätdatans täthet och mätfel kan bidra till modellens beteende.

Jacobianens singularvärden vid ursprungspunkten är ungefär **103,27; 53,24; 2,15** Lab-enheter per normaliserad RGB-enhet. Konditionstalet är cirka **48**, stabilt för prövade differenssteg 0,001–0,01. En RGB-riktning ger alltså betydligt mindre färgändring än andra. Vid andra grön/cyana punkter är konditionstalet större och mer stegberoende. Detta är lokal diagnostik i Lab-koordinater, inte direkt ΔE00-konditionering eller bevis för global entydighet.

Längs den raka linjen mellan original-RGB och B2A-lösningen når färgavvikelsen 2,076 ΔE00. Området kan därför inte beskrivas som en helt platt dal bara för att ändpunkterna liknar varandra.

## Vad siffrorna inte säger

Alla Lab-mål i just denna kontroll skapas med A2B från kända RGB. Därför finns redan en exakt förbild i samma modell: det ursprungliga RGB-värdet. Kvarstående fel vid numerisk inversion är inte bevis för att målet ligger utanför gamut. Det visar begränsningar i den använda inversberäkningen, lösningsvalet och numeriken.

En liten framåtavvikelse mot träningsdata garanterar inte en stabil eller entydig invers. En jämn framåtmodell kan fortfarande vara svagt känslig i en riktning eller ha flera möjliga lösningar. Få återfunna RGB-värden behöver däremot inte betyda dålig färgåtergivning: färgfel, RGB-återgång och jämnhet måste rapporteras separat.

## Rekommenderade små nästa steg

1. Exponera separat B2A-kvalitet i receptet och behåll medium som jämförelse. High är en tydligt bättre kandidat i denna kontroll.
2. Kontrollera gråramp, färgramper, närliggande PCS-punkters RGB och CMM även för high-kandidaten innan byte. Särskilt viktigt är hopp mellan alternativa lösningar.
3. Skapa ett litet verifieringsmål runt de gröna/cyana fallen: original-RGB, alternativa RGB och närliggande punkter samt upprepningar. Mät om modellen beskriver den faktiska skrivaren där.
4. För egen invers: använd begränsad optimering med fortsatt startvärde från grannlösningen samt regularisering för jämnhet. Gråprioritet måste definieras separat. Välj inte enbart den RGB som ligger närmast originalet; vid verklig PCS→RGB-inversion är originalet okänt.
5. Förstärk mätunderlaget adaptivt där verifierade fel eller inverskänslighet motiverar det; tätare tabell tillför inte nya mätningar.

## Sparade resultat och reproduktion

- `inverse-error-investigation.json`: numerisk invers, fall, Jacobianer och linjeprov.
- `inverse-high-b2a-experiment.json`: high-resultat, taggstorlekar och A2B-identitetskontroll.
- `analysis/investigate_inverse.py`: återanvändbar analys av ett jobb och dess grid-check. Kör med `--help` för argument. Befintlig utdata skrivs inte över.
- High-experimentets profil, oförändrad TI3 och logg ligger under `work/inverse-investigation/high/` (lokalt experiment, inte publicerad profil).

Originalprofil, recept och mätningar har inte ändrats. Resultaten är syntetiska profiltester, inte oberoende utskriftsmätningar eller en konvergensgaranti.

## Konditionstal och val av inversalgoritm

Ett konditionstal runt 48 är en varningssignal om riktningsberoende känslighet, inte i sig ett skäl att underkänna profilen eller ett tecken på flyttalsproblem. Här avses 2-normskonditionstalet hos Jacobianen i Lab per normaliserad RGB. Resultatet beror på koordinatskalning och är inte en generell faktor som kan multipliceras med ett ΔE00-fel.

Lokalt gäller `δLab ≈ J δRGB`. Minsta singularvärdet cirka 2,15 innebär att en Lab-störning på 0,1 i den känsligaste inversriktningen kan motsvara ungefär 0,047 i RGB-vektorns norm i den linjära modellen. Kubgränser och olinjäritet kan begränsa detta. Det är därför absolut inverskänslighet, mätbrus och önskad färgtolerans tillsammans som avgör betydelsen.

Vi byter inte Argylls inversalgoritm enbart på grund av detta tal. Den lagrade B2A-tabellen är en approximation, medan `xicclu -fif` är en annan beräkningsväg; inget av dessa undanröjer att modellen kan tillåta flera lösningar. Tätare B2A behandlar först det uppmätta tabellfelet.

För en senare egen invers rekommenderas ett experiment med begränsad trust-region-minimering (`0 ≤ RGB ≤ 1`), SVD/QR-baserade linjära delproblem och kontrollerad steglängd. Undvik explicit matrisinvers och odämpade Newtonsteg nära svaga riktningar. Välj föregående grannlösning eller B2A som startvärde, kontrollera alternativa startpunkter och inför vid behov en uttrycklig jämnhetsregularisering med dokumenterad avvägning mot färgfelet. Att lösa via normalekvationer kan kvadrera konditionstalet; det är inget skäl att välja den vägen här.

SciPy beskriver [least_squares med bounds och trust-region reflective](https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.least_squares.html). Detta är en föreslagen separat forskningsväg, inte en redan implementerad ersättning för Argyll. En algoritm kan stabilisera lösningsvalet men inte skapa mätinformation som saknas eller göra en flerentydig modell entydig utan extra kriterier.

Efter användarens beslut är High nu förval i nya recept, med Medium som valbar referens. Äldre recept och profiler bevaras oförändrade.

## Verifierad körning med nytt recept

Jobb `63dfb8f4-034b-488e-82b0-341511343016` byggdes via MATLABs ordinarie recept- och jobbrutiner. A2B-taggarna är byteidentiska med baslinjen. Medel/max ΔE00 roundtrip blev 0,4809/2,4055. Träningsanpassningen är oförändrad: 0,4865/2,3387. Inga RGB utanför kuben eller nya framåtrampkandidater noterades.

Det begränsade LittleCMS-testet gav som mest 10,11 procentenheters RGB-skillnad mot Argyll vid samma kvantiserade Lab-indata. Just detta fall motsvarar endast 0,138 ΔE00 genom samma A2B. Över samtliga punkter är denna färgskillnad i medel 0,209 och max 1,333 ΔE00. Det är fortsatt en 8-bitarsjämförelse, inte en fullprecisionsjämförelse eller fysisk validering. Resultaten finns i `high-b2a-build-20260927.json`.

Testning: fem Python-jobbtester (inklusive äldre recept, high/medium och otillåtet kvalitetsval), två MATLAB-dialogtester samt komplett bygge, träningskontroll och nätkontroll genom MATLAB. Profilen har inte installerats som systemprofil.
