# C1 – verifiering 2026-09-27

Status: **Tekniskt genomförd för den aktuella kandidaten; klar för användarens acceptans.**

Kandidat: Epson 3880 / Glossy / 575 korrigerade mätpatchar, A2B medium och B2A high. Jobb `63dfb8f4-034b-488e-82b0-341511343016`, SHA256 `90ac68bb407ceacc1b59edb0e838e76d0d54dcf1218d49ff8ee57d4cb8cc1258`. Alla kontroller nedan avser relativ kolorimetri utan BPC.

## Tidigare kontroller

- Träningsanpassning, 575 patchar: medel/max ΔE00 **0,4865 / 2,3387**.
- RGB-roundtrip, 729 punkter: medel/max ΔE00 **0,4809 / 2,4055**.
- Inga RGB utanför kuben. Framåtgråramp utan L*-reversaler; inga kandidater över den tidigare definierade andra-differensgränsen.

## Återstående C1-prov, nu genomförda

| Kontroll | Resultat |
|---|---|
| Argyll–LittleCMS framåt, flyttalsindata | medel ΔE00 0,001324; max 0,005197 |
| Invers, RGB-skillnad | medel 0,002908; max 0,023940 procentenheter |
| Färgskillnad mellan inverslösningarna via samma A2B | medel ΔE00 0,001284; max 0,007035 |
| 27 inversramper × 1 025 prov | max RGB-steg 0,8585 procentenheter; max färgsteg 0,2252 ΔE00 |
| Trunkerad ICC, fel signatur, fel färgrymd | samtliga avvisades |
| Giltig struktur men förstörd B2A1-tabell | upptäcktes numeriskt; max roundtrip 94,59 ΔE00 |

LittleCMS 2.19 kördes via offentligt C-API med dubbelprecisionsbuffertar och utan omvägen över 8-bitarsbilder. Intern precision begränsas fortfarande av motor och ICC-tabell. Jämförelsen avser just denna utvärderingsväg; andra optimeringsval och rendering intents har inte kvalificerats.

Den tidigare stora skillnaden i 8-bitarsjämförelsen återkommer inte i denna flyttalskontroll. Vi kan därför inte använda 8-bitarsresultatet som belägg för motsvarande fel i en högprecisionskedja.

### Lokalt beteende

Störningen görs i en Lab-koordinat åt gången. Maximal RGB-kanalskillnad mellan ändpunkterna blev:

| Halvt Lab-steg | Totalt Lab-steg | Max RGB-skillnad, procentenheter |
|---:|---:|---:|
| 0,1 | 0,2 | 3,0254 |
| 0,01 | 0,02 | 0,3005 |
| 0,001 | 0,002 | 0,0304 |

Utdataförändringen krymper ungefär proportionellt mot steget. Det stöder ändlig lokal lutning vid de provade punkterna och ger inget belägg för ett kvarstående språng där. Det bevisar inte global jämnhet och bekräftar inte att mätbrus orsakat fel.

## Slutsats och avgränsning

De avtalade återstående numeriska C1-kontrollerna är genomförda. Motorerna överensstämmer väl i flyttalsprovet och diagnostiken upptäcker de avsiktliga felen. Inga nya grovfel framkom i kandidaten. Kvarvarande roundtripfel dokumenteras, inte döps om till nollfel.

C1 ska accepteras som en numerisk kontroll av denna kandidat, inte som godkännande av utskriftskvaliteten. C2 ska verifiera faktiska utskrifter. **ISSUE-001 ligger kvar öppen** tills vi har bättre underlag för att koppla verkliga avvikelser till konditionstal och mätbrus. Den är inte ett krav på att genomföra brusstudien nu.

## Spårbarhet

- `c1-verification-20260927.json` innehåller resultat och värsta fall.
- Rutinen `inkprof.checkProfileC1(jobFolder)` sparar nya rapporter under jobbets `checks` och uppdaterar manifestet.
- Sju nya Python-tester täcker flyttalsformat, indatavalidering, saknat bibliotek, fel profilklass och grovfelindikatorer. Negativa kontroller på en faktisk ICC ingår också i körningen.
