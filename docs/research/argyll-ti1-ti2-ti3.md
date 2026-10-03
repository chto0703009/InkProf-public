# ArgyllCMS: filformaten .ti1, .ti2 och .ti3

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Datum: 2026-09-25

`.ti1`, `.ti2` och `.ti3` är dokumenterade ArgyllCMS-format. Den tredje filändelsen är `.ti3`, inte `.t3`. Filerna är läsbara textfiler baserade på CGATS, med Argyll-specifika fält och betydelser.

## Innehåll och roller

| Format | Innehåll | Skapas normalt av |
|---|---|---|
| `.ti1` | Patcharnas styrvärden, exempelvis RGB, och uppskattade CIE-färgvärden. Beskriver vad som ska provas. | `targen` |
| `.ti2` | Patcharnas styrvärden, placering i det färdiga targetet och uppskattade CIE-färgvärden för kontroll vid inläsning. Kopplar mätningen till rätt patch. | `printtarg` |
| `.ti3` | Styrvärden tillsammans med XYZ/Lab-värden och, när de sparats, spektra. Utgör mätunderlag för profilering i det vanliga utskriftsflödet. | `chartread` |

Färgvärdena i `.ti1` och `.ti2` är uppskattningar, inte uppmätta resultat från den aktuella utskriften. I det normala mätflödet sparas mätresultaten i `.ti3`. Formatet kan även skapas av konverterings- och simuleringsverktyg; filändelsen ensam bevisar därför inte att värdena är fysiskt uppmätta.

## Normalt arbetsflöde för en skrivare

```text
targen    → .ti1
printtarg → .ti2 + utskrivbart target
chartread → .ti3
colprof   → ICC-profil
```

`printtarg` läser `.ti1` och skapar layoutinformationen i `.ti2` tillsammans med ett utskrivbart target. Efter utskrift använder `chartread` `.ti2` för att organisera mätningen och sparar resultatet i `.ti3`. `colprof` använder därefter `.ti3` som underlag för ICC-profilen.

## Betydelse för InkProf

`.ti3` kan koppla varje patchs RGB-styrvärden till dess uppmätta spektrum. Det är det underlag som behövs för den föreslagna RGB-framåtmodellen.

Formatet definierar bland annat:

- `SAMPLE_ID`: patchens identitet.
- `RGB_R`, `RGB_G`, `RGB_B`: enhetens RGB-styrvärden.
- `COLOR_REP`: vilka färgrymder som kopplas samman.
- XYZ- eller Lab-kolumner för kolorimetriska värden.
- `SPECTRAL_BANDS`, `SPECTRAL_START_NM` och `SPECTRAL_END_NM` när spektraldata finns.
- `SPEC_XXX`: spektrala kolumner, där XXX anger våglängden avrundad till heltal i nanometer.

RGB-styrvärdena i `.ti3` anges i **0–100 procent**. Om InkProf använder 0–1 internt ska de divideras med 100. De ska inte tolkas som 8-bitarsvärden i intervallet 0–255.

Spektraldata är inte garanterade bara för att filen har ändelsen `.ti3`. InkProf behöver kontrollera vilka fält som faktiskt finns innan en spektral modell byggs.

InkProf kan använda dessa format utan att skapa egna ersättningar. Projektmetadata kan komplettera med utskriftsinställningar, mätvillkor, verktygsversioner och spårbarhet. Originalfilerna bör bevaras tillsammans med det target som faktiskt skrevs ut.

## Källor

- [ArgyllCMS: File formats](https://www.argyllcms.com/doc/File_Formats.html) – översikt över `.ti1`, `.ti2` och `.ti3`.
- [ArgyllCMS: TI3 file format](https://www.argyllcms.com/doc/ti3_format.html) – fält, metadata och värdeskalor för `.ti3`.
- [ArgyllCMS: Usage scenarios](https://www.argyllcms.com/doc/Scenarios.html) – arbetsflödet från target till mätning och profil.
