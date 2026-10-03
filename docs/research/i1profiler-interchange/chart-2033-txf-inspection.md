# Referensfall: Chart 2033 Patches.txf

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Granskat 2026-09-25. Kompletterar [granskningen av PXF och TXT](chart-2033-inspection.md).

## Original och metod

Christer tillhandahöll `/Users/christer/Downloads/Chart 2033 Patches.txf`. En oförändrad kopia finns i `tests/fixtures/i1profiler/chart-2033/` tillsammans med PXF och TXT. Exakt i1Profiler-version är ännu inte angiven.

Filen har lästs som XML och jämförts med PXF på objektnivå. Detta är filinspektion, inte XSD-validering, återimport i i1Profiler eller praktisk mätverifiering.

## Patchinnehåll

- CxF3-namnrymd: `http://colorexchangeformat.com/CxF3-core`.
- Producent: `X-Rite - Prism`.
- Angivet skapandedatum: `2026-09-25T14:36:04+01:00`, bevarat som skrivet i filen.
- **2 033 targetobjekt**.
- ID, namn, objekttyp, RGB-värden och objektordning är **exakt samma som i PXF-filen**.
- RGB-värdena är alltså heltal på skalan 0–255 och har samma tidigare konstaterade trunkeringssamband till TXT-filen.
- Inga `Location`-element och inga `ReflectanceSpectrum`-element hittades.

TXF kompletterar därmed targetet med layoutparametrar men tillför inte högre precision i färgvärdena eller några mätningar.

## Konkreta lässökvägar i detta referensfall

```text
Namnrymder:
  cc  = http://colorexchangeformat.com/CxF3-core
  xrp = http://www.xrite.com/products/prism

Patchar:
  cc:CxF/cc:Resources/cc:ObjectCollection/cc:Object
    @Id, @Name, @ObjectType
    cc:DeviceColorValues/cc:ColorRGB
      @ColorSpecification
      cc:R, cc:G, cc:B

Layoutparametrar:
  cc:CxF/cc:CustomResources/xrp:Prism/xrp:CustomAttributes
    @NumberPatchColumns, @NumberPatchRows, @NumberPatchPages
    @PageWidth, @PageHeight, @PaperOrientation
    @PatchSizeWidthValue, @PatchSizeHeightValue
    @DimensionUnit, @ScramblePatches
```

Prefixen är exempel; implementationen ska matcha namnrymd och lokalt namn. Schema för privata Prism-resurser är inte verifierat. Attributnamn ovan är direkt observerade, inte gissade.

## Layoutmetadata

| Attribut | TXF-värde | PXF-värde |
|---|---|---|
| `NumberPatchColumns` | 30 | 0 |
| `NumberPatchRows` | 23 | 0 |
| `NumberPatchPages` | 3 | 2 |
| `PageWidth` | 279.40 | 50.00 |
| `PageHeight` | 215.90 | 50.00 |
| `PatchSizeWidthValue` | 8.00 | 0.00 |
| `PatchSizeHeightValue` | 7.00 | 0.00 |

Dessa är de sju ändrade attributen i `CustomAttributes`. Gemensamma värden omfattar `PaperOrientation="Landscape"`, `ScramblePatches="False"`, `DimensionUnit="2"` och `MeasurementDevice="i1Pro 3"`.

Sidmåtten motsvarar liggande US Letter om enheten är millimeter: 279,4 × 215,9 mm. Patchmåtten skulle då vara 8 × 7 mm. Detta är en rimlig tolkning av storleksvärdena, **inte en verifierad generell definition av enhetskoden 2**. Enheten ska bekräftas mot i1Profiler eller en renderad originalkarta före fysisk reproduktion.

Rutnätet anger 30 × 23 = 690 positioner per sida. Tre fulla rutnät skulle ha 2 070 positioner, alltså 37 fler än antalet targetpatchar. Filen ger här inte en explicit patch-för-patch-karta som visar hur dessa positioner används. De ska inte automatiskt betraktas som vita patchar eller mätpatchar.

## Vad vi nu kan göra

Vi har ett verkligt referensfall även för TXF-läsning: patchlistan och ovanstående layoutparametrar kan importeras och bevaras. Det gör att läsaren kan verifieras mot verkliga PXF-, TXT- och TXF-filer från samma target.

Vi kan skapa en **ny** instrumentanpassad layout och TIFF16 med korrekt tillhörande TI2. Väljs TXT som källa till styrvärden används dess högre numeriska precision; väljs TXF används de faktiska heltalsvärdena. Filernas värden får inte blandas tyst.

## Vad som fortfarande måste verifieras för samma fysiska karta

- Hur objektordningen kopplas till rad, kolumn och sida, inklusive läsriktning.
- Hur den sista sidan fylls och om extra kontroll- eller utfyllnadspatchar genereras.
- Enhet, faktisk startposition, sidhuvud, mellanrum och identifieringsmarkeringar. Angivna nollmarginaler bevisar inte att targetet börjar i sidans övre vänstra hörn.
- Hur i1Profiler använder defaults och instrumentinställningar när targetet renderas.
- Att en motsvarande TI2 kan beskriva en karta som chartread kan mäta med valt instrument.

En TIFF eller PDF som i1Profiler genererar från denna TXF är ett lämpligt nästa referensunderlag för layoutkontrollen. Den behövs inte för att börja implementera patchimporten, men behövs tillsammans med praktiska tester innan vi lovar identisk rendering och mätbarhet i båda programmen.

## Slutsats för implementationsunderlaget

Tidigare uppgift om att TXF saknas gäller inte längre. Däremot kvarstår skillnaden mellan **import av observerade layoutparametrar** och **verifierad återgivning av originalets fullständiga utskriftslayout**. Dessa ska ha skilda statusflaggor i InkProf.
