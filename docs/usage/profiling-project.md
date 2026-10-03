# Sammanhållet profileringsprojekt

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Ett profileringsarbete bor i en gemensam mapp med `inkprof-project.json`. JSON-filer för definition, layout, mätning och analys behåller sina egna roller; projektmanifestet sammanställer dem och lagrar historik.

```matlab
paths=setupInkProf();
project=inkprof.createProject(fullfile(paths.Projects,'mitt-profileringsprojekt'), ...
    Name="Printer / paper / print mode");
```

## Mappar och arbetsflöde

- `sources/`: importerade definitioner och annat ursprungsunderlag.
- `targets/`: sparade definitioner och fullständiga TIFF/TI2/layout-paket.
- `measurements/`: mätomgångar och omläsningar.
- `analyses/`: valfri plats för härledda analyser; de kan också sparas bredvid mätningen.
- `reports/`: PDF och kontrollresultat; rapporter kan också ligga bredvid mätningen.
- `profiles/`: framtida profiler och valideringsunderlag.

Spara definitioner under projektet och öppna dem med `inkprof.renderTarget`. Renderdialogen föreslår projektets targets-mapp när indata tillhör projektet. `inkprof.measureChart` skapar mätomgångar i projektets measurements-mapp när vald TI2 ligger inom projektet. Analysens standardplats är bredvid mätfilen. Ange PDF-plats inom projektet.

## Automatisk uppdatering

MATLAB-API:erna registrerar framgångsrik sparning av RGB-definition, TIFF16-paket, chart-förberedelse, mätinställningar, mätresultat, spektralanalys och PDF/kontrollrapport. Äldre fristående mappar fortsätter fungera utan att omvandlas automatiskt. Om ett manifest inte går att uppdatera efter sparning visas en varning; sparade mätdata förstörs inte. Kör då `inkprof.updateProject(project)`.

Filer som kopieras manuellt eller skapas genom direkta Python-/Argyll-CLI-anrop registreras med samma uppdateringsfunktion efteråt. Ingen bakgrundsbevakning av filsystemet är installerad. Profilgenerering och leverans registreras i projektets manifest och arbetsgång när operationerna slutförs.

```matlab
inkprof.updateProject(project,Step="external-files-imported");
```

Manifestet innehåller projekt-ID, revisionsnummer, relativa sökvägar, dokumenttyper, storlekar och SHA256 för filerna. Varje steg anger ändrade och borttagna sökvägar. Tidigare manifest sparas i `.manifest-history/`, som inte räknas in rekursivt i filinventeringen. Ett lås hindrar samtidiga skrivningar; uppdateringen publiceras via en temporär fil.

Kända beroendehashar mellan chart, TI3, mätning och analys matchas mot projektets filer i `links`. Omatchade hashreferenser redovisas i `unresolvedLinkCount`; det är inte automatiskt bevis för att projektet saknar körindata (en referens kan exempelvis avse ett äldre ursprung). Manifesthistorik är inte backup av äldre filinnehåll. Radera inte rådata.

## Fysisk utskrift

TIFF/layout beskriver vad som förbereddes. Uppgifter om verklig skrivare, papper, drivrutin, utskriftsläge och färghantering registreras uttryckligen och står annars som okända. Uppdatera hela printing-posten:

```matlab
printing=struct('status',"user-recorded",'printer',"...",'paper',"...", ...
    'driver',"...",'quality',"...",'colorManagement',"...",'notes',"...");
inkprof.updateProject(project,Step="physical-print-recorded",Printing=printing);
```

## Flytt och befintligt arbete

Den aktuella 575-patchkedjan är kopierad till `projects/Canon-575-20260927`. Originalmapparna har bevarats. Alla kopierade filer verifierades med SHA256. Historiska absoluta sökvägar i rådata har inte skrivits om, eftersom det skulle ändra kontrollsummor. `relocations` kopplar deras gamla rotmappar till relativa sökvägar inom projektet; PDF-rutinen använder denna koppling för layouten. Nya mätningar ska startas från den kopierade TI2-filen i projektets targets-mapp.

Ta med hela projektmappen vid överföring till en annan dator. `inkprof.updateProject` kan därefter uppdatera inventeringen utan att vara beroende av den gamla projektrotens sökväg.

## v1.0.0 project settings

Project details also records dye/pigment ink type, printer coating and coating settings. Matte paper can activate configurable extra dark patch sampling and shadow table emphasis. Read [matte shadow profiling](matte-shadow-profiling.md), [the current workflow](workflow-v1.0.md) and [gamut surface](gamut-surface.md). Certificates distinguish the saved build recipe from requested future patch counts.
