# MXF: i1Profiler Measurements

Aktuell status: se [acceptans 2026-09-27](acceptance-20260927.md).
Daterade uppgifter om väntande importprov nedan beskriver tidigare felsökning.

Datum: 2026-09-25. Status: preliminärt läs-/skrivkontrakt för InkProf.

Tre [verkliga MXF-referensfall](mxf-examples-inspection.md) är nu granskade: CMYK med enbart Lab samt två RGB-filer med spektra för M0/M1/M2. De ger konkreta positionsnycklar via `TagCollection Name="Location"`; XML-objekt-ID och `SampleID` kan inte ensamma antas koppla mätning till target.

## Källbelagd roll

`.mxf` betecknar här i1Profilers mätformat, inte videoformatet med samma ändelse. X-Rite listar det som Measurements. [S5] I CxF3-varianten kopplas targetets enhetsvärden till mätresultat. [S4] Se [gemensamma regler och källor](README.md).

## Föreslagen betydelse i InkProf

MXF är huvudkandidaten för att importera ett komplett profileringsunderlag från i1Profiler. Fullständigheten ska dock kontrolleras i varje fil: spektra, mätvillkor, layout och instrumentmetadata får inte antas finnas bara utifrån filändelsen.

## Konkret läskarta från granskad ChromIQ-kod

```text
Resources / ObjectCollection / Object
  targetobjekt: DeviceColorValues / ColorRGB / R, G, B
  mätobjekt:   ColorValues / ReflectanceSpectrum
```

Den granskade konverteraren söker objektgrupper med beteckningar som `Target` och `M0_Measurement`, `M1_Measurement` eller `M2_Measurement`. Dessa beteckningar och kopplingen efter listordning är observationer av en stödd variant, inte universella CxF-regler.

## Importkrav

- Fastställ entydig koppling mellan target och mätning. Använd explicita referenser där de finns. Ordning kräver ett verifierat ordningskontrakt; lika antal objekt är inte tillräckligt bevis.
- Behåll samtliga mätvillkor och upprepningar. Välj inte tyst den första gruppen.
- Läs våglängdsinformation från spektrum och tillhörande specifikation. Anta inte alltid 380 nm start eller 10 nm intervall.
- Bevara både spektra och befintlig kolorimetri. Dokumentera om XYZ/Lab senare räknas om och med vilka villkor.
- Bevara okänd metadata utan att kalla den verifierad. Rätta inte misstänkta skalor genom gissning.

## Exportkrav

InkProf måste ha matchade styrvärden och mätningar för det valda targetet. Vald i1Profiler-version, XML-variant, färgspecifikationer och eventuella privata resurser ska vara verifierade med en referensfil och ett importprov.

Om endast Lab/XYZ finns får spektra inte konstrueras som om de vore uppmätta. Om spektra finns bör de ingå i den stödda exportvarianten; eventuell reducering till kolorimetri ska tydligt rapporteras. Omsampling och avrundning ska redovisas numeriskt.

## Utbyte med TI3 och ChromIQ

MXF → TI3 ska behålla styrvärden, mätkopplingar och tillgängliga spektra. Om flera mätvillkor måste delas i flera TI3-filer ska ett manifest koppla filerna till originalet.

Den lokalt granskade ChromIQ-funktionen `cxf_measurement_to_ti3` skriver bara RGB och härledd XYZ, inte spektrala kolumner. Dess resultat är därför otillräckligt för en spektral återexport till MXF. Läs original-MXF i InkProf eller använd en annan verifierad konverteringsväg. Se kodrevision och detaljer i [översikten](README.md#kodobservationer-i-lokal-chromiq).

## Verifieringsfall

Prova flera mätvillkor, upprepade patchar, olika våglängdsintervall och en avsiktligt omordnad mätlista. Felaktig koppling ska upptäckas. Jämför spektra och metadata efter en full läs-/skrivcykel, inte bara beräknad ΔE.

## Praktisk granskning av i1Profiler 3.8.5

Se [verifieringsrapporten](ui-verification-3.8.5.md) för observerade menyval, utförd MXF-import, spektral CGATS-export och TIFF-export. Rapporten skiljer utförda prov från återstående format- och layoutverifiering.

## Första spektrala exportkandidaten (2026-09-27)

`exchange/export_mxf.py` skapar en M0-kandidat från en komplett kanonisk
mät-JSON och en verklig Prism/CxF3-referensfil med samma targetordning.
RGB jämförs position för position före export; lika färger används inte som
unik nyckel. Target och mätobjekt får samma Page/Column/Row från chart.json.
Utfyllnadsrutor utelämnas. M1/M2 från referensen tas bort, spektra divideras
med 100 utan omsampling, och de ursprungliga XYZ-värdena följer med i JSON-
rapporten. Filens färgimetri beräknas av mottagaren från spektra.

Detta är en begränsad adapter för den observerade 380–730 nm/10 nm,
XRGA, RGB, M0-varianten. Privata Prism-attribut kommer delvis från referensen
och är kompatibilitetshjälp, inte verifierad information om papper/utskrift.
Privata profilinställningar tas bort. Återläsning kontrollerar alla RGB-värden,
positionskopplingar och spektra. Import i mottagarprogrammet återstår.

Första filen använder den kompletta 575-mätningen från 09:58. Separata
kontrollmätningar av rad 19 och raderna 1–3 har inte automatiskt slagits in.

### Importfel och serialisering v2

Första kandidaten avvisades av mottagaren med `Error reading CxF version
information` (användarens skärmbild 2026-09-27 11:34). ElementTree hade ändrat
XML-deklarationen och namnrymdsserialiseringen, och exportören hade tagit bort
PrismAppName/PrismAppVersion. V2 bevarar referensens yttre XML, versionstaggar
och privata prefix, medan Creator fortfarande anger InkProf. Versionstaggarna
är kompatibilitetsmarkörer för dialekten, inte ett påstående att filen skapats
av i1Profiler. Samtliga RGB och spektra är identiska med första kandidaten.
Vilken enskild skillnad som utlöste felet är inte isolerad. V2 kräver nytt
importprov; XML-korrekthet ensam är inte mottagarverifiering.

## RGB och senare val av papperstyp (2026-09-27)

InkProf arbetar med RGB-target. RGB är därför fast färgformat i detta flöde,
inte ett användarval mellan RGB och CMYK. CMYK-indata ska avvisas med ett
begripligt fel om fel färgformat.

Valet **Glossy/Matte** under Paper Information kan införas i ett senare steg.
Det behöver inte avgöras för den nuvarande formatverifieringen. Vid import
ska ett befintligt pappersval bevaras i intern JSON och kunna följa med vid
export. Saknad uppgift ska lämnas okänd tills användaren anger den; en
referensfils standardvärde får inte beskrivas som verifierat utskriftspapper.
Ett senare användarval ska hållas åtskilt från det importerade originalvärdet
så att ursprung och ändring kan följas.

Den fungerande referensfilen och den avvisade MXF-v2-exporten anger båda
`ColorSpace="RGB"` och `Paper="Glossy"`. Dessa två fält förklarar därför inte
skillnaden i importresultat. Hur Glossy/Matte påverkar mottagarens
profilberäkning är ännu inte verifierat. Valet ska inte tolkas som M0/M1/M2
eller användas för att ändra redan uppmätta spektra.

## Implementerad mätimport (2026-09-27)

`inkprof.importMeasurement()` tar TI3 eller MXF och öppnar samma färgkarta
som interna mätningar. Den spektrala MXF-adaptern använder explicita
positionsnycklar, bevarar original och metadata samt skapar en normaliserad
TI3 och mät-JSON. En accepterad punktommätning ger en ny TI3/JSON-revision;
original-MXF ändras inte. Se [användning och begränsningar](../../usage/measurement-file-import.md).

## 2026-09-29: iteration 2, 911 patches and integer RGB compatibility

The merged 575 + 336 fitting-patch MXF was rejected by i1Profiler 3.8.5 with
“Error reading CxF version information”. This message did not identify the
actual numerical serialization issue. Restoring only Creator, FileInformation,
and ProfileSettings did not fix the decimal-RGB variant. With the known-good
reference envelope unchanged, replacing decimal ColorRGB values by integers
0–255 made the file load. The final file was opened in the Measurement step:
`InkProf-911-iteration2-M0-compatible-RGB8.mxf` (XRGA, M0, Glossy).
This verifies import, not subsequent profile generation or colour accuracy.

`exchange/repair_mxf_compatibility.py` implements this limited compatibility
route. It requires matching spectral specifications and unambiguous locations,
retains the reference metadata envelope, pairs spectra and RGB by location, and
writes a sidecar mapping original Target names to exported names. The
`--allow-rgb8-rounding` flag is required for material rounding; existing outputs
are never overwritten. Tests cover explicit rounding consent, mapping, spectral
preservation and overwrite refusal.

All 911 × 36 spectral samples were preserved. The maximum channel rounding was
0.4980665 on 0–255 (0.1953202 percentage points). Thus this is **not an exact-RGB
comparison** against the full-precision InkProf fit. JSON and TI3 remain the
full-precision source. In sensitive regions even small RGB rounding can matter.
The 84 frozen holdouts and 80 control occurrences are not included in the 911
fitting export. The later 15 ramp points are also not included.

Creator, dates, private profile settings and printer/paper fields retained from
the reference are compatibility metadata, not proof of source provenance or a
prescription for the recipient's profiling recipe. See the export JSON for
actual sources and per-patch rounding. The virtual layout is for transfer and
profile construction, not physical remeasurement. Do not infer that all CxF or
CGATS routes have this same RGB8 limitation.
