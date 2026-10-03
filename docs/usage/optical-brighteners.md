# Optiska vitmedel: OBA, FWA och OBC

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Uppdaterat 2026-10-02. InkProf erbjuder nu valbar D50-kompensation i projektdefinitionen. Direktmätningens instrumentläge ändras inte.

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

## Använd FWA/OBA i InkProf

Öppna **Project details → Project and materials** och välj **Compensate optical brighteners (D50)**. Valet är av som standard och kan ändras även efter mätning, profilering eller export. Det sparas centralt som `printing.fwaCompensation` i projektets JSON.

Efter en ändring markeras B1 och efterföljande steg som inaktuella. Använd samma bevarade profileringsmätning, kör B1/B2 och profileringen igen och gör nya kontroller och ett nytt godkännande. Originalmätningar, tidigare recept, ICC-filer och rapporter behålls; ändringen med före/efter-värden dokumenteras i workflow.json och resultatloggen. En redan exporterad ICC-fil ändras inte.

InkProf använder Argyll `-f D50` tillsammans med `-i D50 -o 1931_2`. Samma kompensation följer med till träningskontroll, adaptiv utvärdering och C3. Recept, kommandologgar och slutrapporter dokumenterar beräkningsvillkoren. Tidiga analyser av råmätningen förblir okompenserade och ändrar inte de sparade spektrala originalvärdena.

Den här implementationen kräver:

- Spektrala originaldata i känt M0-läge, med instrumentidentitet i TI3.
- Ingen UV-filtrering och ingen tidigare FWA-kompensation.
- Ett uppmätt pappersvitt (RGB 100/100/100) i respektive dataunderlag. Vid urval av träningspatchar måste det finnas kvar.

XYZ-only, okänt mätläge, M1, M2 och redan kompenserade mätningar stoppas för detta kompensationsval. M1-data kan fortfarande användas utan denna M0-kompensation. Den simulerade D50-responsen är **inte en fysisk eller certifierad M1-mätning**. Importerade data ometiketteras aldrig.

C2 lägger till en pappersvit referenspatch när FWA är på. Den används för kompensationsmodellen och utesluts från oberoende felstatistik och förbättringsprioritering. Ett äldre kontrollmål utan pappersvitt behöver ersättas med ett nytt mål och mätas igen. Anpassningsmätningar utan pappersvitt kan inte användas för FWA-utvärdering.

## English quick guide

Open **Project details → Project and materials → Compensate optical brighteners (D50)**. You may change this after profiling. Rebuild B1 and subsequent profiling/validation stages from the preserved measurement. Existing profiles and reports remain on disk; the JSON history records the change. Native M0 spectra, a known non-UV-filtered instrument and a measured paper-white patch are required. Compensation simulates D50; it does not certify an M1 measurement. The same FWA settings are used for profile building and evaluation.

## Vad Argyll kan göra

Argylls `colprof -f` aktiverar modellbaserad FWA-kompensation. Enligt dokumentationen behövs spektrala data och mätning utan UV-filter. Metoden uppskattar hur spektrala mätvärden skulle förändras vid en annan excitation av vitmedlen.

Argyll skiljer mellan kompensation för ett betraktningsljus och simulering av instrumentets mätbelysning. Dokumentationen beskriver bland annat kombinationen `-f -i D50` och simulering via `-f M1` eller `-f M2`. InkProf exponerar D50-kompensation; övriga simulerade ljus är inte valbara i appen. En simulerad M1/M2-respons får inte presenteras som direkt uppmätt M1/M2.

För ett verkligt betraktningsljus är dess spektralfördelning, inklusive UV, relevant. Samma färgtemperatur eller vitpunkt garanterar inte samma fluorescens. Argyll beskriver `illumread` som ett sätt att indirekt uppskatta UV-innehållet. Kompensation bör därför införas som ett separat, verifierbart recept, inte som en dold standardinställning.

## Rekommenderat fortsatt arbete

1. Använd konsekventa kompensationsvillkor inom en kandidatjämförelse. En ändring kräver ombyggnad och nya kontroller.
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

Argyll colprof/profcheck-kedjan med `-f D50` testades 2026-10-02 med ArgyllCMS 3.5.0 och syntetiska spektraldata. Det verifierar programflödet, inte fysisk utskriftsnoggrannhet.

## Senare val och rapportering (2026-10-02)

FWA behöver inte väljas när projektet skapas. Valet kan också göras i **B2 → FWA / OBA** eller i FWA-frågan när **Automatic** profilering startas. När valet sparas uppdateras projektdefinitionens `printing.fwaCompensation`. En ändring loggas i `workflow.json` och resultatloggen med tidigare och nytt val samt var valet gjordes. Avbryts valdialogen sparas inget nytt FWA-val.

Vid ett senare FWA-val behålls råmätningen och låst B1-underlag. Tidigare recept, profiler och efterföljande godkännanden blir inaktuella men deras filer finns kvar. Ett B2-recept som precis sparas med det nya valet blir aktuellt när steget slutförts. Automatisk profilering använder det nya valet för samtliga kandidater. Direkt ändring av övriga projektuppgifter följer projektets vanliga regler för ombyggnad.

Mätcertifikatet har avsnittet **FWA/OBA - val och resultat**. Det visar om kompensation faktiskt användes i den levererade profilen, sparat projektval, simulerad belysning samt ΔE00-medel, P95, maximum och antal patchar för träningsanpassning och kontrollutskrift. Uppgiften om faktisk användning kommer från profilens sparade beräkningsunderlag, inte enbart från kryssrutan. Äldre underlag utan dokumenterat FWA-läge anges som **Ej dokumenterat**. Olika FWA-lägen i profil- och kontrollunderlaget stoppar exporten.

Resultaten är profilens resultat med vald inställning. En förbättring eller försämring orsakad av FWA beräknas inte automatiskt genom att jämföra godtyckliga tidigare iterationer. Certifikatet anger att effekten jämfört med en motsvarande profil utan FWA är **Ej utvärderad** när en kontrollerad jämförelse inte redovisas. Det undviker att exempelvis nya mätningar eller ändrad profilutjämning felaktigt tillskrivs FWA.
