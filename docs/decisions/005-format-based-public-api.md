# 005 - Format- och operationsbaserade namn i publikt API

Datum: 2026-09-25. Status: beslutat av projektägaren och implementerat.

## Beslut

InkProfs publika MATLAB-API ska namnges efter **operationen och dataformatet**, inte efter ett program eller en leverantör som producerar eller använder formatet.

Detta gäller inom ett oberoende open-source-projekt under `GPL-3.0-or-later`. Saklig interoperabilitetsdokumentation är viktig för att användare ska kunna förstå öppna arbetsflöden utan att InkProf framställs som en produkt från eller godkänd av en tredjepartsleverantör.

En import, rendering eller export ska därför kunna beskrivas utan att API-namnet antyder att tredjepartsprogrammet krävs, styr processen eller äger det interna arbetsflödet. PXF och RGB-CGATS kodas exempelvis till TIFF16 med:

```matlab
inkprof.createTiff16(...)
```

TXF-export görs med:

```matlab
inkprof.exportTxfTarget(...)
```

En kompakt ensidig A4-layout väljs med:

```matlab
CompactA4=true
```

## Genomförda namnändringar

| Tidigare namn | Beslutat namn |
|---|---|
| `inkprof.createI1ProfilerTiff` | `inkprof.createTiff16` |
| `inkprof.exportI1ProfilerTarget` | `inkprof.exportTxfTarget` |
| `I1ProfilerA4=true` | `CompactA4=true` |

De tidigare namnen tas bort i stället för att behållas som parallella alias. Projektet är ännu i ett tidigt utvecklingsskede, och ett enda entydigt API väger tyngre än bakåtkompatibilitet med de kortlivade namnen.

## Namnregel

- Funktionens verb beskriver handlingen, exempelvis `create`, `import`, `export` eller `verify`.
- Resten av namnet beskriver resultatet eller formatet, exempelvis `Tiff16`, `TxfTarget` eller `Cgats`.
- Leverantörs- och produktnamn används inte i publika funktions- eller alternativnamn när formatet eller operationen räcker för att beskriva beteendet.
- Produktnamn får användas i dokumentation, testfixturer, proveniens och kompatibilitetsrapporter när den faktiska källan eller mottagaren behöver anges.
- Ett leverantörsspecifikt namn kräver ett nytt uttryckligt designbeslut om beteendet verkligen är bundet till ett proprietärt API och inte kan beskrivas korrekt genom format eller operation.

## Varumärkesregel

- InkProf ska inte använda tredje parts varumärken i projektnamn, logotyp, publika API-namn, genererade bildrubriker eller TIFF-fältet `Software`.
- Ett tredjepartsnamn får endast användas beskrivande när det behövs för att identifiera filursprung, testad programversion, kompatibilitet eller avsedd mottagare.
- Beskrivande användning ska vara saklig och inte antyda partnerskap, certifiering, sponsring eller godkännande.
- Tredjepartslogotyper, grafisk profil och upphovsrättstext kopieras inte till InkProf-genererade filer.
- Genererade filer identifierar InkProf som avsändare. Referensfiler bevaras separat och oförändrade för verifiering och proveniens.
- README och distribuerad dokumentation ska ange att tredjepartsnamn tillhör respektive rättighetsinnehavare och att InkProf är ett oberoende projekt.

## Motiv

PXF, TXF och CGATS förekommer i arbetsflöden med flera verktyg. Ett produktnamn i funktionsnamnet gör API:t snävare än dataflödet och kan felaktigt antyda ett programberoende. Formatbaserade namn gör det tydligare vad funktionen läser, skapar eller exporterar och ger ett stabilare API om fler kompatibla producenter eller mottagare tillkommer.

Beslutet ändrar inte kompatibilitetsstatus. En TIFF-layout eller TXF-export kan fortfarande vara baserad på en observerad referens och ännu sakna full fysisk verifiering. Sådana begränsningar ska anges i resultatmetadata och dokumentation, inte döljas eller överdrivas av funktionsnamnet.

## Relaterade beslut

- [004 - Intern JSON och Argyll som primära utbytesformat](004-argyll-primary-json-intermediate.md)
- [001 - Grundläggande projektbeslut](001-project-foundation.md)

## Komplettering 2026-09-26

Genererade statusfält använder `receiverLayoutVerified` och `receiverImportVerified`. Bildrubrik och Software-tag identifierar InkProf. Produktnamn bevaras endast där de behövs för saklig kompatibilitetsproveniens, oförändrade referensdata eller tekniska formatidentifierare. Den valda 575-modellens geometri och etiketter behålls.
