# TXF: i1Profiler Test Charts

Datum: 2026-09-25. Status: preliminärt läs-/skrivkontrakt för InkProf.

Ett verkligt [TXF-referensfall med 2 033 patchar](chart-2033-txf-inspection.md) har nu inspekterats. Där dokumenteras konkreta XML-sökvägar och layoutattribut; rendering och mätning är ännu inte verifierade.

## Källbelagd roll

`.txf` används för i1Profilers testtarget. [S5] Filen innehåller enhetsvärden och kan beskriva patchplacering via CxF3:s platsinformation och egna resurser. PXF och TXF kan ligga nära varandra strukturellt; skillnaden är inte enbart filändelsen. [S4] Se [gemensamma regler och källor](README.md).

## Föreslagen betydelse i InkProf

En TXF behandlas som en targetdefinition med möjlig fysisk layout. Dokumentera separat vilka delar som faktiskt lästs: styrvärden, logisk ordning, sida/rad/kolumn, storlek och instrumentrelaterade parametrar. Saknad layout betyder inte att patcharna får antas ligga i radordning.

## Importkrav

- Läs och validera styrvärden enligt [PXF-kontraktet](pxf.md).
- Spara både originalordning och fysisk position när båda finns. En permutation mellan dem ska vara explicit.
- Bevara platsdata och egna XML-resurser. Exakta sökvägar och enheter ska fastställas från schema och referensfiler; detta dokument anger inga påhittade privata taggar.
- Kontrollera att patchar inte oavsiktligt placeras på samma position och att sid-/rad-/kolumnindex tolkas enligt producentens konvention.
- Matcha layouten mot det utskrivna targetet innan den används för mätning.

## Exportkrav

En targetexport för mätning behöver en verklig layout som mottagaren kan använda. Om i1Profiler genererar om layouten efter import ska det nya targetet skrivas ut. Dess beskrivning får inte användas för att mäta ett tidigare utskrivet ark med annan placering.

För en redan utskriven karta ska exporten bevara patchordning och geometri tillräckligt för rätt identifiering vid mätning. Om detta inte kan styrkas ska InkProf erbjuda export av patchuppsättning för ny layout, inte kalla resultatet en ekvivalent TXF.

## Utbyte med Argyll

TXF motsvarar funktionellt TI2, men en TI2 kan kräva layout- och instrumentinformation som inte har en direkt eller känd TXF-motsvarighet. Konvertering kräver en särskilt verifierad adapter. Att byta ändelse eller kopiera endast RGB-listan räcker inte.

Förlustrapporten ska skilja mellan bevarade färgvärden, ändrad fysisk layout och bortfall av instrumentinställningar. Targetbilden eller utskriftsfilen ska arkiveras tillsammans med layoutbeskrivningen.

## Verifieringsfall

Prova flera sidor, en ofullständig sista rad, randomiserade patchar samt en layout med asymmetriska kontrollfärger i hörnen. Jämför producerad karta med originalet och kontrollera läsriktningen. Vilka privata resurser mottagaren kräver är en öppen versionsfråga.

## Praktisk granskning av i1Profiler 3.8.5

Se [verifieringsrapporten](ui-verification-3.8.5.md) för observerade menyval, utförd MXF-import, spektral CGATS-export och TIFF-export. Rapporten skiljer utförda prov från återstående format- och layoutverifiering.
