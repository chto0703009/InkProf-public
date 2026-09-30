# Organisering av lokala projektdata

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
