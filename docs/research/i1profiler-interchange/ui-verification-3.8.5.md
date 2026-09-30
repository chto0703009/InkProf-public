# Praktisk verifiering i i1Profiler 3.8.5

Datum: 2026-09-25. Källa: direkt granskning av användarens macOS-program och filer exporterade från detta. Detta är versionsbundna observationer, inte en fullständig formatspecifikation.

## Miljö och avgränsning

Startsidan visar i1Profiler 3.8.5, XRD 3.0.152, Prism 3.7.8.18027 och aktiv licens ”PUBLISH & DEVICE LINK” med gröna markeringar. Användaren har anslutit en dongel. Någon jämförelse med urkopplad dongel gjordes inte.

Ingen fysisk mätning, utskrift eller profilgenerering utfördes. Programmet rapporterade i1Pro 3 saknas i targetflödet och i1Pro 2 saknas efter inläsning av det äldre mätunderlaget. Licensåtkomst och anslutet mätinstrument är separata frågor. Originalfilerna skrevs inte över.

## Observerade import- och exportval

| Plats i RGB-profileringsflödet | Val som faktiskt visas |
|---|---|
| Patch Set → Load | Patch sets (.pxf), CGATS (.txt), Cxf (.cxf) |
| Test Chart → Save as | TIFF (.tif), PDF (.pdf), EPS (.eps) |
| Measurement → Load | Measurement (.mxf), Reference Measurement (.rmxf), CGATS (.txt), CxF (.cxf) |
| Measurement → Save | MXF, RMXF, CxF, Tab Delimited Text, i1Profiler CGATS Spectral/CIELab/Custom, ProfileMaker5 CGATS Spectral/CIELab |

En listad filtyp är inte ett bevis på att alla varianter accepteras. CMXF visades inte i denna mätimportdialog; det utesluter inte stöd i andra arbetsflöden. **RMXF är ett tillkommande observerat format**, vars struktur ännu inte analyserats. Det får inte förväxlas med CMXF eller ges ett påhittat konverteringskontrakt.

## Faktisk TIFF-export

Den redan inlästa uppsättningen ”Chart 2033 Patches” visade 2033 patchar och Scramble av. Nästa steg visade i1Pro 3, Letter, mm, nollmarginaler och tre sidor. Export via Save as → TIFF skapade tre separata TIFF-filer.

Kontroll av samtliga filers TIFF-taggar gav:

- 1084 × 784 pixlar, RGB, en bild per fil.
- BitsPerSample = (8, 8, 8): **8 bitar per kanal**.
- Upplösning cirka 101,6 dpi (4 pixlar/mm).
- Ingen inbäddad ICC-profil upptäcktes.

Detta gäller den provade exportvägen och inställningen, inte ett generellt påstående om alla i1Profiler-exporter. Något bitdjupsval visades inte i den använda sparadialogen. Inställningen för ICC-profilens bitdjup ska därför inte användas som bevis för targetbildens bitdjup.

TIFF-bildernas faktiska patchordning, beskärning, kontrollfält och färgvärden har inte jämförts pixelvis med TXF. Denna körning är inte en verifierad TXF → bild → fysisk mätning-cykel. InkProfs TIFF16-krav kvarstår och behöver verifieras separat i dess Argyll-baserade export.

## Faktisk MXF-import och spektral CGATS-export

Filen `/Library/Application Support/X-Rite/i1Profiler/ColorSpaceRGB/Measurements/Chart 2040 Patches.mxf` öppnades via Measurement → Load. Programmet visade rätt namn, fyra sidor, RGB Printer, XRGA, geometri 45:0 samt valen M0 (UV Included), M1 (D50), M2 (UV Excluded). XML-granskningen av samma original finns i [MXF-exempelrapporten](mxf-examples-inspection.md).

Save → i1Profiler CGATS Spectral användes med M0 valt i vyn. **En enda export skapade tre filer med suffix _M0, _M1 och _M2.** Basnamnet råkade redan innehålla M0; det är suffixet och filens MEASUREMENT_SOURCE som anger respektive villkor.

Varje fil innehåller CGATS.17, 2040 rader och 41 fält: SAMPLE_ID, SAMPLE_NAME, tre RGB-kanaler och 36 spektralband från 380 till 730 nm med 10 nm intervall. RGB lagras på skalan 0–255. Spektralvärdena motsvarar MXF:s reflektansfraktioner, inte procent.

Numerisk jämförelse av alla rader mot respektive grupp i original-MXF:

| Kontroll | M0 | M1 | M2 |
|---|---:|---:|---:|
| Antal rader | 2040 | 2040 | 2040 |
| Största RGB-avvikelse, skala 0–255 | 0 | 0 | 0 |
| Största spektrala avvikelse, reflektansfraktion | 0,00005 | 0,00005 | 0,00005 |

Spektra skrivs med fyra decimaler. Avvikelsen motsvarar högst 0,005 procentenheter reflektans; den är en exportavrundning, inte mätosäkerhet. Jämförelsen använde ordningen från just denna verifierade export, inte ett generellt antagande för godtyckliga filer.

Exportens SAMPLE_ID är löpnummer och SAMPLE_NAME exempelvis A1, B1. De ska inte likställas med XML-objektens ID. Textformatet har inte separata Page/Row/Column-fält i denna export. MXF-originalets fullständiga metadata och positionskoppling ska därför arkiveras även när CGATS används.

## Konsekvenser för InkProf

1. Direkt MXF-import är fortsatt lämplig för bevarande av precision, metadata och alla mätvillkor.
2. i1Profiler CGATS Spectral är nu en konkret provad alternativ exportväg från i1Profiler. InkProfs framtida adapter behöver känna igen SPECTRAL_NM380 etc., RGB 0–255 och reflektansfraktioner. Argylls spektrala procentkodning kräver uttrycklig skalning vid TI3-export.
3. Gruppera flerfils-exporten i JSON-manifest och läs villkoren ur innehållet; välj inte tyst första filen.
4. Bevara skillnaden mellan observerade men oprövade menyval, faktisk filimport/export och fullständig kompatibilitet. Ingen InkProf-genererad fil har ännu återimporterats eller fysiskt mätts här.
5. Undersök RMXF och CMXF i sina respektive arbetsflöden senare. De behövs inte för första targetleveransen.

## Sparat verifieringsunderlag

`tests/fixtures/i1profiler/ui-verification-3.8.5/` innehåller tre exporterade TIFF-filer, tre spektrala CGATS-filer samt `verification-results.json` med kontrollsummor, TIFF-egenskaper och numeriska jämförelser. Filerna är referensdata från i1Profiler, inte en ny InkProf-implementation.
