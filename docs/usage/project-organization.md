# Organisering av lokala projektdata

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

`projects/` är lokalt och ignoreras av Git. Kod och dokumentation hör hemma i `src/`, `bridge/`, `tests/`, `examples/` och `docs/`.

## Kategorier

| Mapp | Innehåll |
|---|---|
| `01-source-files/` | Ursprungliga patchdefinitioner och referensbilder. |
| `02-rgb-designs/` | Sparade RGB-nät och tillhörande TI1/JSON; äldre kombinerade paket hålls tillsammans med sin definition. |
| `03-print-targets/` | Utskriftspaket med TIFF, layout och matchande mätunderlag. |
| `04-measurements/` | Sparade mätomgångar och importerade mätningar, även ofullständiga försök. |
| `90-archive/` | Äldre nät- och layoutförsök, utan antagande om att de är godkända. |

Ett sammanhörande paket flyttas som en enhet. Källfil, design-JSON och ett äldre relativt refererat `*-files`-paket ska inte spridas i olika mappar. Sidantal och filnamn räcker inte för att avgöra vilket mätunderlag som matchar en fysisk utskrift.

## Genomförd lokal organisering 2026-09-26

79 poster organiserades. Samtliga 903 innehållsfiler kontrollerades med storlek och SHA-256 före/efter flytten. Inget mät- eller targetinnehåll raderades eller ändrades. Existerande absoluta sökvägar bevaras genom relativa symboliska länkar på de gamla platserna. Länkarna är dolda i Finder men kan visas med Cmd+Shift+punkt. De är inte extra kopior av innehållet.

`projects/README.md` är lokal innehållsförteckning och `projects/organization-map.json` anger tidigare och nuvarande plats. Flyttplan och hashverifiering finns i `work/cleanup-20260926/`. Nya filer som skapas senare ingår inte automatiskt i den daterade inventeringen.

Gamla metadata och TIFF-sidfötter behåller sina ursprungliga sökvägar. En ny utskrift ska genereras om sidfoten ska visa en ny sökväg; den gamla TIFF-filen får inte ändras tyst. Vid säkerhetskopiering behövs hela kategoriinnehållet. Om gamla kommandon ska fortsätta fungera behöver även kompatibilitetslänkar bevaras. Synkverktygs symlinkhantering är ett separat lokalt val.

FreeFileSync-jobb (`*.ffs_gui`, `*.ffs_batch`) och dess databas-/låsfiler ignoreras av Git. De är datorspecifika och tas inte bort vid kodstädning.

## Städning av huvudmappen 2026-10-03

Äldre lokalt utvecklingsmaterial har flyttats till ett daterat arkiv utanför kodrepot: provkörningarna i `work/`, en äldre guide-PDF i roten, testbilden `MatrixLarge.jpg` och referensfilen `CGATS Chart 575 Patches.txt`. Arkivet innehåller en filförteckning med SHA-256; innehållet verifierades efter flytten. Den aktuella guiden finns under `docs/usage/`.

Hänvisningar till `work/` i äldre forsknings- och provningsanteckningar avser historiska lokala arbetsfiler, inte filer som behövs för att köra appen. Arkivet distribueras inte med det publika repot. Mätprojekten i `projects/`, aktuell kod, testunderlag, lokala inställningar och Pythonmiljön berörs inte av denna städning.
