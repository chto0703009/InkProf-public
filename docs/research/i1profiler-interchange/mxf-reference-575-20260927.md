# Ny M0-referens från i1Profiler, 2026-09-27

Aktuell status: se [acceptans 2026-09-27](acceptance-20260927.md).
Daterade uppgifter om väntande importprov nedan beskriver tidigare felsökning.

Källa i projektet: `projects/Canon-575-20260927/exports/InkProf-575-from-TI2-v2_i1profile.mxf`.
SHA-256: `f8686e81cd3aa6a9a200d76d50e15e93a46c274cc650f4f6610f956cfcb9ca27`.
Originalfilen har inte ändrats.

## Verifierat genom filanalys

- 575 Target-objekt och 575 M0_Measurement-objekt; inga M1/M2-objekt.
- Alla target-RGB och deras listordning matchar exakt InkProfs genererade
  `InkProf-575-from-TI2-v2.pxf`. Därmed finns ett konkret mottagarflöde från
  vår PXF till en sparad mätfil, inte bara intern XML-återläsning.
- 575 unika positionsnycklar `(Page, Column, Row)` i respektive grupp;
  positionsmängderna matchar entydigt. `SampleID=-1` och tomt SampleName kan
  inte användas som unika identiteter i denna fil.
- Varje spektrum har 36 ändliga värden. Specifikationen anger start 380 nm,
  steg 10 nm, XRGA, Filter_None och M0_Incandescent; slutet är 730 nm.
- Reflektansfaktorintervallet är 0,002413–1,049892. Värden över 1 har inte
  klippts eller normaliserats bort.
- Layout: en sida, 29 kolumner och 20 rader. Första 20 patcharna ligger i
  kolumn 0, rader 0–19. Det är kolumnvis fyllning, till skillnad från den
  separata InkProf-utskriftens två sidor med 21 patchar per rad.

## Skillnader mot den avvisade MXF-v2-exporten

Referensen anger MeasurementMode=1 i användarens Single Scan/M0-flöde;
den tidigare exporten ärvde MeasurementMode=2 från en M0/M1/M2-referens.
Den nya referensen har heltals-RGB, SampleID=-1, tomt SampleName, privata
ProfileSettings och originalets layout/skrivarattribut. Den tidigare
exporten ändrade flera sådana fält samtidigt och skrev fraktionella RGB.
Skillnaderna är kandidater för isolerade importprov, inte bevisade orsaker
till meddelandet `Error reading CxF version information`.

Nästa steg är återimport av den nya, oförändrade i1Profiler-filen som
positiv kontroll. Därefter bör en separat exportkandidat ändra enbart
spektral nyttolast med verifierad targetkoppling, före fler metadataändringar.
En referenslayout får inte beskrivas som InkProf-originalets fysiska layout;
båda positionssystemen måste då dokumenteras i JSON.

Inspektionsresultatet finns i projektets
`exports/i1profiler-reference-inspection.json`. De nya fysiska mätvärdena
har inte slagits ihop med eller ersatt InkProfs tidigare mätningar.
