# C2 – oberoende verifieringsmål med applicerad ICC

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Första implementationen använder **absolut kolorimetri, D50/2° och ingen svartpunktskompensation**, enligt användarens val. Profilen appliceras en gång när patcharnas device-RGB beräknas. TIFF16 skrivs därefter utan ytterligare färghantering, utan tilldelad/inbäddad ICC och utan skalning.

```matlab
[folder, reference] = inkprof.createVerificationTarget(jobFolder, ...
    Name="Epson3880-Glossy-C2", ...
    ColourPatches=80, GrayPatches=24, ChallengePatches=12, Repeats=12, ...
    Seed=20260928, DPI=300, Paper="A4-landscape");
```

Utan jobbargument öppnas en mappväljare. Namn anges med `Name`, och `OutputFolder` kan ange en egen ny mapp. Annars skapas en unik mapp under projektets `verification`. Befintligt innehåll skrivs aldrig över. Appen erbjuder pappersförslag med ändringsbara projektmått för C2. A4 liggande är förval; befintlig utskriftsstandard med projektets ändringsbara måttgränser, kontrastmarkörer, bokstäver, radnummer, sidantal och fullständig sökväg används.

## Färger och oberoende

Önskade absoluta D50-Lab-färger väljs i PCS; de är inte kopior av de uppmätta träningsvärdena. Chromatiska kandidater samplas med lagrat frö, L* 18–90 och a*/b* −75–75. Neutrala gråprov har a*=b*=0. Utskrifts-RGB beräknas via `xicclu -fb -ia -pl`, kvantiseras till 16 bitar och används oförändrat vid layout/rendering.

Efter profilkonvertering utesluts RGB som ligger närmare någon träningspatch än `MinTrainingRGBDistance` i max-kanalnorm, förval 1/255 av normaliserat RGB. Olika unika prov får inte kollapsa till samma RGB16. Upprepningar duplicerar uttryckligen valda verifieringspatchar och behåller `repeatOf`. Det blir 116 unika prov och 12 upprepningar med förvalen. Slumpad utskriftsordning är spårbar i TI2 och JSON.

Urvalet är modellinformerat genom gamutgranskning: separat numerisk A2B-inversion används för att uppskatta om önskad färg kan nås. Residual ≤0,5 ΔE00 märks `model-reachable`. Övriga märks `outside-or-inversion-unresolved`, eftersom en ofullständig numerisk inversion inte bevisar att färgen ligger utanför gamut. Challenge-prov väljs bland residualer >3 ΔE00. Detta är urvalskriterier, inte acceptansgränser för profilen. Gråprov kan också ha gamutbegränsning och ska redovisas därefter.

Utdata-RGB och profilens förutsägelser bevaras separat från **referenceLabD50Absolute**, som är jämförelsereferensen för C3. Att senare använda verifieringsmätningar vid omträning gör dem inte längre oberoende; då behövs ett nytt slutkontrollmål.

## Sparat paket

- `definition/printer.icc`: exakt kopia av den testade profilen med SHA-256.
- `definition/source-Lab-D50.icc`: källkoordinaternas standard-Lab-representation; arkiverad proveniens. xicclu får PCS-Lab direkt. Den ska **inte** tilldelas TIFF-filen.
- `definition/verification.ti1`: redan profilkonverterade device-RGB och förväntade XYZ för layout/patchigenkänning. XYZ är modellprediktion, inte mätning.
- `print/target*.tif`, `print/target.ti2`, `print/layout.json`: verifierat befintligt utskriftspaket. Samma TI2 används vid mätning.
- `verification.json`: huvudreferens med önskad Lab, separata prediktioner, roller, upprepningar, RGB16, sida/koordinat, profilhashar, kolorimetri, utskriftsrecept och filkopplingar.
- `PRINTING.txt`: instruktioner som tydligt anger att ICC redan är applicerad.

Paketets pixelverifiering kontrollerar TIFF mot patchdefinitionerna; C2 kontrollerar dessutom att varje källpatch har exakt en placering med rätt RGB16. Kontrastmarkörer och padding ingår inte i verifieringens färgpoäng. Projektmanifestet uppdateras.

Om rendering misslyckas kan definitionen finnas sparad utan färdigt utskriftspaket. Endast huvudreferens med status `ready-to-print-not-measured` betecknar ett komplett C2-paket. Generera till en ny mapp efter rättning.

## Utskrift och nästa steg

Använd exakt samma fysiska skrivare, papper, media- och kvalitetsinställningar som vid profilens karakterisering. Receptuppgifterna följer med, men verkliga inställningar måste bekräftas av användaren; okända värden blir inte automatiskt verifierade. Ingen ny färgkonvertering får ske i applikation, operativsystem eller drivrutin.

Mät med matchande TI2 och samma dokumenterade mätvillkor. C3 ska beräkna Lab enligt samma D50/2°-konvention och jämföra med önskad absolut Lab. Skilj model-reachable, övriga färger, gråprov och upprepningar. Denna första leverans bygger målet; en färdig C3-poängsättning är inte implementerad här.

Acceptansgränser för ΔE00 och gråbalans står som **awaiting user acceptance** i JSON. Inga godtyckliga gränser används för att utse en vinnande profil. ISSUE-001 är fortsatt öppen och C2 gör ingen full mätbrusstudie.
