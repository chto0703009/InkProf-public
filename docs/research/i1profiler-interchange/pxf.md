# PXF: i1Profiler Patch Sets

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Datum: 2026-09-25. Status: preliminärt läs-/skrivkontrakt för InkProf.

## Källbelagd roll

`.pxf` används för i1Profilers patchuppsättningar. [S5] Formatet är CxF3-baserat och innehåller enhetsvärden, exempelvis RGB eller CMYK. [S4] Se [gemensam definition, källor och versionsgränser](README.md).

## Föreslagen betydelse i InkProf

En PXF importeras som **targetdefinition**, inte som mätresultat. Patchidentiteter, namn, ordning, kanalnamn, styrvärden och kodning ska bevaras. En patchuppsättning bevisar inte var patcharna ligger på ett redan utskrivet ark.

## Konkret läskarta från granskad kod

ChromIQ:s RGB-export använder följande struktur. Den är en kodobservation, inte ett komplett schema eller en garanti för alla PXF-filer:

```text
CxF / Resources / ObjectCollection / Object
  @Id, @Name, @ObjectType
  DeviceColorValues / ColorRGB
    @ColorSpecification
    R, G, B
```

XML-namnrymden ska hanteras enligt den gemensamma beskrivningen. Bevara den refererade färgspecifikationen även om dess betydelse inte är fullt tolkad. Enhets-RGB ska inte automatiskt behandlas som sRGB.

## Importkrav

- Identifiera rätt samling targetobjekt; blanda inte in eventuella mätobjekt.
- Kontrollera kanaler och numeriska värden. Avvisa eller markera en kanaluppsättning som importören ännu inte stöder.
- Fastställ kodning från verifierad variant och tillgänglig metadata. Skala inte efter högsta patchvärdet.
- Bevara upprepade färger som separata patchar och behåll en explicit ordningskarta.

## Exportkrav

- Generera objekt-ID:n och referenser utan kollisioner.
- Välj mottagarens verifierade kodning och rapportera avrundning. ChromIQ:s observerade RGB-export använder heltal 0–255; detta ska inte generaliseras till alla CxF3-filer.
- Skriv bara utökningar som exportören förstår eller kan bevara med giltiga referenser.
- Skapa inte låtsasmätningar för att fylla ut en targetdefinition.

## Utbyte med Argyll

PXF och TI1 har motsvarande targetroll. Konverteringen behöver bevara enhetsvärdenas betydelse, inte bara siffrorna. För 0–255-kodad RGB är omräkningen till TI1-procent `100 × värde / 255`; en annan kodning kräver en annan omräkning.

Layout, profileringsinställningar och andra privata resurser kan sakna motsvarighet i TI1. Redovisa bortfall och arkivera originalet. Exporten måste kontrolleras i i1Profiler innan den kallas kompatibel.

## Verifieringsfall

Prova svart, vitt, mellanvärden, upprepade RGB-värden och värden som inte motsvarar hela 8-bitarssteg. Kontrollera om återexport ändrar precision eller ordning. Exakta obligatoriska PXF-utökningar för användarens version återstår att fastställa från referensfiler.

## Praktisk granskning av i1Profiler 3.8.5

Se [verifieringsrapporten](ui-verification-3.8.5.md) för observerade menyval, utförd MXF-import, spektral CGATS-export och TIFF-export. Rapporten skiljer utförda prov från återstående format- och layoutverifiering.

## Export från TI1/TI2 i InkProf

```matlab
report = inkprof.exportPxfTarget(inputFile, outputFile);
```

`inputFile` är en RGB `.ti1` eller `.ti2`; `outputFile` slutar med `.pxf`.
Funktionen använder den medföljande, portabla mallen
`resources/templates/rgb-patch-set.pxf`, byggd från den lokalt granskade
`Chart 575 Patches.pxf`. XML-huvud, namnrymder, färgspecifikation och privat
Prism-struktur bevaras. `Template=...` kan ange en annan kompatibel PXF-mall.
`Name=...` sätter beskrivning och titel. Creator anger InkProf.

RGB skalas från 0–100 till 0–255. Standardläget `RGBEncoding="rgb8"` skriver
heltal och accepterar endast värden inom 0,00002 RGB-kodsteg från heltalsnätet
(tolerans för TI1/TI2:s decimalavrundning). Övriga värden avvisas.
`RGBEncoding="round8"` tillåter uttryckligen kvantisering; `"float"` bevarar
decimaler men är experimentellt för mottagaren. Patchordning och upprepade
färger bevaras. XML använder Target1/c1, Target2/c2, …; originalnamn och
SAMPLE_ID bevaras i JSON med samma basnamn. Exporterade RGB-värden och
maximal ändring sparas där också. TI2-utfyllnad exkluderas
enligt InkProfs befintliga chart-import. De kvarvarande patcharnas ursprungliga
koordinater finns i JSON. Ingen ny randomisering görs.

PXF är patchdefinitioner, inte mätdata eller en kopia av TI2-utskriftens layout.
Prism-mallens privata inställningar är kompatibilitetsstandardvärden, inte
verifierade uppgifter om källans utskrift eller profil. JSON sparar källhash,
mallhash, exporthash, targetInfo, mapping, borttaget utfyllnadsantal och
numeriskt återläsningsfel. Projektmanifestet uppdateras när utdata ligger i
ett InkProf-projekt. Befintliga PXF/JSON-filer skrivs aldrig över.

Automatiska prov omfattar TI1 med fraktionella och dubblerade RGB, XML-escaping,
TI2 med utfyllnad/koordinater, CMYK-avvisning och skydd mot överskrivning.
Mottagarimport av RGB8-export från både TI1 och TI2 är användarverifierad
för 575-exemplet. Fraktionella RGB är fortfarande experimentella.
Se [acceptansrapporten](acceptance-20260927.md).

Första genererade PXF-kandidaten avvisades av i1Profiler med "can not load patch file set". V2 skriver heltals-RGB, TargetN-namn och ett fält per XML-rad som referensfilen, samt WriteProtected=True och ScramblePatches=False som i ChromIQ. V2 accepterades sedan av mottagaren. Vilken enskild ändring som löste det tidigare felet är inte isolerad.
