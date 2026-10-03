# B2 – profileringsrecept

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

**MXF-import:** kompletta mätvärden betyder inte att utskriftsuppgifterna är fullständiga. Kontrollera skrivare, pappersprodukt, drivrutinsinställningar, färghantering och mätvillkor; behåll obekräftade uppgifter som unknown. Se [varning och regler för komplettering](measurement-file-import.md#varning-mxf-kan-behöva-kompletterande-uppgifter).

B2-flödet är användargodkänt 2026-09-27. Separat B2A-kvalitet tillagd samma dag.

```matlab
[recipeFile, recipe] = inkprof.createProfileRecipe(folder);
```

`folder` är mappen som B1 returnerade. Utan argument öppnas ett filval för `profile-input.json`. Ingen senaste revision väljs automatiskt.

Dialogen visar namn, beskrivning, skrivare, pappersprodukt, Glossy/Matte/unknown, drivrutinens medieinställning, utskriftskvalitet, drivrutin/version, utskriftsprogram/-väg och färghantering vid utskrift. Projektets aktuella gemensamma uppgifter fylls i och ändras i Project details. Låst B1 och tidigare mätdata ändras inte retroaktivt. Tomma utskriftsuppgifter blir unknown.

Beräkningsvalen är:

- **Spectra (D50 / 2 degrees)**: Argyll-integration vid profilbygget med `-i D50 -o 1931_2`, med valbar `-f D50` från projektdefinitionen. Detta är förvalet och kräver spektra.
- **Stored XYZ**: lagrade XYZ bevaras. Byggsteget måste skapa en separat indatafil utan spektral-/Lab-kolumner och spektralmetadata för att förhindra att motorn väljer annan kolorimetri. B2 påstår inte att lagrad XYZ har verifierad D50/2°-proveniens.

M0/M1/M2 beskriver mätvillkor, inte belysningen för spektralintegrationen. Utskriftskvalitet hålls skild från profilberäkningens kvalitet, med A2B medium och Lab cLUT. Dialogens **Inverse table (B2A)** väljer **High (denser)** eller **Medium (baseline)**. High är förval för nya recept; `B2AQuality="medium"` väljer jämförelsealternativet. Detta ändrar inte mätdata eller framåtmodellens kvalitetsval. Profilversion väljs inte i detta steg; den ska läsas från motorns faktiska resultat. Glossy/Matte är en deklarerad pappersyta, inte ett pappersnamn. Unknown kvarstår i receptet även om motorn har egna standardattribut.

**Save recipe** sparar en ny UUID-mapp under B1:s `recipes`, stänger fönstret och uppdaterar projektmanifestet. **Cancel** eller kryssknappen sparar inget. Ingen ICC genereras av B2. Receptet innehåller relativ länk till B1, SHA-256, mätvillkor, utskriftsdeklarationer, beräkningsval och planerade motorargument. B1-filerna kontrolleras före dialog och före sparning. B3 måste åter verifiera dessa hashvärden och verkställa vald indataförberedelse innan motorn startar.

Skriptanvändning:

```matlab
[recipeFile, recipe] = inkprof.createProfileRecipe(folder, ...
    Name="Epson 3880 Glossy", Description="Epson 3880 - 575 measured patches", ...
    DataMode="spectral", B2AQuality="high", ShowDialog=false);
```

Aktuell projektdefinition används före B1:s äldre uppgiftssnapshot. Uttryckligen angivna `Printing`-fält i skript kan ersätta motsvarande receptfält. Sparade recept återläses med `jsondecode(fileread(recipeFile))`; redigering/öppna befintligt recept i GUI är ännu inte implementerad.

## Verifiering

Integrationstest täcker sparning/återläsning, B1-koppling och avvisning av spectral när data saknas. GUI-tester täcker Save och Cancel. B1-kontroller skyddar mot ändrat låst underlag.

Installerad colprof 3.5.0 provades separat med rättade 575-data och explicit spektralintegration. När en testkopia fick halverade lagrade XYZ men oförändrade spektra blev A2B/B2A-tabellernas byte identiska. Det bekräftar spektralvägens dataval i detta prov. Experimentet använde låg kvalitet och är ingen accepterad användarprofil. Resultatet finns i `docs/research/colprof-b2-spectral-probe.json`, tillfälliga filer i `work/b2-probe`.

Argyll beskriver `-i`/`-o` för spektralintegration och `-f` för FWA. Se [officiell colprof-dokumentation](https://www.argyllcms.com/doc/colprof.html). Lagrade XYZ-vägens filförberedelse och fullständiga profilbyggen verifieras i B3/B4.

B2A-valet sparas som `engine.b2aQuality` och explicit `-bh`/`-bm` i motorargumenten. Äldre recept utan fältet körs med sina ursprungliga argument och ändras inte automatiskt. Ett nytt recept och jobb krävs för tätare B2A. Tätare tabell minskar approximationsfel men garanterar inte en entydig invers eller fysisk utskriftskvalitet.

FWA/OBA kan väljas direkt i receptdialogen. När ett ändrat val sparas uppdateras även projektdefinitionen och beroende resultat blir inaktuella. Råmätningen och låst B1 bevaras. Se [FWA/OBA och senare val](optical-brighteners.md).

## v1.0.0 project settings

Project details also records dye/pigment ink type, printer coating and coating settings. Matte paper can activate configurable extra dark patch sampling and shadow table emphasis. Read [matte shadow profiling](matte-shadow-profiling.md), [the current workflow](workflow-v1.0.md) and [gamut surface](gamut-surface.md). Certificates distinguish the saved build recipe from requested future patch counts.
