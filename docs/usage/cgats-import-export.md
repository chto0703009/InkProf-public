# CGATS-import och export

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

## Varning: externa utskrifter utan kontrastmarkörer

**Mål som skrivits ut utan kontrastmarkörer mellan patcharna kan ge problem vid radmätning med chartread**, särskilt när intilliggande patchar har snarlika färger. Det kan exempelvis ge fel om för få eller för många patchar. En korrekt importerad patchdefinition garanterar inte att det befintliga arket går att läsa tillförlitligt.

**Rekommenderat arbetsflöde:** importera patchdefinitionerna som TI1/TI2 i första hand, eller generell CGATS från ett annat program, och låt InkProf generera en ny TIFF16-utskrift med kontrastmarkörer och matchande TI2/JSON. Använd sedan just det nya utskriftspaketets TI2 vid mätningen. Kontrastmarkörer minskar risken för segmenteringsproblem men garanterar inte felfria svep.

En import eller omordning i programmet ändrar inte ett redan utskrivet ark. Om det befintliga arket mäts i ett annat program kan dess mätfil importeras separat med bevarad patchkoppling.


InkProf kan läsa och skriva CGATS-text för patchdefinitioner och mätdata. Samtliga tabeller, kolumner, textvärden och metadata bevaras. Argyll CTI1/CTI2/CTI3 och i1Profilers CGATS.17 använder samma läsare. Filändelsen avgör inte innehållet.

## Rekommenderade importformat för RGB-patchdefinitioner

1. **TI1/TI2 är förstahandsval.** TI1 beskriver patchdefinitioner; TI2 används när en befintlig målbeskrivning med patchpositioner ska följa med.
2. **Generell CGATS rekommenderas från andra program** när TI1/TI2 inte erbjuds. En textfil med exempelvis ändelsen `.txt` kan innehålla CGATS. Ange RGB-skalan uttryckligen enligt källan, exempelvis `RGBScale=255` för den provade exporten från i1Profiler.
3. **CxF, PXF och TXF är kompletterande alternativ** för stödda varianter. CxF kan vara lämpligt när mer strukturerad färg- och mätmetadata behöver bevaras.

Prioriteringen gäller patchdefinitioner. Mätdata hanteras separat, bland annat via TI3 och positionerad MXF. Inget format garanterar i sig utskriftslayout: en patchlista utan positioner kan användas för ett nytt InkProf-mål med kontrastmarkörer, men beskriver inte automatiskt ett redan utskrivet ark. Ursprungliga ID, RGB-värden och relevant metadata ska bevaras vid import.

## Patchdefinition till och från CGATS

```matlab
paths = setupInkProf();
target = inkprof.importTarget('min-definition.ti1');
inkprof.exportCgats('patchar.cgats', target);

% Ange källans RGB-skala uttryckligt: 100 för procent, 255 för 8-bitarsvärden.
folder = fullfile(paths.Projects, 'cgats-target');
inkprof.createTarget(folder, Source='patchar.cgats', RGBScale=100, ...
    Paper='A3-portrait', Randomize=true, Seed=42, DPI=300);
```

Export av ett `inkprof.target` skriver CGATS.17 med SAMPLE_ID, SAMPLE_NAME och ursprungliga RGB-värden med 17 signifikanta siffror. RGB_SCALE sparas som ett eget deklarerat nyckelord. Andra program behöver inte förstå detta nyckelord; skalan måste avtalas vid utbyte. ImportTarget kräver fortfarande explicit RGBScale för generell CGATS. Denna patchlista innehåller ingen fysisk layout.

`createTiff16` skriver därför två kompletterande CGATS-filer. `*-patches.cgats` innehåller källpatcharna i källordning. `*-layout.cgats` innehåller utskriftens fysiska ordning, `SAMPLE_LOC`, en uttrycklig utfyllnadsflagga och RGB-värden på skalan 0–100. För mätning används fortfarande paketets TI2; CGATS-filerna är neutrala utbytes- och kopplingsunderlag.

## Mätdata, inklusive spektra

```matlab
doc = inkprof.importCgats('matning-M0.txt');
data = inkprof.cgatsData(doc, RGBScale=255, SpectralScale=1);

% Exempel: den verifierade i1Profiler-exporten använder 0–255 RGB
% och reflektansfraktioner. Ange inte dessa skalor för andra filer utan kontroll.
rgb = data.rgbPercent;
wavelengths = data.wavelengthNm;
reflectance = data.spectralFraction;

inkprof.exportCgats('matning-kopia.txt', doc);
```

`cgatsData` ger också `ids`, `locations`, `rgb`, `cmyk`, `xyz` och `lab`. Med `XYZScale=100` eller `XYZScale=1` får man `xyz100`. Utan explicit skala är respektive normaliserad matris tom; råa numeriska värden finns kvar. SpectralScale används för reflektans/transmittans, inte för emissionsenheter. Värden över 100 % och små negativa spektralvärden klipps inte bort.

SPEC_380 och SPECTRAL_NM380 identifieras som spektralfält. Den numeriska vyn sorterar våglängder stigande och behåller kopplingen till rätt värden. Originaltabellen ändras inte. Deklarerade SPECTRAL_BANDS/START_NM/END_NM kontrolleras mot kolumnerna. Ingen spektral interpolation eller omräkning till XYZ/Lab görs.

M0/M1/M2, instrument, XRGA, observatör och belysning bevaras där de finns i källans metadata. Saknade villkor fylls inte i. Flera mätvillkorsfiler hålls separata; importen slår inte ihop mätningar eller kopplar dem automatiskt till ett target. Upprepade ID:n bevaras och `idsUnique` visar om en entydig ID-koppling är möjlig. CTI1/CTI2:s färgvärden märks som targetuppskattningar, inte mätningar.

## Flera tabeller och egen data

`doc.tables(k)` innehåller `signature`, `metadata` (ordnad cellista av strängvektorer), `fields` och `data` (strängmatris). Ändra dessa för att exportera bearbetade data; de numeriska värdena från `cgatsData` är en separat vy. Använd `compose('%.17g', values)` för nya flyttalsvärden i tabellens data. `Table=2` väljer nästa tabell i `cgatsData`. Argylls hjälptabeller bevaras, liksom okända fält och upprepade KEYWORD-rader.

`rawText`, källsökväg och SHA256 sparas i dokumentobjektet för spårbarhet. Originalfilen ändras inte. Spara originalet tillsammans med projektets data; en källsökväg ensam gör inte projektet självständigt. Export skriver aldrig över en befintlig fil, regenererar rad-/fältantal, läser tillbaka och jämför tabellerna innan filen publiceras.

## Avgränsningar

- Detta är tabellbaserad CGATS-text, inte en full implementation av varje CGATS/ISO-variant. Signatur krävs för varje tabell; godtyckliga BEGIN/END-utökningar avvisas.
- Kommentarer och ursprunglig whitespace finns i rawText men återskapas inte i den normaliserade exporten. Metadata och datacellernas textvärden bevaras.
- Strängar med inbäddade citattecken eller radbrytningar avvisas uttryckligt.
- Export av ett CGATS-dokument behåller dess signatur och fältnamn. Att döpa om en CGATS.17-fil till `.ti3` konverterar den inte till Argylls format. Automatisk dialektkonvertering, inklusive i1Profiler-spektra till TI3, ingår inte i detta API.
- Numerisk kontroll sker med cgatsData; den generella dokumentläsaren får även bära textkolumner och okända datatyper utan att tolka dem.
- Detta ersätter inte matchande TXF-export för mätning av samma utskrift i i1Profiler. Fysisk mätning och import i mottagarprogram har inte verifierats med dessa exporter.

## Tester

`runtests('tests/testCgats.m')` provar de tre verkliga i1Profiler-exporterna M0/M1/M2 (2040 × 36 spektralvärden vardera), patchimport/export med 2033 patchar, flera tabeller, Lab, upprepade ID:n/nyckelord, tomma strängar, kommentarer, okända metadata och felaktiga tabeller/spektra. Den befintliga targetsviten provar samtidigt Argylls CTI1/CTI2-filer med hjälptabeller.
