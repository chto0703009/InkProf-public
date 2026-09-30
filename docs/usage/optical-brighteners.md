# Optiska vitmedel: OBA, FWA och OBC

Dokumenterat 2026-09-29. Detta beskriver nuvarande funktion och ett föreslaget separat undersökningssteg. Ingen kompensation eller nytt mätläge har aktiverats.

## Begrepp och fysisk betydelse

- **OBA (Optical Brightening Agents)** och **FWA (Fluorescent Whitening Agents)** är benämningar på optiska vitmedel i papper. De absorberar UV och avger synligt ljus, främst i det blå området.
- **OBC (Optical Brightener Compensation)** är X-Rites benämning på kompensationen, inte själva ämnet.

Papperets och utskriftens färg kan därför bero på belysningens UV-innehåll. En vanlig spektral reflektanskurva uppmätt under ett mätljus räcker inte för att exakt förutsäga fluorescensen under alla andra ljus. Skillnader mellan mätljus och betraktningsljus kan inte lösas enbart genom fler RGB-patchar, bättre interpolation eller en annan ICC-färgmotor.

## Mätvillkor

| Villkor | Innebörd för denna diskussion |
|---|---|
| M0 | Traditionellt mätvillkor. Fluorescensens excitation behöver inte motsvara D50-betraktning. |
| M1 | Avsett att motsvara D50-belysning, inklusive relevant UV-excitation. |
| M2 | UV filtreras bort och vitmedlens excitation reduceras. |

X-Rites i1Pro 2 stöder M0/M1/M2 i ett kompatibelt X-Rite-arbetsflöde. Det innebär inte automatiskt att Argylls instrumentdrivrutin eller InkProfs nuvarande mätrutin exponerar samtliga lägen. Se [chartread och mätvillkor](chart-measurement.md).

M1 är ett mätvillkor, inte en synonym för OBC. Att välja D50 vid integrering av ett M0-spektrum gör inte mätningen till en fysisk M1-mätning.

## InkProf i nuvarande implementation

- Direktmätningen med i1Pro 2 använder M0 eller ospecificerat instrumentstandardläge. M1/M2 är inte tillgängliga direkta val i detta flöde.
- Spektral profilering beräknar XYZ/Lab för D50 och CIE 1931 2-gradersobservatören.
- Profileringsreceptet och C2-underlaget anger `fwaCompensation=false`.
- Ingen särskild fluorescenskompensation utförs i det aktuella profilerings- och verifieringsflödet. Mätdata innehåller fortfarande den fluorescens som instrumentets faktiska belysning framkallade.
- Begärt, rapporterat och tolkat mätvillkor samt proveniens ska bevaras. Importerade data får inte ometiketteras från M0 till M1 på grund av en efterföljande D50-beräkning.

Kodunderlag: `src/+inkprof/measureChart.m`, `src/+inkprof/createProfileRecipe.m` och `analysis/verification_target.py`.

## Vad Argyll kan göra

Argylls `colprof -f` aktiverar modellbaserad FWA-kompensation. Enligt dokumentationen behövs spektrala data och mätning utan UV-filter. Metoden uppskattar hur spektrala mätvärden skulle förändras vid en annan excitation av vitmedlen.

Argyll skiljer mellan kompensation för ett betraktningsljus och simulering av instrumentets mätbelysning. Dokumentationen beskriver bland annat kombinationen `-f -i D50` och simulering via `-f M1` eller `-f M2`. Detta är dokumenterade Argyll-möjligheter, inte aktiverade InkProf-inställningar. En simulerad M1/M2-respons får inte presenteras som direkt uppmätt M1/M2.

För ett verkligt betraktningsljus är dess spektralfördelning, inklusive UV, relevant. Samma färgtemperatur eller vitpunkt garanterar inte samma fluorescens. Argyll beskriver `illumread` som ett sätt att indirekt uppskatta UV-innehållet. Kompensation bör därför införas som ett separat, verifierbart recept, inte som en dold standardinställning.

## Rekommenderat fortsatt arbete

1. Behåll den pågående kandidatjämförelsen konsekvent i M0, utan FWA-kompensation. Ändra inte detta mellan kandidaterna.
2. Undersök **otryckt pappersvitt** och några ljusa gråpatchar med M1 och M2 i ett arbetsflöde som faktiskt stöder villkoren. Samma papper, underlag, instrument, geometri och torkförhållanden ska användas. Skillnaderna ger diagnostisk information om vitmedlens betydelse, inte en universell korrigeringsfaktor.
3. Dokumentera avsett betraktningsljus. Ett påstått D50-ljus behöver även bedömas med avseende på spektralfördelning och UV.
4. Skapa vid behov ett separat profilrecept för kompensation. Bevara råspektra, ursprungligt mätvillkor, instrumentuppgifter, kompensationsmetod, parametrar och motorversion tillsammans med den härledda informationen.
5. Verifiera profilering och C2/C3 under konsekventa villkor. Blanda inte kompenserad profilprediktion med okompenserade referensvärden utan uttrycklig metod och redovisning. Undvik dubbel kompensation av redan bearbetade importerade data.

Vi har ännu inte visat att optiska vitmedel orsakar de aktuella lokala felen i InkProf. Detta är en möjlig separat felkälla att undersöka, inte en fastställd förklaring till M5, U22 eller andra avvikelser. En bra anpassning till M0-data garanterar inte samma visuella överensstämmelse under annat UV-innehåll.

## Källor

- [X-Rite: Optical Brightener Compensation](https://www.xrite.com/-/media/xrite/files/literature/l7/l7-400_l7-499/l7-439_x-rite_i1_family_optical_brightener_compensation/l7-439_obc_en.pdf)
- [X-Rite: i1Pro 2 User Guide](https://www.xrite.com/-/media/xrite/files/manuals_and_userguides/e/eo2-qsg_i1pro_2_user_guide_en.pdf)
- [ArgyllCMS: colprof, FWA och belysning](https://www.argyllcms.com/doc/colprof.html)
- [ArgyllCMS: Fluorescent Whitener Additive Compensation](https://www.argyllcms.com/doc/FWA.html)

Källorna granskades 2026-09-29. Webbdokumentationens funktioner måste kontrolleras mot installerad Argyll-version innan de införs i kod.
