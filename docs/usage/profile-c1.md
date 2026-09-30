# C1 – kompletterande numerisk profilkontroll

`inkprof.checkProfileC1` kompletterar `checkProfileFit` och `checkProfileGrid` med flyttalsjämförelse mot LittleCMS, lokala inversprov och avsiktligt skadade testkopior.

```matlab
[report, reportFile] = inkprof.checkProfileC1(jobFolder);
```

Utan argument väljs jobbets mapp i en dialog. `ShowDialog=false` sparar rapporten utan resultatfönster. JSON och Markdown sparas i jobbets `checks` och projektmanifestet uppdateras. Den godkända profilfilen ändras aldrig. Resultat innebär inte automatiskt godkänd utskriftskvalitet.

## Flyttalsjämförelse

729 RGB-punkter, relativ kolorimetri och ingen svartpunktskompensation. LittleCMS offentliga C-API anropas med dubbelprecisionsbuffertar (`TYPE_RGB_DBL`, `TYPE_Lab_DBL`), RGB 0–1 och vanlig Lab. Ingen 8-bitarsomvandling görs. Optimering och pixelcache stängs av för att jämföra tabellutvärderingen. Interna beräkningar och ICC-tabeller har fortfarande ändlig precision; xicclu skriver sex decimaler.

Samma RGB respektive Lab skickas till båda motorerna. Vi rapporterar framåt-ΔE00, inversens RGB-skillnad samt färgskillnaden mellan inverslösningarna via samma Argyll-A2B. Det sista är en modelljämförelse, inte en oberoende utskriftsmätning.

Biblioteket söks via Pillow och därefter systemets LittleCMS. `INKPROF_LCMS2_LIBRARY` kan ange en explicit bibliotekssökväg med samma arkitektur som Python. API och version kontrolleras; saknat bibliotek ger ett tydligt fel och kontrollen hoppas inte över. Bibliotekssökväg/version sparas. Inga nya binärer distribueras. Licenser finns i `THIRD_PARTY_NOTICES.md`.

## Inversens lokala beteende

Vid varje nätpunkt störs en Lab-koordinat i taget med ±0,1, ±0,01 och ±0,001. Skillnaden mellan inversens RGB-värden redovisas för varje skala. När steget minskar bör ett lokalt ändligt lutande förlopp ge mindre utdataförändring. Detta är diagnostik, ingen global kontinuitetsgaranti. Störda PCS-värden kan ligga utanför gamut och klippas.

Dessutom följs 27 RGB-ramper med 1 025 punkter genom A2B→B2A. Rapporten visar RGB-steg, andra differenser och färgsteget efter A2B. En stor gradient eller ett LUT-knä är inte i sig en diskontinuitet. Provningen visar inte hur mätbrus påverkar en nyanpassad profil; det hör till ISSUE-001.

## Avsiktligt felaktiga profiler

Tillfälliga testkopior får:

1. trunkerat innehåll,
2. fel ICC-signatur,
3. fel färgrymd,
4. nollställd B2A1-CLUT men fortsatt giltig yttre struktur.

De tre första ska stoppas före beräkning. Den fjärde ska ge numeriskt grovfel. Gränsen 10 ΔE00 används endast som grovfelindikator i detta test, aldrig som acceptansgräns för utskriftskvalitet. Den numeriska mutationen stöder för närvarande mft2; andra LUT-typer rapporteras som en ej genomförd negativ kontroll. Det ska inte tolkas som att en godtycklig ICC är felaktig.

## Status

Implementerad och provad 2026-09-27 med den tätare B2A-kandidaten. Se [C1-resultatet](../research/c1-verification-20260927.md). C1:s definierade numeriska kontroller är genomförda för denna kandidat; andra profiler och renderingsavsikter behöver egna kontroller. Oberoende utskriftsvalidering hör till C2. ISSUE-001 hålls öppen enligt användarens beslut.

API-referens: [LittleCMS lcms2.h](https://github.com/mm2/Little-CMS/blob/master/include/lcms2.h).
