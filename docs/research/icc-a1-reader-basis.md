# A1 – underlag för InkProfs ICC-läsare

Datum: 2026-09-27. Status: implementationsunderlag; A1 är nu implementerad. Se [aktuell användning](../usage/icc-reader.md).

## Rekommendation och avgränsning

Bygg en självständig läsare i Python med standardbiblioteket (`struct`, `pathlib`, `hashlib`, `json`). MATLAB Base står för filval och presentation på engelska. Ingen MATLAB-toolbox eller körberoende till ChromIQ behövs för detta steg.

A1 läser identitet, profilhuvud, taggförteckning, beskrivningar och enkla XYZ-taggar. LUT-taggar identifieras men används inte för färgomvandling. Att en profil kan läsas betyder inte att dess färgåtergivning är validerad. Oförändrad import och Spara som tillhör A2; profilgenerering kommer senare.

## Normativ grund

ICC anger ett 128-byte huvud, följt av taggantal och 12-byte poster med signatur, offset och storlek. Flerbytesvärden läses big-endian. Taggarnas start är fyrbytesjusterad; storleken utesluter avslutande padding. Flera taggar får dela identiskt dataintervall. Delvis överlapp och dubbla taggsignaturer ska inte behandlas som sådan delning. Taggarnas ordning behöver inte följa datans ordning. Texttyper omfattar bland annat `mluc`; XYZ använder signerad fixed-point. Krav beror på profilklass och version. Huvudets PCS-belysning ska inte tolkas som uppmätt pappersvit. Källa: [ICC.1:2022, särskilt kapitel 4, 7–10](https://www.color.org/specifications/ICC.1-2022-05.pdf).

Äldre profiler kräver även [ICC:s v2-specifikation](https://www.color.org/v2spec/). V4.4:s tillkommande krav ska inte automatiskt användas för att underkänna äldre v2.1/v4.2-profiler. Läsaren ska skilja stödd version, strukturellt fel och ännu ej implementerad tolkning.

## ArgyllCMS och ChromIQ

[Argyll iccdump](https://www.argyllcms.com/doc/iccdump.html) används som oberoende jämförelse där den installerade versionen stöder profilen. Lokalt rapporterar iccdump 3.2.0 och varnar för saknat v4-stöd. Därför krävs ytterligare kontroll med verifierat v4-stöd för v4-provet; valet av sådant kontrollverktyg återstår.

ChromIQ granskades lokalt vid commit `92e6ead022fd57f4ecb80bf03670361b1b882247`:

- [workflow/icc_info.py](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/workflow/icc_info.py) visar en enkel Python-läsare. Den tolkar huvud, beskrivning och vit-/svartpunkt. Dess mluc-läsning väljer första språkposten och kontrollerar inte alla interna intervall mot taggens deklarerade storlek. Vissa textfel blir tom text. InkProf behöver tydligare diagnostik och striktare gränskontroller.
- [core/icc_text.py](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/core/icc_text.py) visar betydelsen av att bevara Unicode i äldre beskrivningar.
- [workflow/icc_convert.py](https://github.com/itsab1989/ChromIQ/blob/92e6ead022fd57f4ecb80bf03670361b1b882247/workflow/icc_convert.py) är inte en generell lösning för våra LUT-skrivarprofiler: konverteringen är begränsad till matrix/TRC RGB. Ingen versionskonvertering ingår i A1.

Ingen ChromIQ-kod har kopierats. Underlaget används för egen implementation mot ICC-specifikationen.

## Verkliga testprofiler

Följande uppgifter kommer från lokal binär inspektion, användarens uppgifter och tillverkarens instruktion. Originalen har bevarats som referensfiler i det lokala profileringsprojektet.

| Profil | Version | Klass / enhet / PCS | Tabelltyper | Medieinställning |
|---|---|---|---|---|
| 3880 IGGFS Neutral.icm | 2.1.0 | prtr / RGB / Lab | mft2 | Premium Luster, enligt användaren |
| 3880 ScPh Glossy_opt.icm | 4.2.0 | prtr / RGB / Lab | mAB / mBA | Premium Glossy, enligt användaren |
| HFA_Eps3880_PK_FABaryta.icc | 2.4.0 | prtr / RGB / Lab | mft2, även privata taggar | Premium Luster, enligt medföljande Hahnemühle-PDF |

Ingen av dessa är angiven för matt papper. De första två är användarens i1Profiler-profiler för Epson Stylus Pro 3880. Den tredje avser Hahnemühle FineArt Baryta med Photo Black. Medieinställning är inte samma sak som pappersproduktens namn. Uppgifterna bevisar inte vilket utskriftsrecept som användes för 575-målet. Projektmappens historiska namn Canon är inte belägg för skrivarmodell.

## Föreslaget JSON-kontrakt

En separat ICC-metadatapost länkas från projektmanifestet. Binär originalfil är fortsatt auktoritativ; JSON ersätter inte profilen.

- `source`: ursprunglig sökväg, projektrelativ kopia när sådan finns, SHA-256, faktisk filstorlek och importtid.
- `header`: deklarerad storlek, full version, klass, enhetsfärgrymd, PCS, datum, CMM, skaparsignatur, flaggor, attribut, intent och profil-ID där tillämpligt. Bevara råa signaturer jämte visningsnamn.
- `tags`: signatur, typ, offset, storlek, delat intervall, tolkad sammanfattning och diagnostik. Okända taggar finns kvar i originalfilen och förteckningen.
- `descriptions`: samtliga tillgängliga språkposter, inklusive originalkodning och vald visningstext.
- `diagnostics`: stabil felkod, allvarlighetsgrad, berörd tagg/byteposition och begriplig förklaring.
- `capabilities`: vad läsaren faktiskt tolkat. Skilj läsbar profil från kompatibel RGB-outputprofil för ett senare profileringssteg.
- `declaredPrintSettings`: användar-/tillverkaruppgifter med källa, separat från uppgifter avlästa ur ICC.

Skaparsignatur är en ledtråd, inte säker identifiering av programversion. Saknad information ska vara okänd, inte fyllas i från filnamnet. A1 ska inte uppskatta fysisk densitet eller metamerism från profilhuvudet.

## Små implementationssteg och acceptans

1. **Binär grundläsare:** kontrollera hela taggkatalogen och varje intervall innan data tolkas. Begränsa resursåtgång från orimliga räknare. Jämför faktisk och deklarerad filstorlek och redovisa skillnader.
2. **Text och enkla värden:** tolka beskrivning, lokaliseringar och XYZ; kontrollera interna längder inom respektive tagg. Behåll varningar synliga om en enskild tagg inte kan tolkas.
3. **MATLAB-dialog:** filval, profilsammanfattning, taggtabell och diagnostik. Ingen profiländring eller färgomvandling. Non-RGB kan identifieras men får inte godkännas som RGB-underlag.
4. **Verifiering:** jämför de tre riktiga profilerna med externa verktyg inom deras verifierade stöd. Kontrollera originalhash före/efter. Komplettera med syntetiska filer för trunkering, fel storlek, trasig mluc, Unicode, duplicerad signatur, tillåtet delat intervall och otillåten överlappning. En saknad valfri svartpunkt får inte ensam göra en profil oläsbar.

A1 är klart när dessa kontroller passerar och begränsningarna visas korrekt. Full tolkning/utvärdering av LUT-tabeller och bedömning av profilkvalitet ligger utanför denna leverans.

## Komplettering: Colour och LittleCMS

[Colour Science for Python](https://www.colour-science.org/) installeras som `colour-science` och importeras som `colour`. InkProf har redan version 0.4.6 och använder den i bland annat spektralanalys och färgjämförelser. Den fortsätter vara vårt verktyg för kolorimetri.

För ICC-inläsning och senare profilbaserade transformationer finns [Pillow ImageCms](https://pillow.readthedocs.io/en/stable/reference/ImageCms.html), byggt på LittleCMS. Lokalt finns LittleCMS 2.19. Ett läsprov 2026-09-27 öppnade båda användarprofilerna och återgav rätt beskrivning och version (2.1 respektive 4.2). Detta verifierar grundläggande läsning, inte tabellernas numeriska resultat eller full formatöverensstämmelse.

Rekommendationen kompletteras därför: använd ImageCms/LittleCMS för oberoende metadatajämförelse och utvärdera dess API innan mer egen ICC-funktionalitet byggs. En begränsad strukturläsare behövs fortfarande för full taggförteckning, råa intervall och InkProfs diagnostik. Colour hanterar kolorimetrin. MATLAB Base presenterar resultaten.

## Fjärde referensprofilen: matt papper, Canon

Tillagd 2026-09-27: `HFA_CanonGP-2600S_MK_GermanEtching.icc` med medföljande inställningsblad, 05.2024 / Rev. 00. Lokala oförändrade kopior och hash finns under `projects/icc-reference-profiles/canon-gp2600s-german-etching/` tillsammans med `inspection.json` och `reference.json`.

A1 läser profilen utan strukturvarningar: ICC 4.3.0, prtr/RGB/Lab, 18 taggar, mAB/mBA. Beskrivningen stämmer med LittleCMS. Taggarna CxF / ZXML och meta / dict redovisas men avkodas inte av A1. Filens interna beskrivning är `HFA_Canon2600S_MK_GermanEtching.icc`, vilket skiljer sig från filnamnet.

Inställningsbladet anger Canon iPF GP-2600S, Matte Black (MK), mediet Heavyweight Fine Art Paper, kvalitet high och avstängd färghantering i drivrutinen. Rendering intent och svartpunktskompensation väljs efter bilden. Användaren anger matt papper och skriver Canon pro 2660; kompatibilitet med den avsedda skrivaren är därför ännu inte fastställd. Referensen kopplas inte till Epson-mätningens utskriftsrecept.

Profilhuvudets attribut är noll trots att referensen avser matt papper. Detta visar varför pappersegenskaper från ett standardvärde i profilhuvudet inte ensamt bör användas för att välja utskriftsinställningar.
