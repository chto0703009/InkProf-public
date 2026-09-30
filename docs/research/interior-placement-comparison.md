# InkProf: placering av nya inre RGB-punkter

Jämförelse 2026-09-26. Samma budget: 499 anpassningspunkter, 64 kontroller och 12 upprepningar. InkProf börjar med 153 punkter och lägger till 346. Alla InkProf-varianter behåller 98 ytpunkter och har 401 inre anpassningspunkter. Argyll har 190 ytpunkter och 309 inre.

## Oberoende kontroll med 100 000 slumpmässiga provpunkter

Samma provpunkter används för alla metoder; MATLAB twister med frö 20260926. Provpunkterna används inte vid genereringen. Avstånd gäller normaliserat RGB till närmaste anpassningspunkt, inte ΔE. Kontroller och upprepningar ingår inte som anpassningsstöd. Lägre är bättre.

| Metod | Medel | 95-percentil | Största påträffade avstånd |
|---|---:|---:|---:|
| Argyll OFPS | 0.06695 | 0.09564 | 0.12648 |
| InkProf: tyngdpunkter (förval) | 0.06648 | 0.09910 | 0.13312 |
| InkProf: omsfärscentrum inom egen tetraeder | 0.06615 | 0.10535 | 0.13812 |
| InkProf: alla omsfärscentrum inne i kuben | 0.06723 | 0.10305 | 0.13360 |

## Bedömning

Att använda omsfärscentrum endast där de ligger i sin egen tetraeder ger ungefär 0,5 procent lägre medelavstånd än tyngdpunktsmetoden på det oberoende provet. Däremot blir 95-percentilen cirka 6,3 procent högre och största påträffade avståndet cirka 3,8 procent högre. Argyll behåller bättre täckning enligt dessa två svansmått. Den nya placeringen är därför ett jämförelsealternativ, inte en entydig förbättring. Tyngdpunkter behålls som förval.

Det regelbundna 33³-nätet gav större förbättring av medelvärdet än det oberoende slumpmässiga provet. Detta visar att ett enda regelbundet provnät inte bör avgöra metodvalet. Båda undersökningarna finns i JSON-filen. Inget undersökt maximum är ett bevisat maximum över den kontinuerliga kuben.

## Implementation

InteriorPlacement="centroid" är förval. "contained-circumcenter" lägger till omsfärscentrum inom respektive tetraeder som kandidater, med tyngdpunkter som reserv. "circumcenter" tillåter omsfärscentrum var som helst strikt inne i kuben, även utanför sin definierande tetraeder. Alla kandidater rangordnas efter avståndet till närmaste befintliga anpassningspunkt. Startpunkter flyttas inte och inga nya ytpunkter läggs till.

Omsfärscentrum är lika långt från tetraederns fyra hörn. För Delaunay-tetraedrar ger det en tom sfär, men en girig följd av sådana val behöver inte ge bäst fördelning vid ett bestämt slutligt punktantal.

Algoritmversion 2.1 sparar InteriorPlacement, insertionKinds, candidateKinds och parentTetrahedra. Vid omsfärscentrum avser de fyra föräldrarna sfärens definierande hörn; de måste inte omge punkten i den obegränsade varianten.

Det gjordes också ett separat försök med diskret längst-bort-placering med 65 nivåer per axel, där ytterytan undantogs (63³ inre kandidater). Det gav inte bättre inre medeltäckning än tyngdpunkter och lades inte till som användaralternativ.
