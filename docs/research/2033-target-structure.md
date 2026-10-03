# Struktur i Chart 2033 Patches.txt

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Undersökt 2026-09-28. RGB-värdena i denna fil är på skalan 0–255.

De första 1872 patcharna bildar ett komplett kartesiskt nät med 12 R-nivåer, 13 G-nivåer och 12 B-nivåer. R/B-steget är ungefär 23,18/255 = 9,09 procentenheter och G-steget 21,25/255 = 8,33 procentenheter. Detta är generell förtätning utan att känna skrivarens individuella fel.

Totalt finns 2033 patchar men 2027 unika RGB-värden. Av de 161 ytterligare raderna upprepar sex nätpunkter och 155 ligger utanför grundnätet. Hela filen innehåller 43 exakt neutrala RGB-rader. 41 av de unika tilläggspunkterna är neutrala och kompletterar svart/vitt till en tätare gråramp. Syftet med resterande tillägg kan inte fastställas enbart från filen; ingen proprietär algoritm härleds.

För våra lokala centrum är närmaste RGB-avstånd 5,154 procentenheter kring O6 och 2,235 kring U5. Inom ±3 procentenheter per kanal finns noll respektive en punkt. Ingen punkt finns i det smala R-intervallet 48,038–49,804 procent med G/B inom ±10 procentenheter från rampens G=85,490 och B=42,745.

2033-målet täcker därför generellt tätare än 575, men fångar inte säkert den observerade smala övergången. Felstyrd förtätning kan placera ett litet antal prov där informationen faktiskt saknas. Det är inte visat här vilken profilkvalitet 2033-målet skulle ge efter utskrift och mätning.

## Förkunskap före mätning

Användarens fråga gäller konstruktörens erfarenhetsbaserade prioritering före någon mätning, inte enbart efterhandskontroll mot vårt felområde. Filen visar regelbunden grundtäckning och särskild gråprovtagning. Den visar inte varför axlarna fått 12/13/12 nivåer; detta kan inte tillskrivas grönkänslighet utan ytterligare källa. Återstående tillägg behöver kartläggas innan de kallas hudtoner, mörkerprov eller gamutprov. För InkProf bör sådana generella startprioriteringar hållas åtskilda från mätbaserad adaptiv förtätning och deras ursprung anges.

## InkProfs föreslagna startfördelning

Se [Startmål för nytt papper – 2033 patchar](../planning/new-paper-2033-target.md)
för ett separat försöksförslag grundat på iteration 2. Det beskriver inte
fördelningen i den importerade fil som analyseras ovan och är ännu inte
implementerat som standardläge.
