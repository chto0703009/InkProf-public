# Acceptans av provat RGB-utbyte – 2026-09-27

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Christer har accepterat det provade utbytet mellan InkProf och i1Profiler.
Acceptansen gäller nedanstående konkreta flöden, inte alla programversioner,
filvarianter, instrument eller mätvillkor.

| Flöde | Verifiering |
|---|---|
| TI2 → InkProf PXF → i1Profiler | Användaren importerade, skrev ut och mätte 575 patchar. |
| TI1 → InkProf PXF → i1Profiler | Användaren bekräftade lyckad import av `InkProf-575-from-TI1.pxf`. RGB och patchordning är identiska med den godkända TI2-exporten. |
| i1Profiler MXF → InkProf JSON/TI3 | Samtliga 575 spektra verifierade genom MATLAB-importen. |
| InkProf-mätning → MXF → i1Profiler | Användaren bekräftade import av `InkProf-575-M0-updated.mxf`; referensens metadata/layout behölls och spektra ersattes. |
| Importerad MXF → punktrevision → TI3 → återimport | Automatiserat test med syntetisk kandidat: endast vald patch ändras, original och historik bevaras. Inte ett fysiskt instrumentprov av hela denna kedja. |

## Godkänd exportväg och begränsningar

`exportPxfTarget` använder RGB8-kompatibel PXF. Godkännandet gäller
heltalsvärdena i detta prov; fraktionella RGB och alla andra mottagarvarianter
är inte kvalificerade.

`exchange/export_reference_mxf.py` gör den godkända spektrala exportvägen
återanvändbar. Den reproducerar den accepterade filen byte för byte från
samma källor. Den kräver M0/XRGA, 36 band 380–730 nm och entydiga TargetN/ID,
RGB- och positionskopplingar. JSON-sidecar anger verklig källa och hashvärden.
Referensens Creator, datum, privata inställningar och layout bevaras av
kompatibilitetsskäl och beskriver **inte** InkProf-originalets utskrift.
Exporten är inte en instruktion för att mäta om originalutskriften.

`exchange/export_mxf.py` är den äldre experimentella exportören som ändrar
layout och metadata. Dess tidigare filer avvisades; den är inte den
mottagarverifierade exportvägen. Creator-fältet ensamt är inte bevisat som
orsak till de tidigare importfelen.

## Korrigerad mätning och jämförelse

Punktkontroller av A22/U22 och efterföljande framåtriktad ommätning av hela
rad 22–23 gav stöd för att tidigare sparad radordning var fel. En ny komplett
revision ersätter 42 patchar och bevarar övriga 533 oförändrade. Original och
separata punktrevisioner finns kvar. Ny revision:
`measurement-20260927-154833490-rows22-23.json` och motsvarande TI3.

Direkt jämförelse av rättad TI3 med i1Profilers ursprungliga MXF, med gemensam
D50/2°-beräkning från spektra:

- 575 patchar, samma RGB inom decimalavrundning och samma 36 våglängder.
- Medel ΔE00 0,5616; median 0,5266; P95 1,0507; maximum 1,7035.
- 536 patchar under 1 ΔE00; alla 575 under 2.
- Spektralt RMS-fel 0,8001 procentenheter reflektans.

Detta är olika utskrifter: resultatet omfattar både utskriftsvariation och
mätvariation. Det är inte isolerad instrumentrepeterbarhet eller en
verifiering av en färdig ICC-profil. Den tidigare accepterade MXF-exporten
innehåller fortfarande den äldre radordningen; den är kompatibilitetsbevis,
inte den aktuella korrigerade profileringsmätningen.

## Kvarstående gränser

Automatisk dubbelriktad radidentifiering kan fortfarande misstolka vissa
icke-randomiserade rader. Ny kod varnar för misstänkt omvänd ordning; den
vänder inte data automatiskt. Import utan entydig layout/koppling avvisas.
Andra MXF-varianter, fysisk punktommätning efter MXF-import samt ICC-generering
och profilvalidering kräver fortsatt provning.

## Kontroller inför commit

- 31 Python-tester passerade (`unittest discover`, `test_*.py`).
- 7 MATLAB-tester passerade: PXF-export, mätimport/ersättning/återimport,
  punktmätning med simulerat instrument samt parade svep.
- Den återanvändbara MXF-kompatibilitetsexportören reproducerade användarens
  accepterade MXF byte för byte (SHA-256
  `6a5a4f5d8dd7151878558108412607a09c78ac0558308dcd73ec40f6ab8c782a`).
- `git diff --check` utan fel. Fysiska mätningar ingår inte i automatiska tester.
