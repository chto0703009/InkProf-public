# Verifieringsanalys som återkoppling till iterationen

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

`inkprof.analyseVerification` analyserar ett sparat C3 `verification-check.json`. Beräkningarna sker i Python; MATLAB Base ger anropet. Från och med denna ändring skapar även nya C3-körningar automatiskt `iteration-feedback.json`, `.md` och `feedback.log` med standardparametrar, tillsammans med C3-rapporten.

```matlab
[feedback, feedbackFile] = inkprof.analyseVerification(reportFile, ...
    MeanLimit=2.5, PatchLimit=5, GrayLimit=2, ...
    ModelTolerance=1, RepeatLimit=1, GrayWeight=2, ...
    MaxPriorityPatches=20);
```

Utan filargument visas en filväljare. Parametrarna anges i anropet; någon parameterdialog finns ännu inte. Varje explicit analys sparas i en ny `feedback/<UUID>` under C3-kontrollen, inklusive källrapportens SHA-256 och använda parametrar. Originalmätningen ändras inte.

## Tre avstånd, tre frågor

- Förutsagt fel: ΔE00 mellan önskat Lab och profilens Lab vid utskrivet RGB.
- Uppmätt fel: ΔE00 mellan önskat och uppmätt Lab.
- Modellavvikelse: ΔE00 mellan profilens Lab och uppmätt Lab.

Alla tre beräknas direkt från Lab; avstånden subtraheras inte. Modellen kan korrekt förutsäga ett stort fel mot en svår målfärg. Om modellen däremot lovar rätt färg och mätningen avviker behöver framåtmodellen eller utskriftsförhållandena undersökas.

## Diagnostiska regler

Gränserna är konfigurerbara. Medel 2,5 och max 5 är jämförelseriktvärden från provtryckskontroll; de ger inte ISO-godkännande av ett eget RGB-mål. GrayLimit och ModelTolerance är InkProf-val, inte ISO-krav. Se [färgtoleranser](../research/colour-difference-tolerances.md).

Patchar med modellavvikelse över ModelTolerance markeras `model-or-print-chain-mismatch`. Om modellavvikelsen ligger inom denna nivå men uppmätt fel över patchgränsen markeras `predicted-limitation`; detta bevisar inte fysisk gamutgräns. Övriga markeras `within-diagnostic-limits`.

Prioritet = max(modellavvikelse − ModelTolerance, 0), gånger GrayWeight för grå och gånger två när uppmätt fel överstiger patchgränsen. Detta är en transparent heuristik, inte en prognos för vinst eller en statistisk signifikansbedömning. MaxPriorityPatches begränsar antalet rapporterade prioriterade källpatchar; det är inte antalet nya RGB-prov.

Upprepningar redovisas separat och får inte dubbel vikt i urval eller huvudstatistik. Överskriden RepeatLimit ger rekommendation att granska repeterbarheten före anpassning. Saknade upprepningar rapporteras som `unavailable`. Tryckta upprepningar innehåller både positions- och mätvariation; de utgör inget isolerat instrumentbrusmått.

## Koppling till iterationsloggen

```matlab
[iterationFolder, result] = inkprof.iterateProfile(measurementFile, ...
    VerificationReport=reportFile);
```

Detta sparar en länk, hash och prioriteringar i iterationen samt ett `verification-feedback`-steg i loggen. Befintliga BaseMeasurement/RoleFile och övriga parametrar måste fortfarande anges när de behövs. Återkopplingen ändrar ännu inte automatiskt träningsurval, kandidatval eller placeringen av nya punkter. För målproduktion används det separata anropet `refineVerification` nedan, med källpatcharnas utskrivna RGB. Granskning krävs, särskilt när repeterbarheten är dålig.

Om C2 används för urval eller anpassning blir det utvecklingsdata. Slutlig verifiering behöver ett nytt oberoende mål. En kandidat måste utvärderas vid samma utskrivna RGB för att kunna jämföras med den befintliga mätningen; en ny invers ger andra RGB och kräver senare utskrift för fysisk kontroll.

## Testfall från 2026-09-29

116 unika patchar och 12 upprepningar. K3 och F5 har stora modellavvikelser och prioriteras. S1/Q1 har stora men huvudsakligen förutsedda fel. Resultatet ska aldrig sätta `qualityApproved=true` eller intyga ISO-överensstämmelse.

## Genomförd koppling: Jacobian och nästa mål

`inkprof.refineVerification` använder nu C3-rapporten för att föreslå nya RGB-prov. MATLAB Base gör SVD, regularisering, rangordning och urval. Python kontrollerar källhashar/identiteter och anropar Argyll `xicclu` för absolut D50-Lab och derivator.

```matlab
[proposal, folder] = inkprof.refineVerification(reportFile, ...
    Name="Iteration 3 - C3 refinement", ...
    MaxNewPatches=100, NormTarget=1, ErrorThreshold=1, ...
    RadiusPercent=5, MinSpacingPercent=1, GrayWeight=2, ...
    CreatePrint=true);
```

Utan filargument väljs `verification-check.json` i en dialog. Inställningarna anges som MATLAB-parametrar. Resultatfönstret visar vilka ursprungspatchar och riktningar som motiverade respektive förslag.

Residualen är `uppmätt Lab − modell-Lab`. Jacobianen gäller Lab per RGB-procentenhet. För `J=U*S*V'` beräknas en regulariserad riktning `−V*diag(s/(s²+lambda²))*U'*residual`, där lambda är minst `RegularizationFraction` gånger största singularvärdet. Den används endast som samplingsriktning på båda sidor, inte som en färdig RGB-korrigering. Tre högra singularvektorer ger ytterligare provriktningar.

Prover skapas vid halv och hel radie. Radien kortas längs strålen vid RGB-kubens gräns; ingen koordinatvis klippning som förvränger riktningen används. Kandidater kvantiseras till RGB16 före kontroll av avstånd till träningsdata, redan mätta punkter och andra kandidater. MinSpacingPercent är euklidiskt RGB-avstånd i procentenheter. MaxNewPatches är övre gräns för nya unika RGB. Gråvikt avgörs från målets gråroll, inte lika device-RGB, eftersom neutral utskrift kan kräva olika kanalvärden.

Urvalspoängen kombinerar överskjutande modellfel, gråvikt, samplingsriktningens Lab-svar i relation till residualen och avstånd till befintliga prov. Konditionstalet förstärker inte poängen obegränsat. Derivator jämförs med stegen h och h/2; grupper över MaxJacobianChange (standard 0,5 relativ Frobeniusnorm) stoppas för granskning. Standard h är 0,5 RGB-procentenheter. Upprepade RGB räknas en gång; oeniga upprepningar över RepeatLimit stoppas. Stopvillkor är uppnådd viktad RMS-norm, kandidatbudget eller slut på tillåtna kandidater. Gränserna är diagnostiska val, inte ISO-gränser.

Förslag sparas i en ny `refinement/<UUID>` under C3-kontrollen, med `proposal.json`, `target.ti1` när punkter finns, `progress.log` och källkopior. `CreatePrint=true` skapar därutöver `refinement-print/print/target.tif`, matchande TI2 och en fryst rollplan med utvecklingsprov och upprepade kontroller. Kontroller tillkommer utöver budgeten för nya RGB. Detta är ett nytt karakteriseringsmål **utan applicerad ICC**, till skillnad från C2. Skriv ut vid 100 procent med samma inställningar och utan färgkonvertering.

Ingen profil ändras och inga mätningar slås ihop automatiskt. Jämför utskriftsförhållandena före användning. C2 som styr förtätningen är utvecklingsdata; en senare verifiering behöver vara oberoende. `iterateProfile(...,VerificationReport=...)` registrerar fortfarande endast diagnostiken; kör `refineVerification` explicit för denna målproduktion.

### Öppna ett sparat förslag igen

`inkprof.showRefinementProposal(folder)` visar tabellen från `proposal.json` utan att generera nya patchar eller TIFF-filer. Utan argument väljs mappen i en dialog. Textceller konverteras till `char` för kompatibilitet med MATLABs `uitable`.

Efter mätning av kompletteringsmålet kan hela kopplingen till ny profil och nytt C2 utföras med [`continueRefinement`](refinement-continuation.md).
