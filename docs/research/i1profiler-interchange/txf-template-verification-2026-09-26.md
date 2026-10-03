# TXF-verifiering med licensdongel, 2026-09-26

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Kontroll i i1Profiler 3.8.5 med synlig PUBLISH & DEVICE LINK-licens. Fyra TXF-kandidater från aktuell `createTiff16` provades, baserade på 2033 RGB-patchar, slumpfrö 42 och 287 utfyllnadsfält. Varje kandidat innehåller 580 positioner på en sida.

## Resultat och korrigering

Importen behåller i1Pro 2, 263 × 195 mm, 29 kolumner × 20 rader och 8 × 8 mm patchar. Första bildkontrollen visade att mottagaren placerar objekt kolumnvis, medan exportören tidigare skrev dem radvis. `writeTxfCandidate` har därför rättats: endast TXF-objektordningen ändras, medan TIFF/TI2 och den fysiska JSON-kartan behåller sin ordning. Koordinatnamnen följer rätt patch även efter omordningen. Regressionstestet kontrollerar både RGB och namn efter återimport.

Samtliga fyra rättade TXF-filer öppnades och sparades som TIFF genom mottagarens användargränssnitt. Alla 2320 patchars inre färgfält stämmer exakt mot InkProfs JSON och TIFF-underlag, inklusive utfyllnad. Mottagarens TIFF är RGB8 vid cirka 101,6 dpi och används endast som kontrollbild, inte som ersättning för InkProfs TIFF16. Alla provvärden är exakt RGB8-representerbara.

## Kvarvarande geometrisk avvikelse

Mottagarens färgfält börjar vid x=15,5 mm, medan InkProf-mallen börjar vid x=14,75 mm. Avvikelsen är +0,75 mm horisontellt. Y-positionen 24,5 mm och patchstorleken 8 × 8 mm stämmer. Efter denna konstanta x-förskjutning jämfördes hela patchrektanglarna: 2320 av 2320 stämde exakt, maximal RGB8-avvikelse 0.

Absolut sidplacering är alltså inte identisk. Ingen fysisk radmätning har utförts och filerna markeras fortsatt som kandidater. Ingen generell kompatibilitetsflagga har satts till godkänd. Äldre kandidater skapade före ordningsrättningen måste genereras om; utskriftsbilderna ändras inte av rättningen.

Varje TXF är en separat sida. Mottagaren visar därför Page 1 of 1 och lokala radnummer även för InkProfs sida 2–4. Använd rätt sidfil och bevara JSON-kartan vid senare sammanfogning av mätresultat. Den granskade vägen är `createTiff16`-sidmallen; den äldre `exportTxfTarget`-vägen för Argyll-layouter med separatorer har inte kvalificerats här.

## Evidens

Maskinläsbar rapport och filhashar: `txf-template-verification-2026-09-26.json`. Lokala prov och återexporter: `work/txf-verification-20260926/` (ignorerad arbetskatalog). Sista sidans TXF återexporterades även som XML; samtliga 580 RGB-objekt behöll värden och ordning.
