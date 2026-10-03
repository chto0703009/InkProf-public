# CxF3-inläsning

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

För RGB-patchdefinitioner rekommenderas TI1/TI2 i första hand och generell CGATS från andra program. CxF är ett kompletterande alternativ, särskilt för strukturerad metadata; se [formatprioriteringen](cgats-import-export.md#rekommenderade-importformat-för-rgb-patchdefinitioner).

Implementerad 2026-09-28. Inläsaren utgår från **ISO 17972-1:2015 / CxF3**.
Den validerar med det oförändrade CxF3 core-schemat 3.0.018 och kontrollerar
värden/referenser. Det är inte certifiering av samtliga ytterligare CxF/X-krav
eller workflow-delar i ISO 17972. CxF/X-4 för dekorfärger ska inte likställas
med allmän RGB-targetimport.

```matlab
setupInkProf();
[data, jsonFile] = inkprof.readCxF( ...
    '/Users/christer/Desktop/InkProf-575-from-TI2-v2.cxf', ...
    OutputFile='/Users/christer/Desktop/InkProf-575-cxf.json');
```

OutputFile är valfri; utelämna den för enbart inläsning i minnet. Befintlig
utdata skrivs inte över. `inkprof.readCxF()` öppnar filval.
För patchdefinition till målrenderingen:

```matlab
target = inkprof.importTarget('/Users/christer/Desktop/InkProf-575-from-TI2-v2.cxf');
inkprof.renderTarget(); % välj samma CxF som input
```

Detta skapar vid rendering en **ny** layout och matchande mätunderlag.
Använd inte den nya layoutens TI2 för ett äldre utskrivet ark.

## Vad bevaras och tolkas?

- RGB med CxF-fältet MaxRange; om det saknas används CxF3:s standard 255.
  Ett motsägande RGBScale-argument avvisas. Blandade MaxRange-värden läses
  generellt men kräver explicit normalisering före målimport.
- Lab och XYZ bevaras som filens värden med länk till ColorSpecification.
  Ingen D50, observatör, profil eller mätroll antas när den saknas.
- Reflektansspektrum bevaras i CxF-skala: **1 = 100 %**. Värden över 1 kan
  förekomma; ingen klippning görs. Schemat tillåter intervallet (-0,1; 3).
  Våglängder kommer från specifikationens StartWL/Increment med eventuell
  StartWL-override på spektrumet. Saknad våglängdsdefinition markeras;
  ingen integration sker då.
- Objekt-ID, namn, ObjectType, färgspecifikationer, profiler, metadata,
  egna resurser och ursprunglig XML sparas i JSON. Källfilens SHA256 följer med.
  Ej numeriskt tolkade färgtyper bevaras med varning.
- CMYK avvisas enligt InkProfs RGB-avgränsning. DTD/externa entiteter avvisas.
  CxF1/CxF2 stöds inte. UTF-8 krävs av den semantiska Python-inläsaren.
- MATLAB Base validerar XSD med Java; Python-standardbiblioteket avkodar data.
  Inget extra Python-paket eller X-Rite SDK behövs. Direkt Python-anrop markerar
  uttryckligen `xsdValidated=false`; den publika MATLAB-rutinen validerar först.

Generell CxF läses till ett bevarande JSON-dokument, inte automatiskt till en
färdig ICC-mätning. Mätvillkor, RGB-koppling och eventuell fysisk layout måste
vara tillräckliga före senare export/profilering. Befintlig positioned MXF-import
har fortsatt sitt särskilda kontrollerade flöde.

## Patch-ID kontra fysisk placering

CxF-objektets ID är färgens identitet. Koordinaten på arket är en separat
koppling. Pappersstorlek, patchstorlek, marginaler, antal rader/kolumner,
placeringsordning, eventuell randomisering och tomma positioner behövs för
att entydigt återskapa ett utskrivet mål. Mått räcker inte ensamma.

Den tillförda `InkProf-575-from-TI2-v2.cxf` innehåller 575 RGB-objekt, inga
mätningar och inga individuella patchkoordinater. RGB-värden och ordning
matchar tidigare PXF exakt. Prism-fälten anger bland annat 0 rader/kolumner,
2 sidor och i1Pro 3; de bevaras som **källdata, inte verifierade uppgifter om
utskriften eller instrumentet**. Den faktiskt kända ensidiga layouten kommer
från tidigare MXF. Dess explicita positioner får länkas till CxF endast efter
kontroll av samma färgsekvens. Gamla spektra ska inte kopieras till en ny mätning.

En korrekt filadapter kan inte förbättra kontrasten på det tryckta arket eller
garantera att chartread särskiljer snarlika grannpatchar.

## PXF och standardkällor

De PXF-exempel som hittills provats i InkProf är läsbar CxF3-baserad XML,
inte krypterade. Filändelsen avgör inte innehållet; andra varianter kan finnas.
Ingen dekryptering ingår i InkProf.

- [ISO 17972-1:2015](https://www.iso.org/standard/61500.html)
- [X-Rites CxF-resurser](https://www.xrite.com/page/cxf-color-exchange-format)
- [CxF3 schema och licens, Colour Developers spegling](https://github.com/colour-science/colour-cxf)
- Oförändrat schema och exakt ursprung: `schemas/cxf3/provenance.json`.
- Separat schemalicens och attribution: `THIRD_PARTY_NOTICES.md`.

### Koppla en befintlig utskriftslayout

`readCxF(..., LayoutFile=matchingMXF)` kan koppla en CxF-definition till explicita
Target-positioner i en separat CxF3/MXF. Antal, RGB-värden och hela ordningen
måste matcha. Inga färgnärmaste gissningar, omordningar eller gamla mätvärden
används. Sidnummer och koordinater sparas under `layout.mapping` tillsammans
med källhash. Det är användarens val av matchande utskrift, inte ett bevis från
RGB-likhet ensamt. Inga tomma fält blir patchar. Detta skapar inte automatiskt
en chartread-kompatibel TI2 för oregelbundna rader.

## Verifierat 2026-09-28

Sex Python-tester och fyra MATLAB-tester passerade. Användarens 575-CxF
passerade XSD-validering; RGB-värden och ordning matchar PXF exakt. Explicit
MXF-layout ger 29 patchar på rad 1–15 och 28 på rad 16–20. Hela flödet
CxF → målimport → ny TIFF/TI2 testades i arbetsmapp vid 100 ppi. Detta är
ett programtest, inte en ny utskrift eller fysisk mätverifiering.

Källfil och JSON med layoutkoppling är sparade lokalt i
`projects/Canon-575-20260927/sources/cxf-20260928/`.
