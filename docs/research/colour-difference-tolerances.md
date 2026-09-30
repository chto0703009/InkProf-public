# Färgavvikelse, branschtoleranser och acceptans i InkProf

Tillagt 2026-09-29 efter användarens underlag och källkontroll. Detta är
bakgrund och stöd för val av acceptanskriterier. Inga kodgränser ändras genom
dokumentet och tidigare mätningar får ingen ny godkännandestatus.

## Standardens område och vilken Delta E som avses

ISO 12647 är en serie för processkontroll i grafisk produktion.
**ISO 12647-2:2013 gäller offsetlitografiska processer**, inte all tryckning
eller en generell tolerans för varje färg på en RGB-styrd bläckstråleskrivare.
Digitala kontraktsprov behandlas i **ISO 12647-7**. Att använda en bläckstråleskrivare
för ett prov gör inte i sig utskriften standardenlig.
[ISO:s beskrivning av 12647-2](https://www.iso.org/standard/57833.html),
[Fogra om digitala provtryck](https://fogra.org/en/certification/prepress-technology).

ΔE är inte en entydig formel. InkProf använder CIEDE2000, skrivet **ΔE00**, för
sina nuvarande färgfelsjämförelser. Formeln korrigerar för ojämnheter i CIELAB:s
samband med visuell färgskillnad. Den ska inte förväxlas med CIELAB 1976,
**ΔE*ab**. Ett toleranstal måste alltid åtföljas av formeln; ett gränsvärde
kan inte överföras mellan formlerna genom att bara byta beteckning.
[CIE:s beskrivning av CIEDE2000](https://www.cie.co.at/publications/colorimetry-part-6-ciede2000-colour-difference-formula-1).

CIEDE2000 är relevant för små färgskillnader, men påståendet att den alltid
”bäst” motsvarar synintrycket blir för generellt. Provstorlek, omgivning och
betraktningssätt spelar roll. Bedömning av färgrutor och av hela bilder är
inte samma uppgift.
[CIE om små färgskillnader](https://www.cie.co.at/publications/validity-formulae-predicting-small-colour-differences),
[CIE om färgskillnader i bilder](https://www.cie.co.at/publications/methods-evaluating-colour-differences-images).

## Korrigering av de föreslagna branschgränserna

- **”5,0 är den officiella maxgränsen och allt under är godkänt”** ska inte
  användas som generell regel. Ange standarddel, utgåva, formel, referens,
  patchgrupp och om gränsen gäller medel, maximum eller percentil.
- **”2–3 är standard hos de flesta tryckerier”** kan diskuteras som ett
  praktiskt avtals- eller projektmål, men belägger inte ett universellt krav.
- **”Högst 1,0 krävs för digitala provtryck”** är inte ett generellt krav i
  ISO 12647-7. Ett sådant tal kan vara ett eget strängare mål för utvalda
  färger, med tydligt angivna mät- och bedömningsvillkor.

Ett konkret exempel är bvdm:s *MediaStandard Print 2018*, tabell 30, tryckt
sida 50. Där sammanfattas jobbrelaterad digital provtryckskontroll med
mediekil utifrån ISO 12647-7:2016:

| Kontroll | Angiven tolerans, ΔE00 |
|---|---:|
| Medel över mediekilens samtliga färgfält | ≤ 2,5 |
| Maximum över mediekilens samtliga färgfält | ≤ 5,0 |
| Primärfärgernas solider | ≤ 3,0 |
| Pappersvitt | ≤ 3,0 |

Det finns ytterligare krav. Tabellen är **inte ett komplett certifieringsprov**
och får inte överföras direkt till InkProfs valfria RGB-mål. Den visar varför
varken ”alla proofs måste vara under 1” eller ”alla värden under 5 är godkända”
är en korrekt sammanfattning.
[bvdm, MediaStandard Print 2018, tabell 30](https://www.bvdm-online.de/fileadmin/user_upload/01_Global/Downloads_PDF_DOC/Downloads_Technik/MediaStandard_Print_2018.pdf#page=50).

De exakta kraven för ett formellt standardpåstående behöver kontrolleras mot
vald standardutgåva och hela dess provningsförfarande. Här har offentliga
standardbeskrivningar och branschorganisationens publicerade sammanställning
använts, inte en fullständig klausulgranskning av ISO-standarderna.

## Ungefärlig visuell tolkning

Följande behåller användarens intervall som **pedagogisk orientering**, inte
som ISO-gränser eller verifierade universella perceptionströsklar:

| ΔE00 | Försiktig tolkning vid jämförelse av färgprov |
|---|---|
| < 1,0 | Mycket liten skillnad; kan ändå vara synlig under gynnsamma jämförelseförhållanden. |
| 1,0–2,0 | Liten skillnad som kan upptäckas vid jämförelse sida vid sida. |
| > 2,0–3,5 | Kan vara märkbar; acceptans beror på färg, motiv och avtal. |
| > 3,5–5,0 | Kan vara tydlig, särskilt i känsliga neutrala partier eller referensfärger. |
| > 5,0 | Bör undersökas särskilt; talet ensamt fastställer varken synintryck eller standardavvikelse. |

”Helt osynlig” och ”helt avvikande färg” bör undvikas som absoluta slutsatser.
Ljushet, kulör, ytstorlek, struktur, glans, omgivning, belysning och observatör
påverkar bedömningen. De skarpa intervallgränserna ovan är ett sätt att
presentera storleksordningar, inte steg i människans färgseende.

## Papper, mätvillkor och referens

Pappersvithet, optiska vitmedel, ytstruktur och glans påverkar den mätta och
upplevda färgen. Bestruket och obestruket papper har olika förutsättningar.
Det innebär inte att ett kritvitt eller blankt papper alltid ger lägst fel:
referensen måste vara relevant för materialet och skrivarens uppnåeliga
färgområde. Substrat- och processval ingår i valet av produktionsstandard.
[ISO/TC 130:s vägledning om produktionsstandarder](https://committee.iso.org/files/live/sites/tc130/files/Resources/Guidelines%20for%20using%20print%20production%20standards%20v2%20Jan%202024.pdf).

För InkProf ska en jämförelse därför dokumentera referens, illuminant och
observatör, M0/M1/M2, mätgeometri, underlag/backing, papper, torktid och
utskriftsinställningar i den mån de är kända. Okända uppgifter ska vara
markerade som okända. Ett ΔE00 i D50 beskriver inte ensamt metamerism under
andra ljuskällor.

## Betydelse för InkProfs iteration och acceptans

Skilj mellan fyra mått:

1. **Träningsfel:** modellens anpassning till de prov som användes vid profilering.
2. **Utvecklingsfel:** separata prov som påverkar modellval och nya patchar.
3. **Utskriftsfel:** ny fysisk utskrift jämförd mot avsedd färgreferens.
4. **Regression:** ökningen av ett befintligt fel när en kandidat jämförs med
   en annan kandidat på samma prov.

`MaxPatchRegression=0.5` betyder exempelvis en tillåten **ökning** på 0,5 ΔE00
av patchens fel. Det är inte en absolut färgtolerans på 0,5 och inte ett
ISO-krav. Inte heller `NormTarget=1` är ett krav för certifierade proofs.
InkProfs viktade RMS-norm ska inte jämställas med ett aritmetiskt medelfel.

I testet med 911 träningspatchar gav high-varianterna lägre samlat fel men
stoppades av regressionsregeln. Branschens absoluta toleranser avgör inte
ensamma om just den regeln bör ändras. En användbar framtida acceptanspolicy
bör ange separata mål för medel, P95, maximum, gråskala och viktiga färger,
samt tillåten lokal regression. För varje gräns behövs patchgrupp, färgformel,
referens och mätvillkor. Mätvariation ska vägas in vid små skillnader.

## Beslutad princip: slutkvalitet och iterationsdiagnostik

Användarens förtydligande 2026-09-29: färgfelen ska sättas i relation till
slutresultatets krav, samtidigt som även små förändringar används för att
förstå hur iterationen utvecklas. Dessa två användningar behöver olika
beslutsregler.

**Exempel: samma patch går från 0,6 till 0,7 ΔE00 mot samma referens.**
Slutfelet är 0,7 och ökningen är 0,1. Om båda värdena ligger inom projektets
accepterade kvalitetsområde är ökningen inte i sig ett problem i slutresultatet.
Den ska loggas som information om iterationens riktning, men bör inte ensam
stoppa en kandidat som förbättrar helheten. Ökningen av referensfelet är inte
detsamma som färgavståndet mellan de två kandidaternas färger.

För kommande urvalslogik gäller följande inriktning:

- **Slutkvalitet:** bedöm det absoluta felet mot avtalade krav för relevant
  patchgrupp, tillsammans med medel, P95 och maximum.
- **Iterationsdiagnostik:** bevara tidigare fel, nytt fel och förändringen,
  även när båda resultaten är acceptabla. Följ återkommande försämringar
  över flera iterationer och använd dem för analys och prioritering av nya prov.
- **Beslut:** små försämringar inom accepterad kvalitet är främst diagnostik.
  Större regressioner och överskridna kvalitetsgränser ska väga tyngre vid
  profilval och kunna utlösa granskning. Ett förbättrat medelfel får inte dölja
  oacceptabla lokala fel.
- **Prioriteringar:** gråskala och särskilt viktiga färger kan ha strängare
  absoluta krav och regressionsregler än övriga färger.
- **Mätvariation:** en förändring på 0,1 kan ligga inom variationen, men får
  inte automatiskt avfärdas som brus. Bedömningen kräver upprepningar eller
  annan dokumenterad osäkerhetsinformation.

Detta är en beslutad utvecklingsprincip, **inte en redan genomförd ändring av
urvalsalgoritmen**. Den nuvarande `MaxPatchRegression`-regeln tar ännu inte
hänsyn till om patchens absoluta slutfel ligger inom ett accepterat område.
Exemplet 0,6 → 0,7 passerar redan den nuvarande regressionsgränsen 0,5, men
principen innebär att framtida regler även ska väga in absolut kvalitetsnivå.
Inga nya generella acceptansgränser fastställs här.

Detta dokument inför **ingen ny automatisk godkännandepolicy**. Val av
projektgränser ska redovisas som egna krav om det inte gäller ett fullständigt
prov enligt en uttryckligen vald standard.

Relaterat: [automatisk profiliteration](../usage/automatic-profile-iteration.md),
[iterationsstrategi](../planning/profile-iteration-strategy.md).
