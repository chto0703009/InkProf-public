# Felstyrd lokal förtätning

Första implementationen: `inkprof.proposeRefinement` använder en lyckad InkProf-profil och en separat komplett spektral mätning för att föreslå nästa kompletteringsmål. MATLAB Base sköter anrop och granskning; Python/NumPy/SciPy/Colour analyserar fel och geometri. Argyll `profcheck` beräknar framåtprediktioner. Inga mätvärden slås samman och ingen ICC ersätts.

```matlab
[proposal, refinementFolder] = inkprof.proposeRefinement( ...
    jobFolder, measurementFile, ...
    Name="Local refinement", Iteration=1, ...
    MaxNewPatches=24, NormTarget=1, ...
    ErrorThreshold=2, RadiusPercent=10, MinSpacingPercent=1);
```

`jobFolder` och `measurementFile` måste vara redan definierade sökvägar. Dialogen visar rangordnade punkter och norm. `ShowDialog=false` stöds. `ParentIterationId` kan länka till en tidigare proposals `iterationId`. Varje körning sparas separat under jobbets `refinement/`.

## Norm och iteration

Normen är `sqrt(sum(w_i * deltaE00_i^2) / sum(w_i))`, över unika användbara RGB-grupper. Samma RGB upprepat räknas en gång; Lab medelvärdesbildas före felberäkningen. Standardvikten är 1. `GrayWeight` påverkar grupper vars största minus minsta RGB-kanal är högst 2 procentenheter; råa fel bevaras.

- `NormTarget`: önskad RMS-norm. Uppnådd norm stoppar nya kandidatförslag på det analyserade utvecklingsunderlaget, inte globalt profilgodkännande.
- `MaxNewPatches`: högsta antal nya RGB-punkter **i denna iteration**, inte totalt antal i profilen.
- `ErrorThreshold`: lokalt ΔE00 över vilket en observation kan stödja förtätning.
- `RadiusPercent`: grannskapsradie i euklidiska RGB-procentenheter.
- `MinSpacingPercent`: minsta avstånd till tidigare träningspunkter, samtliga inlästa mätpunkter och redan valda förslag.
- `RepeatLimit`: största tillåtna ΔE00 mellan upprepningar av samma RGB, standard 1. Grupper som överskrider gränsen visas för kontroll och ingår inte i normen. Exkluderat antal redovisas.

Normen beräknas före komplettering. Om budgeten nås vet vi inte att normen kommer att uppnås. Ny mätning och profilering behövs för nästa iterations utfall. Ingen uppskattad konvergenshastighet anges.

## Hur förslagen väljs

Högfelspunkter kräver stöd från minst en annan unik användbar högfelspunkt inom radien. Isolerade fel flaggas för granskning. Befintliga tränings-RGB används inte som kompletteringsankare. Redan uppmätta nya färger listas i `reuseObservationIndices`, så att användaren kan överväga att använda dem utan ny utskrift.

Nya kandidater är mittpunkter mellan felankaret och närliggande felobservationer eller träningspunkter. Prioritet:

`max(deltaE00 - threshold, 0) × min(trainingDistance/radius,1) × min(existingDistance/radius,1) × userWeight`

Detta är en dokumenterad heuristik, inte en förutsägelse av förbättring. Kandidater kvantiseras till TIFF16-nivåer, dubbletter tas bort och minsta avstånd tillämpas före budgeten. Algoritmen gäller hela RGB-kuben; inga färgområden är hårdkodade.

## Sparade filer och nästa steg

- `proposal.json`: norm, iterations-ID, gränser, stopporsak, fel, residualer, upprepningsvariation, kandidater, prioritetens komponenter och källhashar. Index i `errorObservationIndices`, `reuseObservationIndices` och `review.index` är **nollbaserade JSON/Python-index**; addera 1 vid MATLAB-indexering.
- `target.ti1`: bara nya föreslagna RGB-punkter. Skapas inte om inga kandidater finns.
- `sources/`: kopior av profil, ursprunglig tränings-TI3, recept samt kontrollmätningens JSON och TI3.
- `request.json` och `profcheck.log`: körningsunderlag och logg. Ursprungliga körningssökvägar är historik; källkopiorna följer paketet.

Öppna `target.ti1` i InkProfs TIFF16-rendering. Där skapas fysisk layout och TI2. TI1-filen är ett förslag och användaren granskar punkter och utskriftsrecept före utskrift. Befintliga råmätningar ändras aldrig.

## Giltighet och kvarstående begränsningar

Första versionen stöder endast spektral D50/2°-framåtjämförelse med samma valbara FWA/D50-kompensation som profilreceptet, samma kända M-villkor och kända device-RGB. Profil, recept, tränings-TI3 och mät-TI3 kontrolleras med hash. Invers-/gamutfel från önskat Lab får inte användas som framåtmodellfel här.

Vald mätning deklareras uttryckligen som `adaptive_validation` i API-kontraktet. Ett låst slutmål får inte skickas till funktionen. Rollen kan inte avgöras automatiskt från en äldre mätfil; anroparen ansvarar för detta. Kontroll av skrivare, papper, drivrutinsinställningar, kalibreringsstandard och drift kräver fortfarande granskning. Samma M-villkor räcker inte för att bevisa identiska mätkedjor. Ingen automatisk sammanslagning görs.

Ingen ny låst slutkontroll genereras från de felstyrda kandidaterna: det vore inte oberoende. Sådan kontroll måste hållas separat. Ny mätning/profilrevision och konvergenshistorik över flera iterationer återstår att integrera.

## Sammanhållen iteration och Jacobian (2026-09-29)

Se [automatisk profiliteration](automatic-profile-iteration.md) för den nu
implementerade kedjan med rollstyrd sammanslagning, receptval och utskrifter.
Den ersätter det tidigare behovet att koppla ihop samtliga steg manuellt.

`DevelopmentSampleIds` begränsar vilka ID:n som får styra analysen.
`UseJacobian=true` gör extra framåtuppslag i absolut kolorimetri med `xicclu`.
Jacobianen skattas vid ±0,5 RGB-procentenheter, ensidigt vid kubens gräns.
För kandidatens förskjutning från felankaret beräknas `norm(J * displacement)`.
Den äldre prioriteten multipliceras med
`1 + min(norm(J * displacement) / (radius * median(sigma_max)), 1)`.
Medianen får ett numeriskt golv på 1e-10. Faktorn ligger alltså mellan 1 och 2;
inget ensamt konditionstal kan dominera budgeten. Värdena är Lab-känslighet,
inte ett exakt dE00-mått eller en skattad förbättring efter omprofilering.

`localSensitivity` i observationerna innehåller Jacobian, singulärvärden,
konditionstal (null vid numeriskt nära singularitet) och differenssteg.
`evaluatedPatches` bevarar individuella kontrollfel för jämförelse av recept.
Befintliga anrop utan `UseJacobian` behåller den äldre viktningen.

## Alternative: colours from an image

Step 15 also offers **From image** for general image-guided sampling, independently of current C3 feedback. See [Image-guided refinement](image-guided-refinement.md) for embedded ICC handling, the missing-profile sRGB warning, editable patch selection and the shared continuation workflow.
