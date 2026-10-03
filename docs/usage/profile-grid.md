# C1 – RGB-nät, invers, gråramp och CMM-jämförelse

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

```matlab
[gridReport, gridFile] = inkprof.checkProfileGrid(jobFolder);
```

Standardnätet är 9×9×9 = 729 RGB-punkter. `GridLevels` kan anges mellan 3 och 25. Fönstret visar statistik, lika-RGB-gråramp och RGB-kanalerna från neutral Lab genom inversen. `ShowDialog=false` stöds. Resultat sparas i jobbets `checks/<UUID>` som JSON och Markdown; manifestet uppdateras.

Beräkningen använder `xicclu -ir -pl` utan svartpunktskompensation. Framåt går genom A2B och bakåt genom den lagrade B2A-tabellen (`-fb`), inte genom numerisk inversion av A2B (`-fif`). RGB → Lab → RGB → Lab kontrolleras med ΔE00 och RGB-fel i procentenheter. Antal RGB-värden utanför kuben redovisas utan att först klippa dem. Icke-ändliga värden och felaktigt antal verktygsresultat avvisas.

Övergångar undersöks med 27 linjer (tre axlar, övriga kanaler i 0/0,5/1), vardera 257 prov. Andra differensens Lab76-norm redovisas; värden över 1 Lab-enhet är diagnostiska kandidater, inte en generell acceptansgräns. Grårampen har 257 lika RGB-värden. Minskning i L* större än 0,001 räknas. En separat neutral Lab-ramp undersöker inversen från profilens svarta L* till 100; neutralpunkterna är inte garanterat inom gamut.

Pillow/LittleCMS jämförs framåt och bakåt med Argyll vid samma kvantiserade indata, relativ kolorimetri, BPC av. RGB/Lab-gränssnittet är 8-bitars. NumPy-representationen av Pillow LAB har signerade, byteomslagna a/b-kanaler; detta hanteras uttryckligen och testas mot Pillow-pixlar. Resultatet är en begränsad CMM-kontroll, inte flyttalsprecision eller bred kompatibilitetscertifiering.

Ett syntetiskt nät är separat från mätpunkterna men är inte en oberoende uppmätt kontroll. Stor RGB-roundtripavvikelse kan bero på icke-entydighet, gamutbegränsning eller approximation i inversen; den får inte förklaras som ofarlig utan vidare granskning. Avstånd mellan grannpunkter är en gradient, inte automatiskt en diskontinuitet. Ändligt antal prov kan inte bevisa jämnhet överallt. Lika RGB är inte heller ett krav på neutralt Lab för en okorrigerad skrivare.

Sju automatiska tester täcker verktygsutdata, fel, icke-ändliga värden, nätstorlek och Lab-kodning. Den aktuella 575-profilen har körts genom MATLAB-fönstret. Ett första internt prov hade fel Lab-kodning i CMM-jämförelsen; den rapporten är markerad `invalid-cmm-comparison` och ska inte användas. Korrigerade rapporter genereras med aktuell kod.

[Argyll xicclu](https://www.argyllcms.com/doc/xicclu.html) dokumenterar skillnaden mellan bakåttabell och inverterad framåttabell samt relativ/absolut kolorimetri. Profilkvalitet vid verklig utskrift behöver fortsatt verifieras med nya mätningar.
