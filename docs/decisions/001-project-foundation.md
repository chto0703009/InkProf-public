# 001 - InkProfs grund

Datum: 2026-09-24. Uppdaterat: 2026-09-26. Status: beslutad inriktning; targetflöde implementerat, mätprototyp simuleringsprovad, fysisk verifiering återstår.

## Beslut och inriktning

1. Paketnamnet är **InkProf**. Webbsökningen hittade ingen tydlig ICC-programvara med namnet men en turkisk företagskatalogpost med namnet İnkprof inom trycklösningar. Domän- och varumärkestillgänglighet är inte verifierad.
2. InkProf är ett självständigt MATLAB-paket utan körberoende till SpectraLab eller Camera-41. Se [beslut 007](007-independent-inkprof.md).
3. **MATLAB Base** är plattformskrav. Extra toolboxar får inte bli obligatoriska genom indirekta beroenden.
4. **ArgyllCMS är referensmotor**, särskilt `targen`, `printtarg`, `chartread` och `colprof`.
5. Första leveransen är targetimport/-generering, TIFF16 och mätunderlag. Därefter följer mätning, analys och ICC-generering enligt projektplan v0.6.
6. Canon PRO-2600 behandlas som RGB-enhet i det valda drivrutinsflödet. Antalet patroner avgör inte antalet åtkomliga profilkanaler.
7. Modellens fel mot träningsmätningar och ΔE00 för en separat profilerad utskrift är olika resultat och ska märkas tydligt.
8. Patchantal, patchfördelning och profilbyggare ska jämföras med oberoende kontrollmaterial och registrerad utskriftsvariation.
9. ChromIQ-betans profilbyggare blir en valfri jämförelsemotor. Bättre resultat är en hypotes som ska prövas.
10. Yule–Nielsen/Neugebauer ingår i en senare etapp för undersökning av utskriftsrymden. RGB-flödet kräver först en empirisk spektral modell; fysisk separation av bläck kan inte antas.
11. Interna beräkningar använder `double`. Målet är 16-bitars LUT-värden och 16-bitars RGB-TIFF; faktisk profilprecision och utskriftsväg kontrolleras.
12. Mirage anger `High Quality (600x600 dpi, 12-bit)` för PRO-2600 i [Christers dokumenterade skärmbild](../research/canon-pro-2600-mirage-12-bit.md). Detta är verifierat som en uppgift i gränssnittet för det valda läget; intern kvantisering och bläckdosering är fortsatt okända. Utskriftsreceptet ska registrera hela kvalitetsläget och övriga inställningar. Målet om 16-bitars export och ICC-tabellvärden kvarstår.

## Kvar att fastställa

Exakt kompatibilitetsmatris, instrument och mätläge, första papper och utskriftsrecept, utvecklingstakt samt toleranser för jämförelseförsöken. Dessa frågor hindrar inte att importer och datakontrakt utvecklas med kontrollerade provfiler.

Licensen är fastställd till GPL-3.0-or-later enligt [beslut 003](003-shared-gpl-license.md).
