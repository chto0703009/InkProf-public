# Fortsätta från uppmätt kompletteringsmål till ny ICC och C2

`inkprof.continueRefinement` kopplar ihop `refineVerification` och `iterateProfile`. Den används **efter** att det nya kompletteringsmålet skrivits ut utan färgkonvertering och mätts. Den behöver förslagsmappen och den nya mätfilen, inte manuell inställning av BaseInputFolder och RoleFile.

```matlab
[iterationFolder, result] = inkprof.continueRefinement();
```

Först väljs förslagsmappen som innehåller `proposal.json`, därefter den nya mätningen (JSON, TI3 eller MXF). För en redan öppen arbetsgång:

```matlab
[iterationFolder, result] = inkprof.continueRefinement(folder, measurementFile, ...
    Name="Epson 3880 Glossy - iteration 3", ...
    MaxNewPatches=100, NormTarget=1, GrayWeight=2);
```

Ange en **mätfil**, inte TI2 eller C3-rapport. `MaxNewPatches` avser ett eventuellt kommande förtätningsförslag som den nya profiliterationen skapar; det ändrar inte det redan utskrivna målet.

## Automatisk koppling och kontroller

- Föräldraprofilen och träningsunderlaget kopplas via källkopior och SHA-256. Det låsta kompletta träningspaketet hittas genom inputhash; en lös kopia av metadata i profileringsjobbet räcker inte.
- Den frysta rollplanen kontrolleras mot förslagets RGB-punkter. Nya rollplaner/TI2 får dessutom hashvärden när utskriftsmålet skapas. Äldre förslag valideras semantiskt mot kandidaterna och föräldraprofilens träningspunkter.
- Mätningen måste vara komplett och stämma i ID, RGB, position och mätvillkor. Dess TI3-hash måste stämma. B1 och den befintliga kombinationsrutinen gör ytterligare kontroller inför profilering, inklusive schemas och spektral kompatibilitet.
- Enbart `fit` läggs till tidigare träning. `adaptive_holdout` används för kandidatjämförelse. Upprepade kontrollpatchar och slutliga holdout-patchar blir inte träning.
- Den befintliga profiliterationen skapar och jämför ICC-kandidater, utför numeriska kontroller och skapar ett nytt C2 med profilen applicerad en gång. Eventuellt kompletteringsmål är separat och utan applicerad profil.

För det befintliga förslaget `80903390-9ee5-43dc-8348-1302d1825ac1` blir det 911 gamla + 80 nya träningspatchar = **991**. Av de 100 nya RGB-proven är 20 reserverade för utvecklingskontroll. Därutöver finns 20 tryckta kontrollpatchar. Totalt mäts 120, men inte alla läggs till träningen.

## Förhandskontroll, spårbarhet och avbrott

```matlab
[checkFolder, check] = inkprof.continueRefinement(folder, measurementFile, ...
    PrepareOnly=true);
```

Det kontrollerar kopplingen och sparar en plan utan att starta profileringen. Full körning använder samma anrop utan PrepareOnly. Varje anrop skapar en ny `continuations/<UUID>` med `continuation.json` och `progress.log`. Den nya profiliterationen sparar en egen fryst kopia `continuation-source.json` och loggar föräldrakopplingen. Misslyckanden loggas och befintliga profiler ersätts inte.

Ingen mätning uppfinns om den saknas. Identitetskontroller bevisar inte att papper, torkning och skrivarinställningar varit jämförbara. Automatisk driftbedömning mellan trycktillfällen ingår ännu inte; de upprepade kontrollerna bevaras för granskning. Kandidatvalets befintliga regressionsgränser är oförändrade och kan anges som MaxPatchRegression, MaxGrayRegression och MinImprovement.

Utvecklingsmätningar får inte senare kallas oberoende slutverifiering. Den nya C2-utskriften och dess mätning är nästa fysiska kontroll, och något automatiskt ISO- eller kvalitetsgodkännande görs inte.
