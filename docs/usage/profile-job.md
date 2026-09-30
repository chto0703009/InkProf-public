# B3 – separat profileringsjobb

Implementerad 2026-09-27; användaracceptans återstår. B2 är användargodkänd.

```matlab
[jobFolder, status] = inkprof.runProfileJob(recipeFile);
```

`recipeFile` är JSON-filen från B2. Utan argument öppnas filval för receptet. Detta startar **colprof** och kan skapa en ICC-kandidat; B3 omfattar teknisk jobbkörning, inte utskriftsvalidering eller automatiskt godkännande av profilen.

Fönstret visar status, jobbmapp och senaste loggutskriften. **Cancel job** eller kryssknappen begär avbrytning av just den egna körningen. MATLAB väntar på avslutad körning men GUI:t behandlar händelser. Ctrl+C begär också avbrytning genom städningen. Om MATLAB tvångsavslutas kan automatisk städning inte garanteras.

## Jobbets innehåll

Varje körning får en unik mapp under projektets `profiles/jobs`:

- `recipe.json`, `profile-input.json`, `source.ti3`: ögonblicksbilder av valt recept och profileringsdata.
- `engine.ti3`: exakt indata till motorn. Spectral behåller spektra; storedXYZ tar bort spektral- och Lab-kolumner samt spektralmetadata, med kontroll att RGB/XYZ och patchidentiteter är oförändrade.
- `request.json`: filhashar, sökväg till motorn, tidsgräns och förberedelsemetod.
- `version.txt`, `colprof.log`, `worker.log`: version, motorlogg och eventuella fel från Python-jobbet.
- `status.json`: atomiskt uppdaterad status, verkliga argument, verktygshash, exitkod, resultat eller fel.
- `work`: isolerad arbetsmapp; felaktiga eller avbrutna kandidatfiler kan finnas här för felsökning.
- `result/profile.icc` och `result/inspection.json`: publiceras bara efter exitkod 0, A1-kontroll utan varningar, rätt profilklass/färgrymd, förväntade A2B0/B2A0-taggar och oförändrade indata.

Slutstatus är `succeeded`, `failed` eller `cancelled`. `succeeded` betyder tekniskt skapad och strukturellt kontrollerad kandidat, inte godkänd färgkvalitet. Normal avslutning uppdaterar projektmanifestet. Tidigare profiler och låsta mätningar skrivs aldrig över.

Python äger colprof-processen och hanterar avbrytning; MATLAB visar status och skickar en cancel-fil. Argument skickas som separata processargument, utan shell. Jobbet accepterar bara implementerade receptinställningar och jämför rekonstruerade argument med B2:s planerade argument.

Standardtidsgränsen är 1800 sekunder för motorbygget, versionsfrågan högst 15 sekunder. Motorns sökväg hämtas från InkProfs Argyll-konfiguration; `ColprofExecutable` kan anges uttryckligen. `ShowDialog=false` används för skripttester. Inget instrument används.

## Tester

Python-prover med en falsk motor täcker lyckad körning, exitkod 7, manipulerad indata och avbrytning. MATLAB-integration testar storedXYZ-förberedelse och verktygsfel. En separat temporär kopia av det godkända spektrala 575-receptet används för prov mot installerad colprof; den väljer inte en produktionsprofil åt användaren.

Begränsningar: kontroll av LUT-kvalitet, fysisk utskrift och oberoende färgvalidering hör till senare steg. Okända utskriftsinställningar i receptet blir inte kända genom att jobbet lyckas. Ingen systeminstallation av profilen sker.

Provresultat 2026-09-27: den temporära körningen med 575 spektrala patchar, D50/1931_2, medium/Lab cLUT och colprof 3.5.0 avslutades med `succeeded`. A1 identifierade resultatet som ICC 2.2.0. Testprojektet togs bort efter kontroll; detta är teknisk verifiering av körvägen, inte en accepterad produktionsprofil. MATLAB:s Cancel-knapp ingår också i integrationstestet med en väntande falsk motor.
