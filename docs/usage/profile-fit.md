# Profilkontroll – anpassningsfel per patch

Implementerad 2026-09-27. Detta är första delen av C1, inte hela dess framåt-/inversvalidering. B3 är användargodkänd; den genererade ICC-kandidaten kan nu kontrolleras numeriskt mot träningsunderlaget.

```matlab
[report, reportFile] = inkprof.checkProfileFit(jobFolder);
```

Välj vid behov jobbmapp med `inkprof.checkProfileFit()` utan argument. Fönstret visar patcharna sorterade efter fallande ΔE00, koordinat, sample-ID, RGB, beräknat Lab och referens-Lab. Dropdown väljer alla patchar eller lika RGB (grå), mörka, högkromatiska respektive RGB-kubens rand. Grupperna överlappar; definitionerna sparas i rapporten. Lika RGB innebär inte att uppmätt Lab är neutralt.

Kontrollen använder jobbets verkliga `engine.ti3` och ICC-resultat, med hashkontroll mot jobbstatus. `profcheck -v2 -k -I a` ger absolut kolorimetrisk jämförelse. Spektralrecept använder dessutom `-i D50 -o 1931_2` utan FWA. XYZ-recept använder den redan förberedda filen utan spektraldata. Referens-Lab följer därför vald beräkningsväg; den ersätts inte tyst med InkProfs egna spektralintegrationsvärden.

Varje utskriven rad verifieras mot förväntat sample-ID, mätposition och RGB i TI3. Saknade, dubbla eller obekanta patchar avvisas. Colour räknar oberoende om CIEDE2000 från loggens Lab-värden, med tolerans för deras sex decimaler. En ändrad/okänd loggsyntax avvisas, inte gissas.

Resultat sparas under jobbets `checks/<UUID>` som `profile-fit.json`, `profile-fit.md` (samtliga patchar) och `profcheck.log`. Manifestet uppdateras. JSON innehåller proveniens, verktygsversion, argument, hashvärden, gruppdefinitioner, statistik och individuella värden. Skriptläge: `ShowDialog=false`.

**Tolkning:** detta är träningsfel, inte oberoende utskriftsvalidering, inte en konvergenskurva och inte bevis för en optimal lösning. Inversen, separat RGB-nät, jämna övergångar, oberoende CMM-jämförelse och nya kontrollutskrifter återstår i C1–C3. Profilen eller mätdata ändras inte av kontrollen. Patcher med stora avvikelser tas inte bort automatiskt.

[Argyll profcheck](https://www.argyllcms.com/doc/profcheck.html) beskriver `-k` som CIEDE2000, `-v2` som patchvis utskrift och `-I a` som absolut kolorimetrisk jämförelse.

Verifiering: sex parser-/identitetstester samt körning genom MATLAB och resultatfönstret på den aktuella 575-profilen. Alla patchar måste vara med för att rapporten ska publiceras.
