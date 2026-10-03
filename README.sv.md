# InkProf v1.0.0 – inför utgåvan

[English description](README.md)

**InkProf – När färgerna måste bli rätt**

För fotografen är målet att den omsorgsfullt framtagna bilden också ska komma till sin rätt på papper, med avsedda färger, toner och uttryck. Ett smidigt flöde från bild till utskrift ger trygghet och nöjdare fotografer, utskriftsföretag och kunder. Kalibrering och verifiering kan minska behovet av att göra nya utskrifter, spara arbetstid, papper och bläck och ge jämnare kvalitet.

InkProf samlar mätning, profilering och utskriftskontroll. Öppen källkod ger insyn i metoderna; sparade mätdata, inställningar och beslut gör resultatet spårbart. Det hjälper dig att hitta fel och förklara resultatet för kunden. Transparensen skapar förståelse för flödet och hjälper dig att hantera svåra färger, ända till gränsen för vad vald skrivare, papper och bläck kan återge.

Dokumenterade jämförelser med standarders gränser ger stöd för kvalitetsbedömningen, utan att intyga full standardöverensstämmelse. Kontrollresultaten visar vad den valda kombinationen klarar: en profil kan inte återge färger, svärta eller kontrast utanför skrivarens, papperets och bläckets förmåga.

InkProf är en app i MATLAB med öppen källkod. Varje projekt har en egen mapp, en sparad arbetsgång i JSON (JavaScript Object Notation, ett format för strukturerade data) och en läsbar resultatlogg. Appen stoppar steg vars förutsättningar inte är uppfyllda. Du kan stänga appen medan utskrifter torkar och senare öppna samma projekt.

## Arbetsgång

1. Skapa eller importera ett färgmål med RGB-värden (rött, grönt och blått).
2. Spara målet som TIFF med 16 bitar per färgkanal. Utskriften görs separat.
3. Mät med en kompatibel spektrometer från appen och granska den mätversion som ska användas.
4. Bygg en färgprofil i ICC-format (International Color Consortium) med ArgyllCMS och utför numeriska kontroller.
5. Spara, skriv ut och mät ett separat kontrollmål för fysisk verifiering.
6. Bedöm resultatet, gör vid behov en ny iteration och spara efter godkännande profil och mätcertifikat i PDF- och HTML-format på valfri plats.

Certifikatet samlar projektuppgifter, mätresultat, instrumentuppgifter och ansvarsförhållanden. Det har datum och utrymme för underskrift på papper. En tredimensionell färgvy visar profilens beräknade kontrollfärger; den är inte en uppmätt bild av hela skrivarens färgomfång.

## Projektuppgifter och flytt mellan datorer

Projektdefinitionen samlar användare, skrivare, papper, yta, bläck, utskriftsinställningar och torktid. Uppgifterna kan rättas senare och används av efterföljande steg. Ändrade utskriftsuppgifter kan kräva ny profilering och verifiering; tidigare mätningar och historik bevaras.

När projektet byter namn via appen byter även mappen namn. Om mappen har döpts om utanför appen får användaren bekräfta hur namnet ska hanteras. För att flytta projektet, avsluta aktiva operationer och kopiera hela projektmappen inklusive dolda filer. Appen kontrollerar registrerade filers integritet när projektet öppnas. Installera program och beroenden separat på den andra datorn.

## Installation och testade miljöer

Detta är en källkodsutgåva. MATLAB, Python och ArgyllCMS installeras separat. Se den [engelska installationsanvisningen](README.md#install-and-start) för kommandon och versionsuppgifter.

**InkProf är testat på macOS. Windows och Linux är inte testade.** Grundläggande mätning har provats med i1Pro 2; alla instrumentlägen är inte kvalificerade. Se [testade plattformar och begränsningar](docs/usage/tested-platforms.md).

## Dokumentation

- [Svensk presentation (PDF)](docs/usage/InkProf-presentation.pdf)
- [Svensk profileringskedja och MATLAB-guide (PDF)](docs/usage/InkProf-profileringskedja-MATLAB-guide.pdf)
- [Projektappen och arbetsgången](docs/usage/project-workflow-app.txt)
- [Mätcertifikat](docs/usage/measurement-certificate.md)
- [Förkortningar och begrepp](docs/usage/abbreviations.md)
- [Engelsk beskrivning och dokumentation](README.md)

## Kvalitet och begränsningar

En skapad profil är inte i sig ett bevis på god utskriftskvalitet. Resultatet begränsas av vad skrivaren, papperet och bläcket kan återge. Inställningar, torkning, instrument och mätningar måste kontrolleras för den aktuella användningen. När kontrollresultat används för att förbättra profilen krävs oberoende data för en senare slutkontroll.

Hänvisningar till ISO (International Organization for Standardization, Internationella standardiseringsorganisationen) innebär inte att InkProf intygar överensstämmelse med en standard. Bundesverband Druck und Medien (bvdm), Tysklands branschorganisation för tryck och medier, ger ut MediaStandard Print som sammanfattar standardkrav. Publikationen ersätter inte själva ISO-standarden.

## Licens, garanti och ansvar

Copyright © 2026 Christer Törnkvist. InkProfs egen kod och dokumentation är licensierad enligt GNU General Public License, version 3 eller senare (GPL-3.0-or-later). Se [licensen](LICENSE), [tredjepartsnotiser](THIRD_PARTY_NOTICES.md) och [licensunderlag](licenses/). Tredjepartsresurser behåller sina egna licenser; MATLAB kräver separat licens.

InkProf tillhandahålls i befintligt skick utan garantier. Användaren ansvarar för att kontrollera mätningar, profiler och utskriftsresultat före användning. I den utsträckning tillämplig lag tillåter ansvarar upphovsrättsinnehavaren inte för skador eller förluster som uppstår genom användningen. Se licensens avsnitt 15–17. Denna sammanfattning ersätter inte licensen.

Rapportera reproducerbara fel via [GitHub Issues](https://github.com/chto0703009/InkProf-public/issues). Ta först bort privata mätningar och personuppgifter.

Kontakt: Christer Törnkvist – christer@borgasundsfotografiska.se

## Inför v1.0.0

Koden är märkt **1.0.0-rc.1** medan utgåvan förbereds. Det är ännu ingen publicerad stabil v1.0.0. Se [ändringslogg](CHANGELOG.md), [validering](VALIDATION.txt) och [utgåvechecklista](docs/releases/v1.0.0.md).

Project details samlar även bläcktyp (dye/pigment), coating från skrivaren, torktid och inställningar för matt papper. Skuggläget ger upp till 48 extra mörka träningspatchar per iteration och tätare numerisk upplösning i skuggorna; värdena kan ändras. Se [matta papper](docs/usage/matte-shadow-profiling.md).

Appens 19 steg omfattar bildstyrd komplettering, C2 som träningsunderlag i nästa iteration, profiljämförelse (2D vid L*=50 eller 3D), en separat 3D-gamutyta samt mätcertifikat med underskrift och bilagor A/B. Rad 14 gäller utskriftsgranskat resultat. Rad 19 dokumenterar uttryckligen en senare iteration utan separat kontrollutskrift. Se [aktuell arbetsgång](docs/usage/workflow-v1.0.md) och PDF-handboken.
