# 004 - Intern JSON och Argyll som primära utbytesformat

Datum: 2026-09-25. Uppdaterat: 2026-09-26. Status: beslutad datamodell; targetflöde och mätprototyp finns, full mätexport återstår.

## Beslut

**JSON är InkProfs auktoritativa interna modell för chart, mätningar och härledda resultat.** MATLAB använder strukturer och numeriska arrayer under beräkning. ArgyllCMS `.ti1`, `.ti2` och `.ti3` är primära utbytesformat. Filadaptrar omvandlar mellan dessa och den interna modellen; importerade original bevaras som proveniens.

| Format | Primär roll i InkProf |
|---|---|
| `.ti1` | Patchdefinition och enhetsstyrvärden före layout. |
| `.ti2` | Slutlig targetdefinition med patcharnas placering, kopplad till utskriftsbilden. |
| `.ti3` | Styrvärden och mätresultat, inklusive spektra när sådana finns. |
| `.json` | Intern chart-/mätmodell, resultat, beräkningsvillkor, spårbarhet och manifest. |
| TIFF16 | Utskrivbar bild som motsvarar TI2. |
| Generell CGATS | Neutralt utbyte av källpatchar, fysisk layout och senare mätdata; inte primär projektsanning. |
| TXF-kandidat | Valbart kompatibilitetsunderlag före mätning när värdena kan representeras exakt; inte godkänt förrän mottagarens layout har verifierats. |

PXF/TXF/MXF/CMXF och andra CGATS-varianter hanteras genom import-/exportadaptrar i takt med att de implementeras och verifieras; alla beskrivna format har ännu inte fullständigt stöd. De är inte InkProfs primära arbetsformat. Originalfilerna bevaras ändå oförändrade för spårbarhet och för information som Argyll-formaten inte kan representera.

## Första leveransen

```text
Argyll targen eller importerad patchdefinition
                  ↓
TI1 + JSON med importmetadata och kontroller
                  ↓
Layout och valbar randomisering
                  ↓
TIFF16 + matchande TI2 + CGATS-utbyte + JSON-manifest
                  ↓
valbar TXF-kandidat när precision och mall tillåter
```

Mätprototypen läser TI2 till `chart.json`, exporterar TI2 från JSON vid start av chartread och läser TI3-resultat till nya JSON-resultat. Se [mätanvisningen](../usage/chart-measurement.md). Full export av mätresultat till andra format återstår. Skilda mätvillkor ska bevaras och vid behov exporteras i separata filer.

## Regler för JSON

Följande är krav för det schema som ska fastställas vid implementation:

- Versionsmärkt dokumenttyp och schema.
- Referenser till ursprungsfiler med innehållskontrollsummor, samt patch-ID och eventuell ordnings-/positionsmappning.
- Angivna kanalnamn, enheter, värdeskalor och våglängder där dessa behövs.
- För färgberäkningar: belysning, observatör, referensvit, normalisering och beräkningsversion.
- Numerisk serialisering som bevarar MATLAB `double` vid återinläsning; detta ska provas. Export till ett annat formats lägre precision redovisas separat.
- Saknade värden representeras med en uttrycklig status och vid behov `null`. JSON ska inte innehålla ostandardiserade `NaN`- eller `Infinity`-tal.
- Härledda resultat hålls skilda från originalmätningar. Ett resultat ersätter inte sin källa.

Exporterade filer får inte bli en konkurrerande projektsanning. Varje export binds till en bestämd JSON-version; importer binds även till originalfilens hash. Ändrad patchordning, layout eller kvantisering skapar en ny sammanhängande uppsättning filer; gamla beräkningar ska kunna identifieras som inaktuella.

## Information som inte får förloras

TI2 och TIFF16 ska ha identisk slutlig patchplacering även efter randomisering. JSON-manifestet bevarar dessutom slumpfrö, verktygsversion och faktisk koppling mellan logiska patchar och fysiska positioner.

Vid mätkonvertering ska spektra behållas i TI3 när den valda exporten stöder dem. JSON och originalfilen kan bevara ytterligare metadata, men en export som tappar spektra får inte betecknas som förlustfri.

Ingen konvertering av koordinater, vitpunkt eller RGB-arbetsrymd ska ske enbart därför att filformatet ändras. Sådana beräkningar görs separat och dokumenteras i JSON.

## Relaterade dokument

- [Första leveransen: TIFF16 och mätunderlag](../planning/first-delivery-target-tiff16.md)
- [Argylls TI1, TI2 och TI3](../research/argyll-ti1-ti2-ti3.md)
- [Datautbyte med i1Profiler och ChromIQ](../research/i1profiler-interchange/README.md)
- [Återanvändning av färgberäkningar](../research/colorimetry-reuse-camera41-spectralab.md)
