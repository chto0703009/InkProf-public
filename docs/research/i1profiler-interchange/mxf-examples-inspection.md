# Tre verkliga MXF-referensfall för mätimport

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Datum: 2026-09-25. Status: XML-innehåll granskat; ingen färdig InkProf-import, TI3-export eller återimport i i1Profiler har provats.

Christer har valt tre filer ur i1Profilers lokala datamappar. Oförändrade referenskopior finns under `tests/fixtures/i1profiler/mxf-examples/`. De används som exempeldata, inte som belägg för en ny instrumentmätning eller som InkProf-kod. Filernas ursprung och eventuella externa rättigheter kvarstår.

## Innehåll

| Fil | Target | Mätgrupper | Faktiska värden |
|---|---|---|---|
| `TC1617-CRPC-1.mxf` | 1 617 CMYK-patchar | M1: 1 617 objekt | CIELAB, inga spektra. |
| `Hm_WTu_23-11-23.mxf` | 1 445 RGB-patchar | M0, M1, M2: 1 445 objekt vardera | 4 335 spektra, 36 band per spektrum. |
| `Chart 2040 Patches.mxf` | 2 040 RGB-patchar | M0, M1, M2: 2 040 objekt vardera | 6 120 spektra, 36 band per spektrum. |

Filerna använder namnrymden `http://colorexchangeformat.com/CxF3-core`. Alla observerade `ColorSpecification`-referenser kan lösas till en specifikation i respektive fil.

De två RGB-filerna anger `StartWL="380"` och `Increment="10"` i specifikationens `WavelengthRange`. Tillsammans med 36 värden ger det **380–730 nm med 10 nm steg**. Detta är läst ur dessa filer, inte ett generellt antagande för MXF.

Observerade spektrala värdeintervall är 0,016680–0,939419 för Hm-filen och 0,016108–0,934610 för Chart 2040, över samtliga tre grupper. Värdena bevaras i källans reflektansfaktorkodning. En framtida konvertering till procent ska vara uttrycklig och verifierad mot CxF-/TI3-kontrakten; enbart min/max får inte styra skalan.

## Viktig skillnad: deklaration är inte innehåll

TC1617-filen deklarerar `MeasurementType=Spectrum_Reflectance`, men har **inga `ReflectanceSpectrum`-element**. Dess 1 617 mätobjekt innehåller `ColorCIELab`.

Importören måste därför kontrollera de faktiska värdeelementen. Filen kan användas för kolorimetriskt underlag när referensvillkoren är fastställda, men inte för spektral modellering. Spektra får inte konstrueras ur Lab och betecknas som mätningar.

Inga explicita element för beräkningsilluminant, observatör eller `ColorimetricSpec` hittades i dessa tre filer. För CMYK-filens Lab behöver därför referensvillkoren fastställas från verifierad producentkonvention eller annat underlag. M1 är ett mätvillkor och ersätter inte denna kontroll.

## Så kan patcharna kopplas

Varje target- och mätobjekt har platsdata i följande struktur:

```text
Object
  @Id, @Name, @ObjectType
  TagCollection @Name="Location"
    Tag @Name="Page"       @Value="..."
    Tag @Name="Row"        @Value="..."
    Tag @Name="Column"     @Value="..."
    Tag @Name="SampleID"   @Value="..."
    Tag @Name="SampleName" @Value="..."
```

Detta är **inte ett element som heter `Location`**. En importör måste även känna igen platsuppgifter i `TagCollection`, annars missas den faktiska kopplingen.

Kontroll av samtliga objekt visade:

- Kombinationen `(Page, Row, Column)` är unik inom varje target- respektive mätgrupp i alla tre filer.
- Varje mätgrupp har exakt samma uppsättning positioner som sitt target. Positionerna ligger dessutom i samma listordning i just dessa filer.
- I TC1617 är `SampleID` unika 1–1617 inom varje grupp.
- I båda RGB-filerna är **alla `SampleID=-1`**. Fältet är därför oanvändbart som ensam kopplingsnyckel.
- XML-objektens `Id` är olika för target och mätning. Exempelvis är första targetobjektet i Chart 2040 `c6121`, medan första M0-, M1- och M2-objektet är `c1`, `c2041` respektive `c4081`.

**Föreslagen adapterregel för dessa referensfall:** koppla per fil/target och mätgrupp med den verifierade positionsnyckeln. Bevara objekt-ID och originalordning som separata uppgifter. Vid dubbletter eller saknade positioner ska kopplingen stoppas eller kräva ett annat verifierat kontrakt; använd inte automatiskt radnummer eller RGB som ersättning.

## Mätvillkor och upprepade värden

RGB-filerna har separata specifikationer med `M0_Incandescent`, `M1_Daylight` och `M2_UVExcluded`. De anger XRGA och vinkeluppgifter 0° belysning/45° mätning. Detta är vad filerna deklarerar, inte en ny kvalificering av instrumentet.

Grupperna får inte kollapsas till en enda mätserie. De är inte heller tre identiska kopior:

| Fil | Exakt lika spektra M0/M1 | Exakt lika spektra M0/M2 | Största kanalvisa skillnad M0/M1 | M0/M2 |
|---|---:|---:|---:|---:|
| Hm_WTu | 682 av 1 445 | 690 av 1 445 | 0,017078 | 0,029789 |
| Chart 2040 | 621 av 2 040 | 625 av 2 040 | 0,028971 | 0,050535 |

Jämförelsen avser numeriska spektralvärden för motsvarande positioner. Att vissa är identiska säger inte i sig varför de är lika. Bevara dem tillsammans med sina mätvillkor; deduplicera inte bort deras betydelse.

## Optimeringsfilens särskilda information

Hm-filen ligger i `OptimizationMeasurements` och innehåller `OptimizeProfile` med sökvägen `/Users/christer/Library/ColorSync/Profiles/Hm_WTu_23-11-23.icc`. Det är en profilreferens i metadata, inte den inbäddade ICC-profilens innehåll. InkProf ska bevara referensen som proveniens utan att kräva att den lokala sökvägen finns för att läsa själva spektrumen.

RGB-filernas metadata anger i1Pro 2 och mätobjekten är daterade 2023-11-23. TC1617 anger i1Pro med serienummer 0 och datum 2019-11-25. Eftersom filerna kan innehålla levererade eller tidigare importerade data ska dessa fält bevaras som uppgifter från filen, inte antas bevisa hur eller av vem mätningen utfördes.

## Föreslagna konverteringar

- **TC1617 → TI3:** CMYK + Lab, utan spektrala kolumner. Fastställ Lab-referensvillkoren före profilering. Metadata som påstår spektral mätning får inte användas för att rapportera spektra som tillgängliga.
- **Hm_WTu och Chart 2040 → TI3:** separata, spektrala TI3-filer för M0/M1/M2 med ett JSON-manifest som håller samman original, positionskoppling och villkor. Bevara alla band och explicit värdeskala.
- **XYZ/Lab från RGB-filernas spektra:** beräkna med InkProfs planerade egna kolorimetrirutiner med uttrycklig illuminant och observatör, i ett separat versionsmärkt resultat. Mätningens originalspektrum ändras inte.

Detta utökar mätimportens referensunderlag men ändrar inte första leveransens avgränsning: targetgenerering och TIFF16 kommer före integrerad mätning och analys.

## Föreslagna regressionstester

1. Rätt antal target och mätningar för varje villkor.
2. Platsbaserad koppling ska fungera även om mätobjektens listordning ändras i en testkopia.
3. `SampleID=-1` får inte slå ihop patchar eller orsaka felkoppling.
4. TC1617 rapporteras som Lab-baserad, trots spektral deklaration.
5. Alla RGB-spektrums 36 band och alla tre villkor bevaras vid export och återinläsning.
6. Förlustrapport visar eventuell omskalning, härledd kolorimetri och ej överförda metadata.

Originalkällor:

```text
/Library/Application Support/X-Rite/i1Profiler/ColorSpaceCMYK/Measurements/TC1617-CRPC-1.mxf
/Library/Application Support/X-Rite/i1Profiler/ColorSpaceRGB/OptimizationMeasurements/Hm_WTu_23-11-23.mxf
/Library/Application Support/X-Rite/i1Profiler/ColorSpaceRGB/Measurements/Chart 2040 Patches.mxf
```

Se även [MXF-kontraktet](mxf.md) och [gemensamma utbytesregler](README.md).
