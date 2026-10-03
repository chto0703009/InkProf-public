# Referensfall: Chart 2033 Patches

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Granskat 2026-09-25. Originalfiler tillhandahållna av Christer från i1Profiler. Exakt i1Profiler-version är ännu inte angiven. Ingen import tillbaka i i1Profiler eller fysisk mätning har genomförts.

**Senare komplettering samma dag:** en TXF har nu tillkommit och granskats separat i [TXF-anteckningen](chart-2033-txf-inspection.md). Uppgifter nedan om avsaknad av TXF beskriver det första underlaget med två filer.

## Filer och bevarande

Originalen finns oförändrade under `tests/fixtures/i1profiler/chart-2033/` i InkProf:

- `Chart 2033 Patches.pxf`
- `Chart 2033 Patches.txt`

Filerna är targetdefinitioner, inte mätresultat. Referensdata från ett externt program ska inte betraktas som InkProf-kod eller ges nya rättighetsanspråk genom kopieringen.

## Kontrollerade resultat

| Kontroll | Resultat |
|---|---|
| PXF-format | XML med namnrymden `http://colorexchangeformat.com/CxF3-core`. |
| PXF-producent | `X-Rite - Prism`. |
| TXT-format | `CGATS.17`, producent `i1Profiler - X-Rite, Inc.`. |
| Patchantal | 2 033 i båda; TXT deklarerar också 2 033 rader. |
| ID | PXF `c1`–`c2033`, TXT `1`–`2033`, i följd. |
| Kanaler | RGB, värden i intervallet 0–255 i detta referensfall. |
| Helt lika RGB-rader | 23 av 2 033. |
| Avvikande kanalvärden | 4 861 av 6 099. |
| Största absolutavvikelse | 0,96 på skalan 0–255, ungefär 0,3765 procentenheter på skalan 0–100. |
| Samband mellan filerna | Alla PXF-kanaler är exakt heltalsdelen av motsvarande icke-negativa TXT-värde. Detta är trunkering, inte avrundning till närmaste heltal. |
| Unika RGB-tripplar | 2 027 i vardera filen; upprepade patchar ska bevaras. |
| PXF-platselement | Inga `Location`-element hittades. |
| Spektra | Inga; TXT har bara ID, namn och RGB. |

Exempel: patch 2 har R = 23 i PXF och R = 23,18 i TXT. Patch 5 har R = 92 respektive 92,73. Filernas ID-sekvens och kanalvisa trunkeringssamband stödjer att de beskriver samma ordnade patchuppsättning med olika numerisk precision.

Detta verifierar sambandet i just dessa filer. Det bevisar inte hur alla i1Profiler-exporter fungerar eller vilka av värdena som används internt när i1Profiler skriver ut.

## PXF-metadata ska inte övertolkas

Egna Prism-resurser innehåller bland annat `NumberPatchPages="2"`, men `NumberPatchColumns="0"` och `NumberPatchRows="0"`. Patchmåttens värdefält är också noll. Där finns även `ScramblePatches="False"` och diverse pappers- och profilinställningar. Tillsammans ger detta inte en fullständig fysisk patchkarta.

`MeasurementDevice="i1Pro 3"` och serienummer `0` förekommer. Detta är exporterad inställningsinformation, inte bevis för ett faktiskt använt eller kalibrerat instrument. Numeriska koder som `MeasurementMode="1"`, `SelectedMeasurementCondition="-1"` och `DimensionUnit="2"` bevaras utan gissad tolkning.

`BitDepth` är 16 under `ProfileSettings`, medan själva RGB-patchvärdena är heltal i intervallet 0–255. Denna profilinställning ger alltså inget belägg för högre precision i patchvärdena eller för att en TIFF har exporterats.

## Konsekvenser för första leveransen

1. Dessa filer räcker som verkliga referensfall för PXF-import och en i1Profiler-CGATS-variant.
2. TXT-varianten får inte behandlas som TI3 med RGB-procent. I detta fall används 0–255, trots att formatet är CGATS-baserat.
3. PXF och TXT ska importeras var för sig med sina faktiska värden. De får inte slås samman eller tyst göras lika.
4. För att behålla den högre tillgängliga numeriska upplösningen vid ny TIFF16-generering kan TXT väljas. Det ger inte ett löfte om exakt reproduktion av en tidigare i1Profiler-utskrift.
5. Utan TXF eller annan komplett layoutbeskrivning skapar vi en ny instrumentanpassad layout och matchande TI2. Ingen ursprunglig fysisk layout hävdas vara bevarad.
6. TIFF16 från PXF återställer inte de decimaler som saknas. Exakt återgivning av källvärden och exportens kvantisering kontrolleras separat.
7. Den genererade kartans senare i1Profiler-kompatibilitet återstår att verifiera; filerna löser patchimporten, inte hela layoututbytet.

## Föreslagna regressionsförväntningar

Importören ska få 2 033 patchar och bevara alla upprepningar. ID-mappning, filernas separata precision och ovanstående differensresultat ska kunna återskapas. Saknad full layout ska rapporteras. `BitDepth=16` får inte ändra tolkningen av RGB-kodningen.

Granskningen gjordes med separat XML- och tabelläsning samt decimalaritmetik. Den är ingen full XSD-validering eller test av en färdig InkProf-importör.
