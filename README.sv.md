# InkProf v1.2.2 — Buggrättningar för RGB-target

> **Nytt i v1.2.2:** automatisk ICC v4-kompatibilitetskopia för preconditioning, aktivitet med förfluten tid och rättad sparning av TI1/JSON. PDF-handböckerna är fortsatt v1.2.1; se releaseinformationen för dessa rättningar.

**Behåll din i1Pro 2. Ta kontroll över utskriften.**

Ta reda på vad din skrivare, ditt papper och ditt bläck kan återge. Skapa en profil, kontrollera resultatet och ge kunden ett mätt underlag för det du levererar.

InkProf är en MATLAB-app med öppen källkod för profilering och verifiering av RGB-skrivare. Den kommunicerar med i1Pro 2 via ArgyllCMS, oberoende av i1Profiler. Arbetsflödet är testat med i1Pro 2 på macOS.

<img src="docs/usage/handbook-source/examples/measurement-instrument.jpg" alt="Spektrofotometer placerad över ett utskrivet RGB-färgmål" width="640">

*Spektralmätning av ett utskrivet mål: grunden för profilering och verifiering.*

## Vad får du ut av InkProf?

- **Fortsätt använda instrumentet du redan äger.** ArgyllCMS sköter instrumentkommunikationen, så att arbetsflödet är oberoende av i1Profiler.
- **Fatta tryggare beslut om bild och papper.** En ICC-profil beskriver din utskriftskombination och ger underlag för soft proofing. En separat utskrift och mätning kontrollerar det fysiska resultatet.
- **Minska onödiga provutskrifter.** Sparade inställningar, mätningar och revisioner hjälper dig att upprepa ett fungerande arbete och undersöka förändringar. Det kan spara tid, papper och bläck.
- **Gör kvaliteten begriplig för kunden.** Certifikatet visar referensfärger, mätningar, omfattning och granskarens beslut. Den separata mätbilagan bevarar det fullständiga underlaget.

Projektet håller ihop underlag, profiler, kontroller och historik. Du kan stänga det medan utskriften torkar och fortsätta senare. RGB-skrivare tar emot RGB-data via drivrutinen; de flesta fotoskrivare med bläckstråle använder detta flöde. InkProf sparar TIFF16 för separat utskrift och sköter mätningen i appen.

## Nytt i 1.2.2

Tvåspråkiga PDF-certifikat, ett fullständigt engelskt mätsupplement, valfri lokal 3D-visning och tydligare färgjämförelse. Båda PDF-certifikaten och supplementet ligger direkt i leveransmappen. Se [releaseinformation](docs/releases/v1.2.2.md).

## Nytt i 1.1.1

- Spara hela mätrader och återuppta med besked om sida, rad och riktning.
- Bekräfta samma utskrivna ark; återanvänd godkända RGB-kontroller för samma utskrift.
- Större RGB-rutor och enklare skapande av verifieringsmål.
- Uppdaterade handböcker; instrumentprov av återupptagning återstår.

### Skal-refinement från 1.1.0

**Skalförfining** lägger till mätpunkter nära gamutytan, över hela skalet eller i valda områden. Du granskar förslaget före utskrift. Bildfärger, kontrollfel, markerade områden och prov av tätare ICC-rutnät finns bland samma förfiningsverktyg. Appen föreslår nästa giltiga rad i arbetsgången.

## Tillgänglighet och krav

InkProf är **kostnadsfritt att ladda ner**, enligt GPL version 3 eller senare. **MATLAB kräver licens**; grundversionen räcker. Python, ArgyllCMS och en kompatibel spektrofotometer installeras separat. Det fullständiga arbetsflödet är testat på **macOS med i1Pro 2**; Windows/Linux och alla instrumentlägen är inte kvalificerade.

[Hämta stabil källkod v1.2.2](https://github.com/chto0703009/InkProf-public/releases/tag/v1.2.2) · [English overview](README.md) · [Svensk nyttopresentation](docs/usage/InkProf-presentation-svenska.pdf) · [Svensk användarhandbok](docs/usage/InkProf-anvandarhandbok-svenska.pdf)

Källkodsreleasen publicerades **2026-10-22**. Handböcker, presentationer och MATLAB-guide är uppdaterade för denna release.

## Läs vidare

- [Installationsanvisning](README.md#install-and-start)
- [Engelsk handbok](docs/usage/InkProf-user-handbook-English.pdf)
- [Engelsk presentation](docs/usage/InkProf-presentation-English.pdf)
- [Releaseinformation](docs/releases/v1.2.2.md)
- [Validering](VALIDATION.txt)

Färgnoggrannheten beror på skrivare, papper, bläck och inställningar. Numeriska kontroller och skärmförhandsvisningar ersätter inte fysisk verifiering. Certifikatet dokumenterar underlag och beslut; det är inte ackrediterad certifiering eller intyg om full ISO-överensstämmelse.

Överlämna hela leveransmappen så att HTML-filens underlag, bilder och mätbilaga följer med. Privata projekt, profiler, mätfiler och externa program ingår inte i releasen.

InkProf tillhandahålls utan garanti enligt GPL. Se [LICENSE](LICENSE), [licensomfattning](LICENSE_SCOPE.md) och [tredjepartsnotiser](THIRD_PARTY_NOTICES.md).

Valfri CGATS-leverans till i1Profiler väljs med en kryssruta vid steg 14/19. Se [exportinstruktioner, mätkrav och verifierat importtest](docs/usage/i1profiler-cgats-test.md).

Teknisk implementation: [Svensk beskrivning](docs/TECHNICAL_DESCRIPTION_SV.md) · [Svensk PDF](docs/usage/InkProf_Teknisk_beskrivning_SV.pdf) · [Engelsk PDF](docs/usage/InkProf_Technical_Description_EN.pdf). Med appendix om filer och beroenden, uppdaterad för v1.2.2.
