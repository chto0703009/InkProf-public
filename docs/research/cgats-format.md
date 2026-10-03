# CGATS: utbyte av färg- och mätdata

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Datum: 2026-09-25

## Vad betyder CGATS?

CGATS står för **Committee for Graphic Arts Technologies Standards**, en standardiseringskommitté för grafisk teknik. I färgmätningssammanhang används namnet också om textbaserade utbytesformat för färgdata. Kommittén och filformaten är alltså inte samma sak. [1]

En CGATS-baserad datafil kan beskriva patchar, styrvärden, kolorimetriska värden och spektrala mätningar. Den är ett sätt att lagra och utbyta data, inte en ICC-profil eller en algoritm för färgomvandling.

## Standarder och varianter

ArgyllCMS hänvisar till **CGATS.5 Data Exchange Format**, från Annex J i ANSI CGATS.5-1993. Argylls `.ti1`, `.ti2` och `.ti3` använder denna grundstruktur med egna krav på innehållet. [2]

**CGATS.17** förekommer också som beteckning på standardiserat textutbyte av färgmätdata, bland annat i X-Rites dokumentation. [3] **ISO 28178:2022** definierar utbyte av färg- och processkontrolldata samt tillhörande metadata i XML eller ASCII-text. Den omfattar främst spektrala, kolorimetriska och densitometriska data. [4]

Dessa beteckningar ska inte behandlas som om alla filer vore identiska. Identifierare, fältnamn, obligatoriska metadata och tillåtna utökningar kan skilja sig. InkProf behöver uttryckligen ange vilka varianter som stöds. Detta dokument är en praktisk översikt, inte en fullständig återgivning av standarderna.

## Textfilens uppbyggnad

I Argylls CGATS-baserade textfiler används följande huvuddelar:

| Del | Betydelse |
|---|---|
| Filidentifierare | Anger variant, exempelvis `CTI3` för Argylls `.ti3`. |
| Nyckelord och värden | Beskriver filen och hur data ska tolkas. |
| `NUMBER_OF_FIELDS` | Antal kolumner i tabellen. |
| `BEGIN_DATA_FORMAT` / `END_DATA_FORMAT` | Avgränsar listan med kolumnnamn. |
| `NUMBER_OF_SETS` | Antal datarader. |
| `BEGIN_DATA` / `END_DATA` | Avgränsar själva tabellen. |

Argyll använder bland annat `SAMPLE_ID`, `RGB_R`, `XYZ_X`, `LAB_L` och spektrala fält som `SPEC_500`. Kolumnernas namn anger vad värdena betyder; de får inte identifieras enbart utifrån position. [5]

### Illustrativt exempel

Följande är ett litet, **syntetiskt exempel i Argylls TI3-variant**. Värdena är påhittade och får inte användas som kalibrering eller profilunderlag. Exemplet innehåller XYZ, inte spektra.

```text
CTI3
DESCRIPTOR "Synthetic RGB example - not measured"
ORIGINATOR "InkProf documentation"
DEVICE_CLASS "OUTPUT"
COLOR_REP "RGB_XYZ"

NUMBER_OF_FIELDS 7
BEGIN_DATA_FORMAT
SAMPLE_ID RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z
END_DATA_FORMAT

NUMBER_OF_SETS 2
BEGIN_DATA
1 100.0 100.0 100.0 90.0 93.0 76.0
2 50.0 50.0 50.0 20.0 21.0 17.0
END_DATA
```

Här är styrvärdena procentvärden enligt TI3-konventionen. Värdet `50.0` ska alltså inte tolkas som 50 av 255. För andra varianter och leverantörsexporter måste värdeskalorna fastställas utifrån deras definitioner. [5]

## Förslag till importprinciper i InkProf

Följande anger principerna. En generell tabellimport/export är nu implementerad; se [API, tester och kvarvarande begränsningar](../usage/cgats-import-export.md). Automatisk formatkonvertering och koppling till target återstår:

1. **Identifiera varianten från innehållet.** Filändelsen ensam räcker inte.
2. **Läs metadata och tabellstruktur.** Hantera citattecken, kommentarer och eventuella flera tabeller enligt den variant som stöds.
3. **Kontrollera fält- och radantal.** Avvikelser ska rapporteras, inte tyst korrigeras.
4. **Bevara patchidentiteter.** Koppla mätning till target genom identifierare och dokumenterad layout, inte enbart radordning. Upprepade mätningar behöver kunna särskiljas.
5. **Fastställ enheter och normalisering.** Skilj exempelvis mellan RGB 0–100 och 0–1, samt mellan reflektans som andel och procent. Gissa inte enbart från min- och maxvärden.
6. **Kontrollera spektral information.** Våglängder, antal band och värden måste vara förenliga innan spektrala beräkningar görs.
7. **Registrera mät- och beräkningsvillkor.** Belysning och observatör för XYZ/Lab måste skiljas från instrumentets mätvillkor. Saknade uppgifter ska markeras som okända, eller hanteras enligt en uttryckligt dokumenterad formatregel.
8. **Bevara original och okända metadata.** Spara ursprungsfilen oförändrad. Dokumentera konverteringar till InkProfs interna representation.

En importerad tabell ska också skilja mellan uppmätta, uppskattade och simulerade värden. En välformad fil garanterar inte att dess innehåll är korrekt eller fysiskt uppmätt.

## Kopplingen till övrig dokumentation

CGATS beskriver grunden för datautbytet. Argylls `.ti1`, `.ti2` och `.ti3` ger filerna särskilda roller i arbetsflödet: targetvärden, targetlayout och mätresultat. Se det separata dokumentet **ArgyllCMS: filformaten .ti1, .ti2 och .ti3** i samma dokumentationsmapp.

För InkProf blir huvudprincipen att läsa etablerade format, normalisera data kontrollerat och bevara mätvillkor och spårbarhet. Själva profileringen sker först efter denna tolkning och validering.

## Källor

1. [APTech: Committee for Graphic Arts Technologies Standards](https://printtechnologies.org/standards/) – kommitténs namn och roll.
2. [ArgyllCMS: File formats](https://www.argyllcms.com/doc/File_Formats.html) – CGATS-grunden och Argylls format.
3. [X-Rite: CxF Standard, Annex A](https://www.xrite.com/-/media/xrite/files/literature/misc/c/cxf_standard_en.pdf) – hänvisning till ANSI CGATS.17-2005 som textformat för färgmätdata.
4. [ISO 28178:2022](https://www.iso.org/standard/82264.html) – standardens omfattning enligt ISO:s offentliga beskrivning; full standardtext har inte granskats här.
5. [ArgyllCMS: TI3 file format](https://www.argyllcms.com/doc/ti3_format.html) – struktur, identifierare, fält och skalor för TI3.

## Verifierad i1Profiler-export

[Granskningen av i1Profiler 3.8.5](i1profiler-interchange/ui-verification-3.8.5.md) visar en spektral CGATS.17-export med separata M0/M1/M2-filer. RGB är 0–255, spektra är reflektansfraktioner med fyra decimaler och fältnamnen är SPECTRAL_NM380 till SPECTRAL_NM730. Detta kräver explicit skalning och fältnamnsöversättning vid TI3-export.
