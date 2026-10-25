# InkProf - Teknisk beskrivning

Christer Törnkvist

christer@borgasundsfotografiska.se

https://github.com/chto0703009/InkProf-public

Version 1.4.1 | 2026-10-25 | GPL-3.0-or-later

Implementation, beräkningskedja och datakontrakt

Beskrivningen gäller version 1.4.1, släppt 2026-10-25. Den följer data från definition av färgmål via mätning, ICC-bygge och numeriska kontroller till uppmätt verifieringsutskrift och leverans. Handboken beskriver användarens knapptryckningar; detta dokument förklarar vad stegen innebär och vilka filer de behöver.

Äldre gränssnittsbilder anges uttryckligen som dokumentationsexempel. De visar fiktiva projekt och är inte mätresultat som bevisar utskriftskvalitet. Sökvägar i appendix är relativa till installationens eller projektets rot. Genererade UUID och mappnamn varierar.


| Läsordning / sida | Innehåll |
| --- | --- |
| 2 | 1. Arkitektur och avgränsning |
| 3 | 2. RGB-definition och utskriftslayout |
| 4 | 3. Mätning och färgberäkningsvillkor |
| 5 | 4. B1-B3: från accepterad mätning till ICC |
| 6 | 5. Vad de numeriska kontrollerna visar |
| 7 | 6. C2/C3: fysisk verifiering |
| 8 | 7. Förfining och följande iterationer |
| 9 | 8. Projektstatus, integritet och leverans |
| 10 | Bilaga A. Installation, beroenden och licens |
| 11 | Bilaga B. Filer: vad behövs och var finns det? |
| 12 | Bilaga C. Avstämning och kodreferenser |
| 13 | Bilaga D. Målidentitet och spårbara utskriftskopior |
| 14 | Bilaga E. Återkoppling och verifierad ICC i leveransen |
| 15 | Bilaga F. Granskning, låsning och rättelser |
| 16 | Bilaga G. Mätning, avbrott och leverans |
| 17 | Bilaga H. Gamutgräns och utökat utskriftsmål |
| 18 | Bilaga I. Uppmätt Lab-täthet och separat kandidat |
| 19 | Bilaga J. Aktivitet, spårbarhet och körmiljö |
---PAGE---
## 1. Arkitektur och avgränsning

InkProf samordnar profilering av en RGB-skrivare med bestämt papper, bläck och utskriftsinställningar. Appen profilerar inte digitala kameror och styr inte en analogkamera. Ett utskrivet RGB-färgmål är något annat än en fotograferad ColorChecker. InkProf stöder valbara uppsättningar av skrivarpatchar utan begränsning till en viss fotograferad ColorChecker-modell.

MATLAB hanterar app, projektstatus, geometri, dialoger och samordning. Externa Python-processer används för mätbrygga, spektral och numerisk analys, ICC-inspektion och rapporter. ArgyllCMS tillhandahåller verktyg för färgmål, layout, instrumentkommunikation, profilbygge och färguppslag. LittleCMS används via stödda Python/Pillow-vägar för ytterligare ICC-behandling och kontroller. InkProf är inte en egen ersättningsmotor för ICC-anpassning.

[FLOW]

Projektinställningarna beskriver utskriftsförhållandena. Målfilen beskriver RGB-värden och roller. Layouten kopplar identiteterna till utskrivna positioner. Mätrevisionerna knyter avläsningarna till samma identiteter. Ett låst indatapaket och ett recept binder profilbygget till granskade data. Senare kontroller och verifiering knyts till den valda ICC-filen och dess indatahashar.

Huvudflödet har 19 rader. Rad 1-4 förbereder och accepterar mätningar; B1-B3 låser indata, sparar recept och bygger profil; rad 8 kontrollerar resultatet. C2/C3 skapar och mäter en verifieringsutskrift. Återkoppling, godkännande för avsedd användning och leverans följer. Rad 15-19 hanterar förfining, följande iterationer, profiljämförelse och en separat leveransväg med enbart numeriskt underlag.

Kodreferenser: `src/+inkprof/app.m`, `ProjectWorkflow.m`, `+internal/executeWorkflowStep.m`, `bridge/`, `profiles/`, `analysis/`.
---PAGE---
## 2. RGB-definition och utskriftslayout

Måldesignen arbetar i normaliserad enhets-RGB med tre värden per patch. Mesh-metoden börjar med ett rutnät i RGB-kuben och eventuella extra unika värden på gråaxeln. Delaunay-tetraedrar ger inre kandidater. Redigerarens standard är tyngdpunkter; API stöder också omskrivna sfärers centrum och centrum inuti respektive tetraeder, tillsammans med tyngdpunktskandidater. Kandidater utanför den öppna kuben, dubbletter och nollavstånd tas bort.

Kandidatens poäng är det euklidiska avståndet till närmaste befintliga träningspunkt: d(p) = min ||p - RGB_i||. Högst rankad kandidat läggs till och trianguleringen byggs om. Detta mäter geometrisk täckning, inte uppmätt färgfel, och är ingen fysikalisk FEM-modell. En äldre variant som förfinar kanter finns kvar i API.

Det totala patchantalet omfattar träningspunkter, separata kontrollpunkter och upprepningar. Kontrollpunkterna kommer från en deterministisk radical-inverse-sekvens; upprepningar refererar till befintliga träningspunkter. Roller sparas som `fit`, `control` och `repeat`. RGB på gråaxeln bevisar inte att utskriften blir neutral. Täckningskontrollen använder ett fast rutnät med 33 x 33 x 33 provpunkter och skiljer yta från inre; den bevisar inte största luckan i hela den kontinuerliga kuben.

Argyll-alternativen använder targen och kan använda en befintlig RGB-skrivarprofil för perceptuell placering. ICC v4 får automatiskt en separat approximativ v2-kompatibilitetskopia. Original och konverteringsunderlag bevaras. Cachen identifieras av originalets hash. Rekonstruktionen använder ett relativt framåt-rutnät med 17 punkter per axel och invers Bradford-anpassning av medievitt. Inverstabeller och perceptuell avbildning byggs om. Detta är en approximation, inte ett byte av versionsmarkering.

Definitionen sparas som TI1 och JSON utan utskriftslayout. Renderingen skapar därefter TIFF16, TI2 och motsvarande layoutdata. Ideala flyttalsvärden och kvantiserade RGB16 är separata uppgifter. Fönsterreferenser och callbacks sparas inte i JSON.



Kodreferenser: `designRGBTarget.m`, `createTarget.m`, `+internal/drawPrintControls.m`, `analysis/gamut_refinement.py`.
---PAGE---
## 3. Mätning och färgberäkningsvillkor

Motsvarande TI2/layout behövs: en mätning är mer än en lista med Lab-värden. Patch-ID, position, RGB-kommandon, fullständighet och tillgängliga spektra/XYZ måste behålla kopplingen till utskriften. Instrumentfrågor, kalibrering och remsans riktning hanteras av mätflödet och Argyll-bryggan. Importerad CGATS/TI3 eller stödd MXF kräver motsvarande identitets- och layoutunderlag.

![Mätgränssnitt](docs/usage/handbook-source/examples/measurement-window.png)

Figur 1. Gränssnittsexempel för dokumentation från 2026-10-09, före instrumentstart. Bilden visar ingen genomförd mätning. Gränssnittets texter kan skilja sig från version 1.4.1.

En ommätning blir först en kandidat och sedan en accepterad revision. Registrerade avläsningar får inte ersättas i det tysta. Parvisa skanningar, upprepningar och punktkorrektioner svarar på olika frågor. Repeterbarhetsmått gäller de faktiskt genomförda upprepningarna och beskriver inte all osäkerhet i skrivare, instrument och miljö.

Mätvillkor ska anges, inte gissas från filändelsen. Spektrala indata integreras under stödda valda villkor. Nuvarande profileringsprocess (Python-arbetaren) kräver D50 och CIE 1931:s 2-gradersobservatör för den spektrala vägen. Lagrade XYZ är en separat väg som beror på de ursprungliga beräkningsvillkoren.

FWA/OBA-kompensation kräver ursprungliga M0-färgspektra, känt kompatibelt instrument utan UV-filter, våglängdstäckning från högst 400 nm till minst 700 nm samt lämplig uppmätt pappersvitreferens. Instrument och våglängder för vitreferensen måste stämma. M1, M2, okända eller redan kompenserade data kan inte behandlas som ursprungliga M0. Mätning av blankt papper kan inte ersätta saknade färgspektra. Simulerad FWA-kompensation till D50 är ingen fysisk M1-mätning.

Kodreferenser: `startMeasurement.m`, `MeasurementDialog.m`, `importMeasurement.m`, `prepareProfileInput.m`, `createProfileRecipe.m`.
---PAGE---
## 4. B1-B3: från accepterad mätning till ICC

B1 kontrollerar de faktiska mätfilerna, överensstämmelse mellan JSON och TI3, kartläggning av patchar och fullständighet. Ett nytt låst paket skapas med mät-JSON, chart-JSON, ursprunglig TI3, profilerings-TI3 och `profile-input.json`. Hashar knyter paketet till underlaget. Att öppna en dialog innebär inte att något accepterats.

B2 sparar ett uttryckligt recept men bygger ingen profil. Det anger färgdataväg, kvalitet för utmatningstabeller, utjämning, perceptuella inställningar och relevanta utskriftsuppgifter. Projektinställningarna kan ge värden, men det sparade receptet styr bygget. FWA kontrolleras innan receptet kan användas. Den borttagna axiella/Hessian-baserade InkProf-regulariseringen av rutnät avvisas av nuvarande jobbkörning; den är inte ett aktivt profileringsval.

![Receptgränssnitt](docs/usage/handbook-source/examples/profiling-recipe.png)

Figur 2. Fiktivt receptexempel från 2026-10-09 som avbröts utan profilbygge. Receptet beskriver inställningar, inte uppmätt kvalitet.

B3 verifierar receptets och hasharna för indata, kopierar nödvändigt underlag till arbetsytan och startar Python-arbetaren och Argyll colprof. Spektrala indata och lagrade XYZ förbereds på uttryckligt skilda sätt. Vid FWA görs integration och kompensation en gång före anpassningen och underlaget bevaras. `engine.ti3` visar vilka data som faktiskt gavs till motorn.

Jobbet sparar status, argument, loggar och resultatets identitet. Lyckat, misslyckat och avbrutet är olika utfall. Om arbetaren slutar utan giltigt slutbesked behandlas det som fel. En tidigare fungerande ICC får inte framställas som resultatet av ett misslyckat nytt bygge. Tidsgränser och avbrytning är driftskydd, inte kriterier för färgkvalitet.

Kodreferenser: `prepareProfileInput.m`, `createProfileRecipe.m`, `runProfileJob.m`, `profiles/profile_job.py`.
---PAGE---
## 5. Vad de numeriska kontrollerna visar

Träningsanpassning, numerisk transformkonsistens och oberoende utskriftsnoggrannhet är skilda prov. Litet träningsfel bevisar inte korrekthet för omätta RGB-värden. Numeriska framåt-/bakåt-fel påverkas av gamutgränser, flertydig inversion, återgivningsmetod och provpunkter. De ersätter inte en uppmätt utskrift.

| Kontroll | Indata och jämförelse | Tolkning |
| --- | --- | --- |
| Fit | ICC-framåtprediktion mot träningspatcharnas Lab | Anpassning till använda byggdata; Delta E00 per patch |
| Grid | Samplade ICC-transformer framåt och bakåt | Numeriska rutnätsdiagnoser för undersökta provpunkter |
| C1 | Flyttals-CMM, lokala inversa grannskap och skadade kontrollprofiler | Diagnostisk konsistens och detektion av grova fel |
| C3 | Uppmätt verifieringsutskrift mot önskad färg och modellprediktion | Fysiskt utskriftsresultat under dokumenterade villkor |
| ICC-jämförelse | Föregående och aktuell profil vid gemensamma provpunkter | Modellförändring; bevisar inte vilken som är mest korrekt |

Fit-rapporten behåller patchidentiteter, predikterat och uppmätt Lab, absolut kolorimetriskt sammanhang och sammanfattande statistik. Filter för exempelvis RGB-grått, mörkt, hög kulörthet eller kubgräns hjälper granskningen men ändrar inte mätningarna.

C1 använder också avsiktligt skadade profiler som negativa kontroller. Att upptäcka dem ger stöd åt diagnostiken, men bevisar inte att alla möjliga ICC-fel upptäcks. Mätbrusets fortplantning genom en ny anpassning är ännu inte fullständigt kvantifierad.

Rapporter skapas i nya diagnostikmappar och registreras i projektet. Ny kontroll gäller vald ICC och indata; den får inte tyst skriva om ett tidigare levererat certifikat. Operatören/granskaren tolkar resultatet utifrån avsedda utskriftsförhållanden.

Kodreferenser: `checkProfileFit.m`, `checkProfileGrid.m`, `checkProfileC1.m`, `analysis/profile_fit.py`, `analysis/profile_c1.py`.
---PAGE---
## 6. C2/C3: fysisk verifiering

C2 skapar ett verifieringsmål för ett lyckat ICC-jobb eller en stödd importerad profil. Önskade absoluta D50-Lab-värden transformeras till enhets-RGB och kvantiseras för TIFF16. Referenspaketet bevarar önskad färg, faktiska RGB-värden, patchidentiteter, ICC-hash och transformvillkor. Nuvarande C3-väg kräver absolut kolorimetrisk återgivning utan svartpunktskompensation.

Det genererade målet kan innehålla färg-, grå-, utmanings- och upprepningspatchar. En stödd extern referens är ett uttryckligt alternativ. Standardantal och slumpfrön sparas; de är inte universellt optimala urval. När träningsdata finns används en regel om minsta RGB-avstånd i det genererade urvalet. Det är en bestämd uteslutningsregel, inte bevis för statistiskt oberoende i alla avseenden.

Skriv ut C2-TIFF via den dokumenterade vägen utan oavsiktlig ytterligare färgkonvertering. Ange skrivare, drivrutin, media, papper och torkning. Efter mätning kontrollerar C3 unika identiteter, förväntade positioner/RGB, fullständighet och referenskoppling. En snarlik TI3 från ett annat mål är inte utbytbar.

Två användbara felvektorer särredovisas: uppmätt Lab minus önskat Lab samt uppmätt Lab minus ICC-prediktionen för faktiskt utskriven RGB. Delta E00 sammanfattar färgskillnad; komponentfelen i L*, a* och b* behåller riktningen. Antal, medel, median, percentiler och maximum gäller de undersökta patcharna.

Stort fel mot önskad färg men liten modell-till-utskrift-residual kan vara förenligt med begränsad gamut, men visar inte ensamt orsaken. Repeterbarhet och dokumenterade utskriftsvillkor måste också granskas. C3-återkopplingen prioriterar residualer för fortsatt arbete. Gränser i `analyseVerification` är ändringsbara diagnostiska regler, inte ISO-certifiering eller automatisk profilacceptans.

Kodreferenser: `createVerificationTarget.m`, `checkVerificationTarget.m`, `analyseVerification.m`, `analysis/verification_check.py`, `analysis/verification_feedback.py`.
---PAGE---
## 7. Förfining och följande iterationer

Förfining föreslår ytterligare RGB-prover från bildfärger, tidigare verifiering eller andra stödda urval. Bildens inbäddade ICC används när den finns. Ett reservantagande när profil saknas måste redovisas. Predikterat fel vid urval är en uppskattning, inte en instrumentavläsning.

Varje iteration behåller roller och källidentiteter. Prover som används som träningsdata för nästa ICC är inte längre oberoende test av den profilen. Upprepningar och kontrollpatchar behåller sina roller. Rätt layout och definition måste följa med eftersom en allmän TI3 inte innehåller hela arbetsflödets policy.

Den inställbara skuggstrategin för matt papper kan förstärka mörkt urval och Argyll-rutnät. Projektets nuvarande standardvärden omfattar patchbetoning 2, rutnätsbetoning 1,3 och högst 48 extra mörka träningspatchar per iteration. Detta är InkProf-inställningar, inte en officiell matt-förinställning i Argyll eller bevis för förbättring på varje matt papper. Målfiler och faktiskt antal sparas. Gamla mål ändras inte när standardvärden ändras.

Nya förfiningsmål reserverar ungefär en tredjedel av skuggbudgeten för neutrala patchar och en tredjedel för svagt färgade skuggor (beräknat C*ab högst 10). Återstående platser täcker andra mörka färger. Med 48 tillgängliga patchar blir det normalt 16 per grupp. Täta grå RGB-prover och små kanalavvikelser kompletterar Argyll-urvalet. Oanvänd kvot återgår till mörkerurvalet. Befintliga RGB16-färger utesluts. Urvalsregler och källprofilens hash sparas. Det nya målpaketet innehåller enhets-RGB utan ICC-konvertering; dess TI2 binder kommande mätning till nästa iteration. ICC-profilen används bara för urvalets prognos och appliceras inte på utskriften. Originalmål och profiler bevaras. En ny fysisk verifieringsutskrift krävs för att bedöma kandidaten; fler patchar garanterar inte mörkare fysiskt svart.

Nästa profilbygge använder det godkända träningsunderlaget och skapar en ny kandidat. Jämförelse av föregående och aktuell ICC på gemensamma provpunkter visar numerisk förändring. Gör aktuella kontroller och helst en ny fysisk verifieringsutskrift för att bedöma förbättring. Två jämförda modellytor ger inte ny uppmätt utskriftsnoggrannhet.

Leveransvägen med enbart numeriskt underlag för en senare iteration skiljs från utskriftsverifierad leverans. Den beskriver tillgängliga beräkningsresultat och begränsad omfattning. Den skapar ingen saknad verifiering och innebär inte att en äldre utskrift verifierar en ändrad ICC.

Kodreferenser: `proposeRefinement.m`, `continueRefinement.m`, `iterateProfile.m`, `refineVerification.m`, `analysis/shadow_patches.py`, `+internal/createRefinementPrint.m`. Faktisk väg dokumenteras i projektunderlaget.
---PAGE---
## 8. Projektstatus, integritet och leverans

`inkprof-project.json` innehåller projektidentitet, utskriftsinställningar, filregister och historik. `workflow.json` innehåller arbetsstatus och artefaktlänkar. Projektinställningar är inte datorns körmiljö: lokala Python-/Argyll-sökvägar blir inte portabla data om skrivaren.

Ready betyder att nödvändig indata finns. Complete betyder att radens resultat eller beslut sparats. Locked anger att förutsättningar saknas. Stale anger att ett beroende ändrats och tidigare resultat behöver uppdateras. Ingen av dessa etiketter innebär ensam att utskriften klarar önskad noggrannhet.

SHA-256 identifierar exakta filinnehåll och kan upptäcka utbyte eller oavsiktlig ändring. Hashar visar inte om instrumentet placerades rätt, om utskriftsinställningarna stämde med verkligheten eller om mätningen var vetenskapligt lämplig. Okända fysiska uppgifter måste förbli okända. En ny revision ska bevara tidigare underlag och inte tyst räkna om hashar för orelaterade ändrade filer.

Leverans skapar en uttrycklig ICC-kopia och dokumenterar originalets och kopians hashar. Interaktiv namngivning kan uppdatera ICC-profilens interna beskrivning; leveranskopian kan därför legitimt skilja från byggkandidaten. Stödda val av v2/v4.4 och konverteringsunderlag ska vara synliga. Profilbygge och formatkonvertering är olika operationer.

Certifikat och supplement anger mätvillkor, vald profil och godkännandets omfattning. HTML-leveranser kan behöva stödfiler; flytta hela paketet. Registrerade rapporter får inte genereras om på plats: gör en ny arbetsflödesexport. Ett certifikat dokumenterar sparat underlag och operatörsbeslut, inte ackreditering eller automatiskt uppfyllda standardkrav.

Långa beräkningar visar aktivitet, arbetsfas och förfluten tid. Filval och användarbeslut är något annat än beräkning. Måldesignen skapar automatiskt separat v2-kompatibilitetskopia när den behövs; andra importvägar kan fortfarande begära bekräftelse.



Kodreferenser: `ProjectWorkflow.m`, `updateProject.m`, `verifyProject.m`, `+internal/writeWorkflowFinalReport.m`.
---PAGE---
## Bilaga A. Installation, beroenden och licens

| Komponent | Funktion och krav |
| --- | --- |
| MATLAB | App, geometri och samordning. Base MATLAB R2025b testad på macOS; innebär inte verifiering av Windows/Linux. |
| Python | Extern arbetare. Release 1.4.1 använder Python 3.13.6 i egen isolerad .venv med hela den låsta paketlistan; check/sync/rebuild görs med setup_python_environment. |
| ArgyllCMS | Uppdaterad macOS-mapp innehåller separat licensierade 3.5.0-verktyg för ARM/Intel som provstartas. Andra plattformar behöver kompatibel installation. Verktyg är bland annat targen, printtarg, chartread/spotread, colprof, xicclu och profcheck. |
| NumPy, SciPy, colour-science | Numerisk och spektral analys. Exakta låsningar finns i requirements.txt; `requirements-analysis.txt` hänvisar till samma lista. |
| Pillow / LittleCMS | ICC-behandling och jämförelser; ursprunglig profil och transformvillkor spelar roll. |
| tifffile, imagecodecs | Diagnostik av RGB16-TIFF och komprimerad TIFF vid behov. |
| ReportLab | PDF-rapporter; låst i requirements.txt. `requirements-report.txt` hänvisar till samma lista. |

Programmet använder egen isolerad `.venv` med Python 3.13.6 och låst `requirements.txt`; analys-/rapportfiler hänvisar till samma lista. `setup_python_environment` kontrollerar, synkroniserar eller bygger om miljön. `setupInkProf(CheckPython=true)` kontrollerar installationen och `startInkProfApp` öppnar appen. Nativ Python prioriteras på Apple Silicon.

Mätbryggan innehåller POSIX-beroende vägar. Testad instrumentanvändning omfattar i1Pro 2 på macOS; andra system och instrument kräver egen verifiering. Fungerande kommunikation bevisar inte korrekt instrumentkalibrering eller rätt mätvillkor.

InkProf-kod, tester och dokumentation omfattas av GPL-3.0-or-later utan garanti. MATLAB, Python, ArgyllCMS och externa bibliotek har egna villkor. Medföljande undantag omfattar CxF3-schema, typsnitt och material som anges i `LICENSE_SCOPE.md`, `THIRD_PARTY_NOTICES.md` och `licenses/inventory.json`. Användarens mätdata och inlästa profiler får inte ny licens bara för att projektet exporteras.
---PAGE---
## Bilaga B. Filer: vad behövs och var finns det?

Sökvägarna beskriver genererade projektpaket. Arbetsflöde och API kan välja olika rötter. Artefaktlänkar och verification.json identifierar rätt paket; UUID och namngivna undermappar varierar.

| Plats relativt projektet | Innehåll och ansvar |
| --- | --- |
| inkprof-project.json | Identitet, inställningar, register och historik; skapas av appen |
| workflow.json | Sparad status och artefaktlänkar; skapas av appen |
| sources/ | Importerat källmaterial; bevara ursprungsunderlaget |
| targets/ | TI1-definition och JSON, renderad TIFF16/TI2, chart/layout och paketdata |
| measurements/ | Mätsessioner och revisioner; parvisa JSON/TI3 samt motsvarande chart-underlag |
| profiles/inputs/<id>/ | Låst B1: profile-input.json, measurement.json, chart.json, source.ti3, profiling.ti3 |
| profiles/... | B2-recept och B3-jobb; faktisk undermapp anges i arbetsflödet |
| <jobb>/engine.ti3 | Data som gavs till profileringsmotorn |
| <jobb>/status.json; worker.log | Jobbets utfall och driftunderlag |
| <jobb>/result/profile.icc | Lyckad ICC-kandidat |
| <jobb>/checks/<id>/ | Diagnostikrapporter för Fit, Grid och C1 |
| targets/<ID>/ | C2-paket i huvudflödet: verification.json, definition/ och print/ |
| verification/<namn-ID>/ | C2-paket när API körs utan uttrycklig OutputFolder |
| <C2-paket>/checks/<ID>/ | C3: verification-check.json och verification-check.md |
| analyses/; reports/ | Analyser, beslut och leverans-/rapportartefakter |
| profiles/exports/ | ICC-exportkvitton samt ursprungs- och leveransidentiteter |

Installationen innehåller `src/`, `bridge/`, `profiles/`, `analysis/`, `schemas/`, `resources/`, `config/` och kravfiler. Det är programresurser, inte ersättning för projektets filer. Gemensam `.icc-v2-cache` under installationens projects/ är en konverteringscache, inte fullständig projektbackup.

För ett nytt mätflöde tillför användaren fysisk skrivare/papper/bläck, inställningar, faktisk utskrift och instrumentavläsningar. En valfri befintlig ICC styr punktplacering men ersätter inte mätdata. Matchande TI1/JSON/TI2/layout och mätrevisioner skapas eller importeras genom appen. Enbart TIFF eller enbart Lab garanterar inte att identitetskedjan finns kvar.
---PAGE---
## Bilaga C. Avstämning och kodreferenser

| Fråga | Underlag att bevara |
| --- | --- |
| Vilket fysiskt utskriftssystem? | Projektets material- och utskriftsinställningar, utskriftsväg och torkning |
| Vilket mål och vilka RGB-värden? | Definition JSON/TI1, utskriven TI2/TIFF16, layout och hashar |
| Vilka mätningar? | Vald accepterad revision, mätvillkor/instrument, chart-koppling och käll-TI3 |
| Vilka byggdata och inställningar? | Låst B1-paket, B2-recept, B3-argument/logg/status |
| Exakt vilken ICC kontrollerades och levererades? | ICC-hashar i kontroller, verifieringsreferenser och exportkvitton |
| Vad verifierades fysiskt? | C2-paket, motsvarande utskriftsmätning och C3-rapport |
| Vad godkändes? | Uttryckligt beslut om avsedd användning och leveransomfattning, inte bara klar rad |

Primära implementationsreferenser är kodfilerna i respektive kapitel. Referenser utan katalogprefix avser `src/+inkprof/`. Publik källkod och release: https://github.com/chto0703009/InkProf-public samt https://github.com/chto0703009/InkProf-public/releases/tag/v1.4.1.

Fördjupning i repot: `docs/usage/rgb-target-designer.md`, `docs/usage/workflow-v1.0.md`, `docs/usage/profiling-paths.md`, `docs/usage/profiling-best-practice.md`, `docs/usage/verify-existing-icc.md`, `docs/usage/measurement-certificate.md`, `docs/releases/v1.4.1.md`, `VALIDATION.txt` och licensfilerna. Äldre guider kan behålla historiska versionsrubriker; här används implementationen i v1.4.1.

Release 1.4.1 kontrollerades i den separata publika källkopian med 59 godkända riktade MATLAB-tester och 29 godkända Python-tester; inga fel eller ofullständiga MATLAB-tester rapporterades. Miljökontroll och PDF-/paketkontroller dokumenteras i VALIDATION.txt och docs/releases/v1.4.1.md. Tester med syntetiska data och isolerade projekt är inte ny fysisk instrument- eller skrivarkvalificering.

Historiskt underlag: release 1.2.2 hade 23 riktade MATLAB-kontroller. Denna äldre uppgift beskriver inte testomfattningen för 1.4.1.

Begränsningar kvarstår: samplad diagnostik täcker inte alla transformindata; profiljämförelse är inte mätning; okända förhållanden kan inte återskapas från filnamn; FWA-simulering är inte uppmätt M1; verifieringsfärger som senare används för träning ändrar roll. Bevara underlaget som behövs för tolkning i stället för att enbart lita på ICC-filen.

### Implementation för target och utskriftskopia

Implementation: MeasurementDialog och measurementTargetInfo behåller bindningen till förberedd session och visar metadata/förhandsvisning. ProjectWorkflow.savePrintCopy använder printDeliveryFolder och writePrintDeliveryInfo. Kopierade TIFF verifieras med SHA, kvittot binder originalets TI2/manifest och arbetsflödesidentitet och historiken får print-copy-saved. Mappnamnet använder project.name och inte printing.profileName.
---PAGE---
## Bilaga D. Målidentitet och spårbara utskriftskopior

### Bindning mellan mätning och mål

Arbetsflödets rad 3 använder grundmålets TI2; rad 10 (C2b) använder det valda C2-paketets TI2 och verifieringsreferens. En förberedd mätsession låser målvalet. `measurementTargetInfo` sammanställer patchantal, måltyp, sidantal, tidsuppgifter och förhandsvisning från paketet. Saknade historiska metadata fylls inte i med antaganden. En sparad tid identifierar inte det fysiska utskriftstillfället.

### Identitet i kopierade paket

`ProjectWorkflow.savePrintCopy` skapar en separat destinationsmapp via `printDeliveryFolder`. Namnet bygger på projektets namn, aktuell iteration, radens interna ID och lokal kopieringstid; namnkrockar ger en ny numrerad mapp. Projektets `name` och profilens `printing.profileName` är skilda identiteter.

`writePrintDeliveryInfo` skapar UTF-8-filen `PROJECT_INFO.txt` och det strukturerade kvittot `print-delivery.json`. De knyter kopian till projekt-ID, källpaket, TI2 och SHA-256, utskriftsinställningar samt aktuella och historiskt identifierbara iterationsuppgifter. Kopierade TIFF-filer verifieras byte för byte. Historiken registrerar kopieringen utan att flytta originalprojektet.

### Iterationsursprung och fysisk spårbarhet

Ett mål kan ha skapats före den iteration som är aktiv vid kopieringen. Kvittot skiljer målursprung från kopieringstillfälle när historiken kan styrka det. Okända uppgifter förblir okända. Hashar identifierar filer, inte fysiska pappersark eller verkliga drivrutinsinställningar. En extern TIFF-kopia ersätter inte originalets TI2/layout och mätrevisioner.

Kodreferenser: `MeasurementDialog.m`, `+internal/measurementTargetInfo.m`, `ProjectWorkflow.m`, `+internal/printDeliveryFolder.m`, `+internal/writePrintDeliveryInfo.m`.
---PAGE---
## Bilaga E. Återkoppling och verifierad ICC i leveransen

### C3-resultatens placering

`checkVerificationTarget` skapar varje kontroll under `<C2-paket>/checks/<kontroll-ID>/`, där paketet är mappen som innehåller `verification.json`. Rapporterna heter `verification-check.json` och `verification-check.md`. I huvudflödet ligger C2-paket normalt under `targets/<ID>/`; API-standardvägen är `verification/<namn-ID>/`. Samma relativa regel gäller i båda fallen och för kombinerade förfiningspaket.

C3 särredovisar uppmätt utskrift mot önskat Lab och mot ICC-prediktionen. `analyseVerification` skapar återkopplingsunderlag som kan öppnas från aktuell arbetsflödesrad eller dess sparade resultat. En ny kontroll får ett nytt ID och skriver inte över tidigare kontroller.

### Beslut och leveransidentitet

Radval i huvudfönstret är navigering. `approvalDialog` sparar ett uttryckligt beslut om avsedd användning efter granskning. Rad 14 samlar underlag och beslut i en ny leveransrevision. Valet av extern kopia ändrar inte vilket ICC-original som kontrollerats; rad 19 har separat numerisk omfattning.

Leveransen innehåller `<namn>-verified-original.icc`, en byteidentisk kopia av kontrollerad ICC. En namngiven leveransvariant kan ha ändrad namnmetadata; en v4.4-variant är en dokumenterad konvertering. `delivery.json` lagrar `verifiedOriginalICCFile` och `verifiedOriginalICCSHA256`. Registrerade certifikat återskapas inte på plats.

Kodreferenser: `checkVerificationTarget.m`, `analyseVerification.m`, `+internal/approvalDialog.m`, `ProjectWorkflow.m`, `+internal/writeWorkflowFinalReport.m`.
---PAGE---
## Bilaga F. Granskning, låsning och rättelser

### Tillståndsövergångar och granskningsgränser

Rad 4 behåller mätförhandsvisningen tills bedömningen fortsätter. B1 validerar vald mätrevision och sparar först efter modal bekräftelse en verifierad indatakopia. Arbetsflödet skiljer öppnad dialog från accepterat och registrerat resultat. Föreslagen ordning är B1, B2, B3; den automatiska B3-vägen genererar egna recept.

Parametrar för extra kompletteringspatchar hör till förfining och följande iterationer. Det första B3-bygget använder det låsta grundunderlaget. C1 sparar rapporter utan att öppna flera resultatfönster i följd. Sparade resultat är separata från körningen som skapade dem.

### Dokumentationsrättelse och ändrat fysiskt system

`Project details` skiljer `Correct recorded details` från `Changed actual setup`. En dokumentationsrättelse kräver förklaring och oförändrade fysiska villkor. Originalfiler verifieras och revisionshistoriken får före-/eftervärden. Undantaget gäller inte numeriska processändringar och återställer inte automatiskt redan inaktuella resultat.

En verklig förändring av utskriftssystemet invaliderar berörda beroenden. En sparad rättelse bevisar inte att den fysiska utskriften hade vissa villkor; den dokumenterar operatörens uppgift och beslut.

Kodreferenser: `ProjectWorkflow.m`, `projectDetailsDialog.m`, `+internal/executeWorkflowStep.m`, `+internal/workflowSteps.m`.
---PAGE---
## Bilaga G. Mätning, avbrott och leverans

### Instrumentprocess och återkoppling

RGB-kontroller, punktommätningar och pappersvitt använder samma princip för startljud vid skärm- och instrumentutlöst mätning med i1Pro 2. Kalibrering är ett separat processtillstånd. RGB-rader visar sida, färg och förlopp; sidbyte presenteras i samma fönster utan ytterligare modal bekräftelse.

`SpotReadSession` och `readSpotLines` separerar delvis inkommande processutdata från fullständiga frågor och mätvärden. GUI-pollning får inte blockeras av en ofullständig textrad. En avbrytning återställer aktivitetstillstånd, medan sparade förfrågningar, loggar och mätningar bevaras. Återupptagning av delmätning förutsätter samma fysiska utskrift.

### Fönsterlivscykel och kopior

När `gamutPicker` har fått ett färdigt, registrerat mål från `refineFromGamut` stängs gamutfiguren även vid fristående anrop. Avbrott eller fel före färdigställandet lämnar figuren tillgänglig. Den externa kopian är separat från projektets målpaket och använder projekt-/iterationsidentitet; originalprojektet flyttas inte.

### Leveransaktivitet

Rad 14 rapporterar arbetsfas och förfluten tid för insamling av underlag, figurer/PDF, ICC-varianter och verifierad kopiering. Ett färdigt certifikat är en registrerad artefakt; en ändring ger en ny exportrevision. Aktivitetsvisningen bevisar driftsförlopp, inte färgnoggrannhet.

Kodreferenser: `SpotReadSession.m`, `+internal/readSpotLines.m`, `+internal/gamutPicker.m`, `refineFromGamut.m`, `ProjectWorkflow.m`.
---PAGE---
## Bilaga H. Gamutgräns och utökat utskriftsmål

### Kandidater kring en modellerad yta

`gamut_refinement.py` väljer giltiga enhets-RGB-värden nära den aktuella ICC-modellens gamutmesh. Urval kan avse ett inre skal, en vald region eller båda sidor av ytan. Signerat Delta E76-avstånd skiljer insida från modellerad utsida. Negativt avstånd bevisar inte att skrivaren kan återge ett större fysiskt färgomfång. Minsta RGB-avstånd och högsta antal nya punkter begränsar kandidatpoolen.

### Utökning med bevarat ursprung

`gamutTargetExtension` identifierar senaste färdiga, kompatibla utskriftspaket för samma ICC-hash. Förslag utan färdig TIFF hoppas över. Befintliga anpassnings-/utvecklingspunkter och extra skuggpunkter bevaras; kontrollroller återskapas. Exakta dubbletter och RGB som redan ingår i träningen utesluts. Sparade bekräftade mätrader, TI3 eller en mätrevision med RGB-data blockerar utökning av paketet. Enbart ett öppnat mätfönster blockerar inte.

### Ny version av hela målpaketet

Utökningen skapar ett nytt komplett TIFF16/TI2-paket med frysta roller och ursprungsreferenser. Tidigare filer och mätningar ändras inte. Rad 16 binder nya avläsningar till den nya layouten; rad 17 bygger en ny profil med tidigare godkända träningsdata och kompletteringen. Den externa kopiedialogen utgår från Downloads. Ett avbrutet kopieval påverkar inte det redan sparade projektpaketet.

Kodreferenser: `refineFromGamut.m`, `+internal/gamutTargetExtension.m`, `+internal/gamutPicker.m`, `analysis/gamut_refinement.py`, `+internal/createRefinementPrint.m`.
---PAGE---
## Bilaga I. Uppmätt Lab-täthet och separat kandidat

### Gruppering av ursprungliga observationer

`measurement_density.py` grupperar närliggande uppmätt Lab med en fullständig grannskapsregel som begränsar hela gruppens utsträckning. RGB16-upprepningar och deras Delta E00-spridning hålls isär från olika RGB som ger liknande Lab. Likheten kan vara förenlig med mättnad men fastställer inte ensam orsaken. Originalobservationer raderas, ändras eller medelvärdesbildas inte.

### Urval och skyddade observationer

Granskningsparametrar är Lab-avstånd (Delta E76), målantal per grupp och repeterbarhetsgräns (Delta E00). Standardvärdena 1 / 4 / 1 är provisoriska. Markerade grupper balanseras med automatiska representanter; omarkerade grupper behåller alla rader. Neutrala RGB, ljushets-/RGB-ytterlägen och inkonsekventa upprepningar skyddas. Målantalet är därför inte ett ovillkorligt borttagningskrav. Ändrade parametrar kräver omberäkning före kandidatbygge.

### Jämförelse på gemensamt underlag

`buildDensityTrial` skapar en separat kandidat från ett dokumenterat delurval. Bygget är spärrat om inga observationer utelämnas. Ursprunglig och ny profil jämförs mot alla ursprungliga träningsobservationer, även utelämnade, samt tillgängliga undanhållna utvecklingspatchar och samma tonövergångar. Kandidaten ersätter inte automatiskt aktiv profil. Diagnostiken är inte en ny oberoende utskriftsverifiering.

Kodreferenser: `reviewMeasuredDensity.m`, `buildDensityTrial.m`, `+internal/showMeasuredDensity.m`, `+internal/densityGroupSelection.m`, `analysis/measurement_density.py`, `analysis/density_comparison.py`.
---PAGE---
## Bilaga J. Aktivitet, spårbarhet och körmiljö

### Aktivitets- och revisionskontrakt

Täthetsgranskning och kandidatbygge rapporterar arbetsfaser för indatakontroll, originalkopior, ICC-bygge, jämförelse av alla patchar, tonövergångar, tillgängliga utvecklingskontroller och sparning. Parametrar, markerade grupper, källrader och SHA-256 finns i separata gransknings-/försöksfiler. Faserna beskriver faktisk bearbetning och hålls åtskilda från väntan på användarbeslut.

### Isolerad miljö per program

Varje program har egen `.venv` med Python 3.13.6 och den gemensamt låsta `requirements.txt`. `setup_python_environment` anropar miljöhanteraren för `check`, `sync` eller `rebuild`. Ombyggnad bevarar tidigare miljö som backup och återställer den vid fel. En kopierad miljö betraktas inte som portabel ersättning för ombyggnad på en annan dator. Projekt och originalmätningar är separata från körmiljön.

### Arkitektur och tredjepartsverktyg

Programmappen innehåller separat licensierad ArgyllCMS 3.5.0 för ARM och Intel macOS. Arkitektur och faktisk startbarhet kontrolleras; nativa verktyg prioriteras. `provenance.json` och ursprungliga licenser/notiser identifierar medföljande distributioner. Källkod, miljöinställningar och mätdata har olika livscykler.

Kodreferenser: `+internal/calculationProgress.m`, `setup_python_environment.m`, `tools/manage_python_environment.py`, `requirements.txt`, `+internal/argyllUsable.m`, `third_party/argyll/provenance.json`.
