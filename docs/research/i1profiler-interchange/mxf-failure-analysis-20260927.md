# Analys: fungerande MXF, avvisade InkProf-exporter och ChromIQ

Aktuell status: se [acceptans 2026-09-27](acceptance-20260927.md).
Daterade uppgifter om väntande importprov nedan beskriver tidigare felsökning.

2026-09-27. Undersökning av lokala filer och lokal ChromIQ-kod, commit
`92e6ead0`. Originalmätningarna har inte ändrats.

## Slutsats

Den nya i1Profiler-filen är en fungerande referens: användarens skärmbild
12:08:06 visar den återöppnad med färgkarta, XRGA, M0 och Device ready.
Det tidigare meddelandet Device: Invalid Argument försvann efter instrument-
kalibrering. Detta är ett separat förlopp från CxF-versionsfelen i våra exporter.

Våra två MXF-exporter är giltig XML med kompletta spektra, men accepterades
inte av i1Profiler. Intern XML-återläsning räckte alltså inte. Flera ändringar
hade gjorts samtidigt. Creator är nu en konkret hypotes, inte en fastställd
rotorsak. Två kontrollfiler isolerar Creator respektive spektral nyttolast.

## Jämförelse

Referens: `InkProf-575-from-TI2-v2_i1profile.mxf`.
Avvisade filer: `InkProf-575-M0.mxf` och `InkProf-575-M0-v2.mxf`.
Samtliga finns i projektets exports-mapp.

| Egenskap | Fungerande referens | Export v1 | Export v2 |
|---|---|---|---|
| Creator | X-Rite - Prism | InkProf | InkProf |
| PrismAppName/PrismAppVersion | i1Profiler / 1.1.0 | Saknas | Återställda |
| XML-deklaration | Dubbla citattecken | Enkla citattecken | Som referens |
| Privat Prism-prefix | xrp, lokalt deklarerat | pr, deklarerat på roten | Som originalmall |
| RGB | Heltal 0–255 | Decimaler från TI2 | Decimaler från TI2 |
| Objekt | 575 M0 + 575 Target | 575 M0 + 575 Target | 575 M0 + 575 Target |
| Spektral specifikation | 380–730 nm, 10 nm, XRGA/M0 | Samma | Samma |
| Layout | 29 kolumner × 20 rader, 1 sida | 21 kolumner, 2 sidor | 21 kolumner, 2 sidor |
| SampleID / SampleName | -1 / tomt | Käll-ID / koordinat | Käll-ID / koordinat |
| MeasurementMode | 1 | 2, ärvt från annan mall | 2, ärvt från annan mall |
| ProfileSettings | Finns | Borttaget | Borttaget |
| WriteProtected | True | False | False |
| Radslut/BOM | LF, ingen BOM | LF, ingen BOM | LF, ingen BOM |

Att v2 också avvisades visar att återställda versionstaggar och XML-huvud
inte ensamma löste problemet. Olika radslut/BOM är inte förklaringen för
dessa konkreta filer. XML tillåter enkla citattecken och alternativa prefix;
att en läsare kan vara känslig för serialisering är en hypotes om mottagaren,
inte ett allmänt XML-krav.

Fler privata attribut skiljer sig, bland annat Media_Type, pappersmått,
titel och skrivarnamn. Referensen anger Translucent Media trots det använda
utskriftsflödet. Sådana privata fält får inte tolkas eller ändras som om deras
semantik vore fullständigt känd.

## Patchkopplingen

Filanalysen har verifierat 575 unika positionsnycklar `(Page, Column, Row)`
för både target och M0-mätningar. Positionsmängderna är identiska. Samtliga
RGB-värden och targetens listordning matchar exakt den PXF som InkProf skapade.
Alla 575 spektra har 36 ändliga värden. Reflektansfaktorn ligger mellan
0,002413 och 1,049892; inget värde har klippts.

Referensen fyller kolumnvis. Första 20 patcharna ligger i kolumn 0, rader
0–19. InkProf-originalet hade två sidor med 21 patchar per rad. Detta är
olika layout, inte i sig ett felaktigt spektrum. En omordning måste flytta
RGB och spektrum tillsammans. Upprepade RGB förekommer, så RGB ensamt är
inte en entydig identitet.

## Vad ChromIQ faktiskt gör

Granskade filer:
- `workflow/i1profiler_export.py`: `write_pxf`, `export_from_ti1`, `write_pwxf`.
- `workflow/i1profiler_import.py`: `parse_pxf`.
- `workflow/reference_convert.py`: `cxf_measurement_to_ti3`.
- `docs/dev_pxwf_format.md`.

PXF-exporten avrundar RGB till 8-bitars heltal, använder TargetN/cN och
WriteProtected=True/ScramblePatches=False. Creator är ChromIQ. InkProf-PXF-v2
följer motsvarande principer och har nu följts genom i1Profiler till en sparad
MXF vars patchuppsättning är verifierad.

PWXF-exporten (workflow, inte MXF) använder däremot Creator=X-Rite - Prism,
Description=Prism CXF3 file och PrismApp-versionstaggar. Kodkommentaren anger
att headern speglar originalet för att workflow-läsaren ska acceptera filen.
Det ger stöd för att prova Creator separat även i MXF, men bevisar inte att
MXF-läsaren har samma krav. ChromIQ-dokumentets äldre råd säger att behålla
ChromIQ som Creator tills ett importprov visar annat; den aktuella koden
använder alltså en mer konservativ header än det dokumentrådet.

I den granskade workflow-koden hittades MXF-import, PXF- och PWXF-export,
men ingen motsvarande MXF-skrivare att behandla som verifierad lösning.
MXF-importen väljer en tillgänglig mätgrupp, parar listor efter ordning,
antar 10 nm våglängdssteg, räknar XYZ under D50 och skriver TI3 med RGB/XYZ.
Den skriver inte ut spektralkolumner eller bevarar fysisk SAMPLE_LOC. Därför
ska InkProf inte kopiera den vägen för ett förlustfritt MXF-utbyte.

## Två kontrollerade importprov

Filerna finns i `exports/mxf-compatibility-tests/`, med JSON-proveniens:

1. **01-Creator-only.mxf**: exakt samma byte som fungerande referens, förutom
   Creator som ändrats från X-Rite - Prism till InkProf. Alla mätvärden är
   referensens ursprungliga värden. Om endast denna fil avvisas isolerar det
   Creator-beroendet i detta flöde.
2. **02-Spectra-only.mxf**: exakt samma referensfil utanför de 575 spektrala
   textfälten. Där har InkProfs kompletta M0-mätning från 09:58 satts in, med
   procent dividerat med 100 och verifierat numeriskt återläsningsfel under
   1e-8 i procentenheter. Targetordning kontrolleras mot käll-ID och alla RGB;
   mätobjekt kopplas till target via positionsnycklar. Ingen omordning eller
   positionsändring görs i referensfilen.

Kontroll 2 behåller uttryckligen referensens Creator, datum, layout och
privata inställningar som experimentkontroller. Det är en InkProf-genererad
**diagnosfil**, inte korrekt fullständig produktionsproveniens för InkProf-
utskriften. JSON anger faktisk källa, referenshash, exporthash och kopplingen
mellan originalets och referensens koordinater. Använd den inte som mall för
att mäta om InkProf-originalets papper.

Prova med samma kalibrerade instrument-/appläge som den fungerande referensen.
Om Creator-provet avvisas och spektralprovet accepteras är headern en tydlig
förklaring. Om båda accepteras ligger felet bland övriga ändringar och dessa
ska införas en i taget. Om spektralprovet avvisas undersöks först nyttolastens
numeriska format och mottagarens krav, utan samtidiga layoutändringar.

Ingen av kontrollfilerna har ännu verifierats genom mottagarimport.

## Komplettering: RGB och Glossy/Matte

Kontroll av referensen och den avvisade v2-exporten visar samma
`ColorSpace="RGB"` och `Paper="Glossy"`. Dessa val är inte en särskiljande
felorsak. RGB är fast för InkProf. Glossy/Matte kan bli ett användarval i ett
senare steg; importerade uppgifter ska bevaras, medan saknad papperstyp inte
ska gissas från exportmallen. Betydelsen för mottagarens profilberäkning
återstår att verifiera. Se [MXF-specifikationen](mxf.md).
