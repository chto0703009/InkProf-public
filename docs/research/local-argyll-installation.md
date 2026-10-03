# Lokal ArgyllCMS-installation

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Kontrollerat 2026-09-25 efter sökväg från Christer.

## Sökvägar

- Installationsrot: `/Users/christer/Argyll_V2.3.1`
- Dokumentationsindex: `/Users/christer/Argyll_V2.3.1/doc/ArgyllDoc.html`
- Verktygskatalog: `/Users/christer/Argyll_V2.3.1/bin`

`targen`, `printtarg` och `chartread` finns i verktygskatalogen. Dessa sökvägar är lokal miljökonfiguration, inte hårdkodade installationskrav för InkProf.

## Dokumenterat stöd för första leveransen

Den lokala `doc/printtarg.html` beskriver:

- TIFF med 16 bitar per kanal genom `-T`.
- TI2 som åtföljande beskrivning av styrvärden och layout.
- Randomiserad patchplacering som normalbeteende; `-r` avaktiverar randomiseringen.
- `-R` för ett bestämt slumpfrö.
- Instrumentanpassad layout, sidstorlek och marginaler.

Detta täcker de centrala verktygsfunktionerna för InkProfs första planerade leverans. Det är dokumenterat stöd, inte en genomförd verifiering av TIFF-export eller fysisk mätning.

## Versions- och körstatus

Katalognamnet anger V2.3.1 men dokumentationsindexets rubrik anger **V2.3.0**, daterad 27 juni 2022. Denna skillnad ska bevaras i miljöinventeringen; binärversionen får inte bestämmas enbart från katalognamnet.

Försök att köra `printtarg '-?'` och `targen '-?'` avslutades med **exitkod 137 utan utdata**. Orsaken är inte fastställd. Installationen är därför ännu inte verifierad som körbar på den aktuella datorn. Inga säkerhetsinställningar eller programfiler har ändrats.

Före implementationens integrationsprov behöver en fungerande Argyll-installation väljas eller denna installation felsökas. Därefter registreras faktisk verktygsversion och ett litet TI1 → TIFF16 + TI2-prov körs.

## Användning i InkProf

### Fungerande installation funnen vid implementationen

Den 2026-09-25 verifierades `/usr/local/bin/targen` och `/usr/local/bin/printtarg`, symlänkar till Homebrew-installationen `/usr/local/Cellar/argyll-cms/3.5.0/bin/`. Båda identifierar sig som **3.5.0**. Denna installation kör targetgenerering och TIFF16/TI2-export i InkProfs integrationstester. MATLAB R2025b Update 7 används. De tidigare installationsproblemen ovan kvarstår som historik; inga säkerhetsinställningar behövde ändras.

InkProf ska kunna konfigurera sökvägen till Argyll och registrera den använda versionen i JSON-manifestet. Den lokala dokumentationen används som versionsnära referens tillsammans med verktygens egen hjälptext när de kan startas.
