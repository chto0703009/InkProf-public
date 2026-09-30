# Canon PRO-2600: 12-bitarsläge i Mirage

Dokumenterat 2026-09-25. Källa: skärmbild tillhandahållen av Christer i planeringssamtalet. Datumet avser dokumentationen, inte en verifierad tidpunkt för skärmbildens skapande.

## Direkt observerat

- Program: Mirage Print; versionsraden visar Mirage Pro 2026.5.2 (Trial).
- Skrivare: `Canon PRO-2600 (LUCIA PRO II Ink)`.
- Papper: `Grafisk Handel Pro Luster 260 g`.
- Kvalitetsfältets exakta text: **`High Quality (600x600 dpi, 12-bit)`**.
- `Finest Details` är markerat; Chroma Optimizer-fältet visar `CO All`.

![Mirage visar 12-bitarsläge för Canon PRO-2600](assets/2026-09-25-mirage-pro-2600-12-bit.png)

## Tolkning och avgränsning

Skärmbilden bekräftar att Mirage anger 12 bitar för det valda utskriftsläget. Uppgiften avser inte beteckningen ”12 Color” eller antalet patroner. Den ersätter tidigare generell osäkerhet om huruvida Mirage alls anger ett sådant läge.

Skärmbilden fastställer inte var i utskriftskedjan kvantisering sker, vilket dataformat som överförs, eller hur skrivarens interna bläckdosering fungerar. Den bevisar inte 4 096 fysiskt särskiljbara nivåer per patron och ska inte generaliseras till alla kvalitetslägen eller program. 600x600 dpi återges som lägets beteckning, inte som ett påstående om skrivarhuvudets maximala upplösning.

## Konsekvenser för InkProf

- Behåll `double` i beräkningar och målet 16-bitars TIFF samt 16-bitars ICC-tabellvärden. Profilprecision och utskriftslägets bitdjup är olika egenskaper.
- Registrera program/version, skrivare, medieinställning, kvalitetslägets fullständiga text, angivet bitdjup, Finest Details och Chroma Optimizer i utskriftsreceptet.
- Använd samma utskriftsrecept vid targetutskrift och senare profilerad utskrift. Registrera också färghanteringsinställningar; de framgår inte av denna bild.
- Ange bevisnivån som ”observerat i Mirage-gränssnittet”, inte ”verifierat internt skrivarbitdjup”.

## Spårbarhet

Originalbilden bevaras utan bildändringar i `assets/2026-09-25-mirage-pro-2600-12-bit.png`.

SHA-256: `491cca056f233c16c5fe550553f0989adedcfe2d69f64126598712fc227b5ca5`
