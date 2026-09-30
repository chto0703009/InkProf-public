# Återanvändning av färgberäkningar från SpectraLab och Camera-41

Datum: 2026-09-25. Status: inventering och föreslaget integrationskontrakt; ingen InkProf-integration är implementerad här.

## Syfte

InkProf ska ha egna, gemensamma och verifierade färgberäkningar, utan körberoende till SpectraLab eller Camera-41. Inventeringen är kunskapsunderlag och möjliga licenskontrollerade kodkällor, inte en lista över nödvändiga installationer. Filkonvertering och färgberäkning är separata operationer. En exporterad fil ska normalt återge redan tolkade data, inte räkna om färger utan ett uttryckligt beräkningsbeslut.

Denna inventering bygger på läsning av lokal kod i SpectraLab v1.2.1-dev och Camera-41 v0.9.0-dev. Den visar vilka rutiner som finns, men innebär inte att deras fullständiga beroenden eller numeriska riktighet har testats på nytt. Vid eventuell kodadaptation ska ursprungsversion och licens dokumenteras; rutiner och testunderlag ska ingå i InkProf.

## Identifierade rutiner

| Behov | Befintlig rutin | Kontrakt och begränsning i granskad kod |
|---|---|---|
| Reflektans och belysning till XYZ, xyY och Lab | `spectralab.analysis.colorimetry` | Tar spektrala objekt/samlingar/arkiv och explicit illuminant-SPD. En gemensam referensvitskala bevarar patcharnas relativa ljushet. Nu stöds `CIE1931_2`. |
| Spektral integration till XYZ | `spectralab.analysis.xyz` | Integrerar med CIE 1931 2°-funktioner. En lägre nivå än den kompletta reflektansberäkningen. |
| XYZ till Lab | `spectralab.analysis.lab` | Kräver prov-XYZ och referensvit-XYZ i kanoniska strukturer med samma normalisering. |
| XYZ till xyY | `spectralab.analysis.xyY` | Bevarar Y; noll eller ogiltig tristimulussumma avvisas. |
| Kromatisk adaptation | `camera41.profile.adaptXYZWhitePoint` | Bradford med explicit källvitpunkt och valbar målvitpunkt; standardmål är D50. |
| Färgskillnad | `camera41.negative.deltaE00` | CIEDE2000 mellan motsvarande ändliga Lab-rader. Detta är ett felmått, inte en färgrymdskonvertering. |
| XYZ D50 till linjär ACEScg | `camera41.negative.convertXYZD50ToACEScg` | Anpassar till D60 och använder AP1-primärer. Ingen klippning eller tonkurva. Finns för möjliga bildflöden, inte som generell skrivarinvers. |

Inventeringen är inte ett påstående om stöd för alla inversa omvandlingar. Lab → XYZ, xyY → XYZ, valfria observatörer och godtyckliga RGB-arbetsrymder behöver inventeras eller implementeras och verifieras separat när de krävs.

## Kritisk normaliseringsregel

SpectraLabs granskade reflektansväg lagrar reflektansfaktor i procent och räknar med `r = R / 100`. Den viktar med vald illuminant och färgmatchningsfunktionerna. Samma skalfaktor, bestämd av illuminantens referensvit, används för alla patchar:

```text
prov-SPD = r(lambda) * S(lambda)
vit-SPD  = S(lambda)
k        = 100 / Y_vit_raw
XYZ_prov = k * XYZ_prov_raw
XYZ_vit  = k * XYZ_vit_raw
```

**Normalisera inte varje patch separat till Y = 100.** Den lägre nivåns `xyz(..., Normalization="Y100")` gör just en normalisering av det enskilda indatat och ska därför inte användas direkt för varje reflektanspatch. Då försvinner ljushetsskillnaderna. Använd den samlade reflektansvägen och ett explicit belysningsspektrum.

## Föreslaget beräkningskontrakt i InkProf

- Bevara ursprungsspektrum, våglängder, storhet och skala. Dokumentera eventuell omsampling och integrationsområde.
- Ange illuminant-SPD, observatör, referensvit och XYZ-normalisering tillsammans med resultatet. Den granskade implementationen stöder inte automatiskt exempelvis 10° bara för att formatet kan beskriva det.
- Bevara importerat XYZ/Lab som ursprungsdata. Nya beräkningar skapar en separat, versionsmärkt representation och skriver inte över originalet.
- Separera instrumentrapporterad kolorimetri från den kanoniska beräkningen. SpectraLabs beteende utan explicit illuminant är en särskild väg; InkProf bör ge en uttrycklig SPD för reproducerbara reflektansberäkningar.
- Skilj en omräkning av samma koordinater från kromatisk adaptation. Beräkning under en annan belysning från spektra och Bradford-adaptation är olika operationer.
- Använd endast jämförbara Lab-värden för ΔE00 och redovisa referensvillkoren. Funktionens matematiska inmatningskontroll ersätter inte denna semantiska kontroll.
- Bevara enhets-RGB som styrvärden. Behandla dem inte automatiskt som sRGB, ACEScg eller någon annan standardiserad bildrymd.
- En färgberäkning till standard-RGB ersätter inte inversion av skrivarens uppmätta framåtmodell eller en ICC-transform.
- Spara beräkningsversion, använda indata och funktionsversion. Exportörer serialiserar resultatet; de ska inte ha egna dolda färgberäkningar.

Mätvillkor som M0/M1 och beräkningsbelysning som D50 ska registreras separat. Reflektansberäkningen innebär inte i sig att ett mätflöde är kvalificerat enligt ett visst mätvillkor.

## Integration och verifiering

Enligt [beslut 007](../decisions/007-independent-inkprof.md) ska beräkningsrutinerna finnas i InkProf. Kunskap eller licensmässigt förenlig kod från tidigare projekt kan återanvändas med ursprungsnotis, men deras API:er får inte bli körberoenden. Egen kolorimetri är planerad och inte färdigställd i denna dokumentationsuppgift.

Föreslagna acceptansprov inför implementation (även på en installation utan de andra projekten):

1. En ideal reflektans på 100 procent får samma XYZ som referensvitt. En konstant 50-procentsreflektans får halva XYZ under samma villkor.
2. Samma prov ger samma kolorimetri oavsett om det kommer från MXF, TI3 eller ett SpectraLab-arkiv, när spektra och villkor är lika.
3. XYZ/Lab och adaptation verifieras mot oberoende referensvärden. Kontrollera även noll, neutrala färger och relevanta gränsfall.
4. ΔE00 verifieras mot en publicerad referensuppsättning; jämförelse med sig själv räcker inte.
5. Läs-/skrivcykler bevarar originaldata. Avrundning och förändringar i härledda koordinater får angivna toleranser.

## Kodunderlag för inventeringen

Lokala källrötter vid granskningen:

- SpectraLab: `/Users/christer/Desktop/SpectraLab/SpectraLab_v1.2.1-dev`
- Camera-41: `/Users/christer/Desktop/Camera-41/Camera-41_v0.9.0-dev`

Filer relativt respektive rot:

```text
SpectraLab:
  docs/REFLECTANCE_COLORIMETRY.md
  spectralab/+spectralab/+analysis/colorimetry.m
  spectralab/+spectralab/+analysis/xyz.m
  spectralab/+spectralab/+analysis/lab.m
  spectralab/+spectralab/+analysis/xyY.m

Camera-41:
  src/+camera41/+profile/adaptXYZWhitePoint.m
  src/+camera41/+negative/deltaE00.m
  src/+camera41/+negative/convertXYZD50ToACEScg.m
```

Dokumentet kompletterar [datautbyteskontraktet för i1Profiler och ChromIQ](i1profiler-interchange/README.md). Formatbeskrivningarna anger hur data lagras; detta dokument anger vilka befintliga beräkningar som kan återanvändas och under vilka villkor.
