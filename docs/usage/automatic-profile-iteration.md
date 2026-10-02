# Automatisk profiliteration från mätning

`inkprof.iterateProfile` kopplar ihop validerad inläsning, fryst träningsunderlag,
Argyll-profilering, modelljämförelse, numerisk kontroll och utskrivbara TIFF16-mål.
MATLAB Base styr flödet; Python och Argyll gör färgberäkningarna. Ingen koppling
till Camera-41 eller SpectraLab krävs.

Denna version använder spektrala mätdata och D50/2° med samma valbara FWA/D50-kompensation som projektets profilrecept.
Rutinen tar **mätdata**, inte enbart patchdefinitioner. JSON, TI3 och MXF stöds
via befintlig import. TI3 behöver matchande TI2 (`TargetFile`); en positionerad
MXF använder sin egen layout. Ett mål utan mätningar kan inte ge en ICC.

## Enkel körning

```matlab
cd('/Users/christer/Desktop/InkProf')
setupInkProf();
[iterationFolder, result] = inkprof.iterateProfile();
```

Välj mätfilen. Den ska tillhöra ett InkProf-projekt; för en extern fil anges
`ProjectFolder` uttryckligen. Resultatet är en **ICC-kandidat**, inte ett
automatiskt godkännande av utskriftskvaliteten. Alla resultat får en ny mapp.
Ingen fysisk utskrift skickas till skrivaren.

## Kompletteringsmätning med tidigare träningsdata

```matlab
[iterationFolder, result] = inkprof.iterateProfile(measurementFile, ...
    BaseMeasurement=previousMeasurementFile, RoleFile=roleFile, ...
    Name="Glossy - iteration 2", MaxNewPatches=100, ...
    NormTarget=1, GrayWeight=2);
```

Variablerna ska vara filvägar. `RoleFile` är en JSON med `patches`, där varje
post har `sampleId`, `rgbPercent` och `role`. ID och RGB kontrolleras mot den
inlästa mätningen. `placement-plan.json` upptäcks också automatiskt bredvid,
eller en nivå ovanför, målets ursprungliga sökväg i mätningens `targetInfo`.
Efter flytt kan sökvägen behöva anges explicit.

- `fit` går till träning.
- `adaptive_holdout` och `adaptive_validation` används för modellval och
  kompletteringsförslag. De är därefter utvecklingsdata, inte orörd slutkontroll.
- `control`, `repeat` och `final_holdout` tas inte med i träning eller modellval.
  Deras originalvärden bevaras för separat drift-/slutkontroll.
- En utvecklings-RGB som redan finns i träningen ger fel, så att ett läckande
  kontrollurval inte presenteras som oberoende från träningen.

Vid nästa iteration kan `BaseInputFolder=fullfile(previousIterationFolder,
"training")` användas i stället för `BaseMeasurement`. Då återanvänds den
föregående körningens sammansatta, frysta träningsunderlag. Ange bara ett av
alternativen. Kombination kräver explicit eller upptäckt rollfil.

En sammansatt träningsmapp bevarar källpaketen under `sources/input-N/`.
`measurement.json` och `chart.json` i **denna mapp** är dokument av typen
`inkprof.profile-training-set`, inte en ny fysisk mätning eller ett nytt ark.
Tränings-ID:n får källprefix; mappningen bevarar ursprungligt ID, koordinat och
rad i mätfilen. Filerna används genom B2/B3, inte som mätfiler i ommätningsdialogen.

## Profilval och stopp

Med utvecklingspunkter körs tre separata recept: medium A2B, high A2B och high
A2B med Argylls `-r 0.1`. B2A är high i alla tre. Det sista är ett försök med
lägre antaget mätbrus/utjämning; det är inte ett påstående om instrumentets
verkliga brus. Defaultreceptets `-r` utelämnas helt. Exakta argument sparas.

En kandidat ersätter den hittills valda om den viktade RMS-normen förbättras
minst `MinImprovement` (0,01), ingen kontrollpatch försämras mer än
`MaxPatchRegression` (0,5 dE00), och grågruppens medelfel inte ökar mer än
`MaxGrayRegression` (0,25). Grågruppen definieras här av kanalspann högst två
RGB-procentenheter; även antalet sådana kontrollpunkter loggas. Det är en
prioriteringsregel, inte en garanti för hela gråskalan.

Alla råa utvecklingsfel och regressioner bevaras. Upprepningar grupperas per
RGB i normen; grupper med för stor inbördes avvikelse utesluts. Saknas
utvecklingspunkter byggs en high-kandidat utan automatiskt jämförande modellval.
Träningsfel används inte som ersättning för utvecklingskontroll.

Nästa kompletteringsmål följer den befintliga felstödda mittpunktsmetoden:
fel, lokalt mätstöd, avstånd, gråprioritet och riktad Jacobian-känslighet. Enbart stor Jacobian eller dåligt
konditionstal startar inte förtätning. Jacobianen skattas med ±0,5 RGB-procentenheter (ensidigt vid kubens kant).
En begränsad faktor mellan 1 och 2 prioriterar riktningar med större
framåtförändring. Singulärvärden och konditionstal loggas som diagnostik;
konditionstalet används inte som obegränsad vikt. Krökning och osäkerhet i
derivatskattningen återstår att utveckla. `MaxNewPatches` är ett tak, inte ett krav
att fylla budgeten. `NormTarget` kan stoppa förslag; det betyder inte att
profilen är validerad över hela färgområdet.

## Två olika utskriftspaket

1. `verification/print/`: C2, normalt 128 källpatchar, profilen applicerad en
   gång med absolut kolorimetri och utan BPC. Tillhörande `verification.json`
   innehåller önskade Lab och kopplingen till profilen.
2. `refinement-print/print/`: skapas bara om nya punkter föreslås. Device-RGB
   utan applicerad ICC. Var femte kandidat reserveras för utvecklingskontroll
   när minst tio nya punkter finns. Upp till tio gamla RGB återkommer två
   gånger för drift-/repeterbarhetskontroll. Dessa kontrollförekomster ligger
   utöver taket för **nya** RGB-punkter; alla antal redovisas. Roller och layout
   fryses i `refinement-print/placement-plan.json` före mätning.

Båda har kontrastmarkörer, matchande TI2 och TIFF16 utan inbäddad ICC, A4
liggande som standard. Skriv ut 100 % utan ytterligare färgomvandling. Bevara
papper, skrivare och inställningar från mätunderlaget. Läs respektive pakets
`PRINTING.txt`. Målen kan inte bytas sinsemellan vid mätning eller analys.

## Logg, fel och kvarstående granskning

Mappen `profiles/iterations/<UUID>/` innehåller:

- `iteration.json`: status, parametrar, roller, länkar, källhashar, kandidater,
  beslut, normer, kontroller och nästa steg. Uppdateras efter varje fas.
- `progress.log`: läsbar händelselogg med UTC-tid.
- `progress.jsonl`: motsvarande maskinläsbara händelser.
- `training/`, rollkopia och utskriftspaketen.

Profiljobben har egna `colprof.log`, status, argument och ICC-hashar. Relativa
länkar i iterationen pekar även på dessa jobb inom projektmappen. Bevara hela
projektet för portabilitet. Ett byggfel loggas och stoppar kedjan; redan
sparade artefakter finns kvar. Ctrl+C avbryter; `cancel.request` i iterationsmappen
kontrolleras mellan faser. Med `ShowJobDialog=true` kan ett pågående profiljobb
avbrytas i dess fönster. Ny körning skapar en ny iteration, ingen dold återstart.

Ingen profil installeras eller ersätter originalet. Status
`ready-for-print-review` betyder att kandidaten och testfilerna finns, inte
att utskriftsinställningar, drift, historiska ommätningar eller mätbrus är
slutligt godkända. Samma M-villkor bevisar inte samma skriv-/mätkedja.
Kontrollpunkterna för drift bevaras men automatisk driftspärr återstår.
Intern lösarkonvergens påstås inte när Argyll bara rapporterar lyckad körning.
Färg- och metamerismvalidering kräver fortsatt fysisk mätning.

## Branschtoleranser och egna acceptansgränser

Se [färgavvikelse och toleranser](../research/colour-difference-tolerances.md)
för ISO 12647-2/-7, skillnaden mellan ΔE*ab och ΔE00 samt försiktig visuell
tolkning. `MaxPatchRegression` begränsar ökningen av ett fel mellan kandidater;
det är inte en absolut utskriftstolerans. Viktad RMS är inte detsamma som
aritmetiskt medelfel. De nuvarande parametrarna är InkProfs projektregler,
inte ISO-godkännandegränser.

## Återkoppling från en verifieringsutskrift

C3 ger nu en maskinläsbar diagnostisk prioritering, med konfigurerbara gränser och separata förutsagda/uppmätta fel. `VerificationReport=reportFile` registrerar den i iterationsloggen. Den ändrar inte automatiskt träningsurval eller kandidatval. Se [verifieringsåterkoppling](verification-feedback.md) för anrop, regler och begränsningar.

## Fortsätt efter kompletteringsmätning

[`continueRefinement`](refinement-continuation.md) hittar förälderns låsta träningspaket och målets rollplan, validerar den nya mätningen och anropar profiliterationen med rätt kopplingar.
