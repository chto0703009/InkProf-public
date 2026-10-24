# InkProf - Teknisk beskrivning

Christer Törnkvist

christer@borgasundsfotografiska.se

https://github.com/chto0703009/InkProf-public

Version 1.2.3 | 2026-10-24 | GPL-3.0-or-later

Implementation, beräkningskedja och datakontrakt

Beskrivningen gäller den släppta appen för profilering av RGB-skrivare. Den följer data från definition av färgmål via mätning, ICC-bygge och numeriska kontroller till uppmätt verifieringsutskrift och leverans. Handboken beskriver användarens knapptryckningar; detta dokument förklarar vad stegen innebär och vilka filer de behöver.

Teknisk bas är källkodsversion 1.2.2. Äldre gränssnittsbilder anges uttryckligen som dokumentationsexempel. De visar fiktiva projekt och är inte mätresultat som bevisar utskriftskvalitet. Sökvägar i appendix är relativa till installationens eller projektets rot. Genererade UUID och mappnamn varierar.


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
| 10 | Appendix A. Installation, beroenden och licens |
| 11 | Appendix B. Filer: vad behövs och var finns det? |
| 12 | Appendix C. Avstämning och kodreferenser |
| 13 | Appendix D. Mättargetens identitet och spårbara utskriftskopior |

---PAGE---
## 1. Arkitektur och avgränsning

InkProf samordnar profilering av en RGB-skrivare med bestämt papper, bläck och utskriftsinställningar. Appen profilerar inte digitala kameror och styr inte en analogkamera. Ett utskrivet RGB-färgmål är något annat än en fotograferad ColorChecker. Camera-41-apparnas begränsning till SG140 begränsar inte InkProfs valbara uppsättningar skrivarpatchar.

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

Argyll-alternativen använder targen och kan använda en befintlig RGB-skrivarprofil för perceptuell placering. I v1.2.2 får ICC v4 automatiskt en separat approximativ v2-kompatibilitetskopia. Original och konverteringsunderlag bevaras. Cachen identifieras av originalets hash. Rekonstruktionen använder ett relativt framåt-rutnät med 17 punkter per axel och invers Bradford-anpassning av medievitt. Inverstabeller och perceptuell avbildning byggs om. Detta är en approximation, inte en ändrad versionsbyte.

Definitionen sparas som TI1 och JSON utan utskriftslayout. Renderingen skapar därefter TIFF16, TI2 och motsvarande layoutdata. Ideala flyttalsvärden och kvantiserade RGB16 är separata uppgifter. Fönsterreferenser och callbacks sparas inte i JSON.

---PAGE---
## 3. Mätning och färgberäkningsvillkor

Motsvarande TI2/layout behövs: en mätning är mer än en lista med Lab-värden. Patch-ID, position, RGB-kommandon, fullständighet och tillgängliga spektra/XYZ måste behålla kopplingen till utskriften. Instrumentfrågor, kalibrering och remsans riktning hanteras av mätflödet och Argyll-bryggan. Importerad CGATS/TI3 eller stödd MXF kräver motsvarande identitets- och layoutunderlag.

![Mätgränssnitt](docs/usage/handbook-source/examples/measurement-window.png)

Figur 1. Gränssnittsexempel för dokumentation från 2026-10-09, före instrumentstart. Bilden visar ingen genomförd mätning. Texter kan skilja från v1.2.2.

En ommätning blir först en kandidat och sedan en accepterad revision. Registrerade avläsningar får inte ersättas i det tysta. Parade skanningar, upprepningar och punktkorrektioner svarar på olika frågor. Repeterbarhetsmått gäller de faktiskt genomförda upprepningarna och beskriver inte all osäkerhet i skrivare, instrument och miljö.

Mätvillkor ska anges, inte gissas från filändelsen. Spektral indata integreras under stödda valda villkor. Nuvarande profilarbetare kräver D50 och CIE 1931:s 2-gradersobservatör för den spektrala vägen. Lagrade XYZ är en separat väg som beror på de ursprungliga beräkningsvillkoren.

FWA/OBA-kompensation kräver ursprungliga M0-färgspektra, känt kompatibelt instrument utan UV-filter, våglängdstäckning från högst 400 nm till minst 700 nm samt lämplig uppmätt pappersvitreferens. Instrument och våglängder för vitreferensen måste stämma. M1, M2, okända eller redan kompenserade data kan inte behandlas som ursprungliga M0. Mätning av blankt papper kan inte ersätta saknade färgspektra. Simulerad FWA-kompensation till D50 är ingen fysisk M1-mätning.

Kodreferenser: `startMeasurement.m`, `MeasurementDialog.m`, `importMeasurement.m`, `prepareProfileInput.m`, `createProfileRecipe.m`.

---PAGE---
## 4. B1-B3: från accepterad mätning till ICC

B1 kontrollerar de faktiska mätfilerna, överensstämmelse mellan JSON och TI3, kartläggning av patchar och fullständighet. Ett nytt låst paket skapas med mät-JSON, chart-JSON, ursprunglig TI3, profilerings-TI3 och `profile-input.json`. Hashar knyter paketet till underlaget. Att öppna en dialog innebär inte att något accepterats.

B2 sparar ett uttryckligt recept men bygger ingen profil. Det anger färgdataväg, kvalitet för utmatningstabeller, utjämning, perceptuella inställningar och relevanta utskriftsuppgifter. Projektinställningarna kan ge värden, men det sparade receptet styr bygget. FWA kontrolleras innan receptet kan användas. Den borttagna axiella/Hessian-baserade InkProf-regulariseringen av rutnät avvisas av nuvarande jobbkörning; den är inte ett aktivt profileringsval.

![Receptgränssnitt](docs/usage/handbook-source/examples/profiling-recipe.png)

Figur 2. Fiktivt receptexempel från 2026-10-09 som avbröts utan profilbygge. Receptet beskriver inställningar, inte uppmätt kvalitet.

B3 verifierar receptets och indatans hashar, kopierar nödvändigt underlag till arbetsytan och startar Python-arbetaren och Argyll colprof. Spektral indata och lagrade XYZ förbereds på uttryckligt skilda sätt. Vid FWA görs integration och kompensation en gång före anpassningen och underlaget bevaras. `engine.ti3` visar vilka data som faktiskt gavs till motorn.

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

C1 använder också avsiktligt skadade profiler som negativa kontroller. Att upptäcka dem ger stöd åt diagnostiken, men bevisar inte att alla möjliga ICC-fel upptäcks. Den öppna forskningsfrågan ISSUE-001 förklaras inte vara ett fastställt profilfel. Mätbrusets fortplantning genom en ny anpassning är ännu inte fullständigt kvantifierad.

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

Nästa profilbygge använder det godkända träningsunderlaget och skapar en ny kandidat. Jämförelse av föregående och aktuell ICC på gemensamma provpunkter visar numerisk förändring. Gör aktuella kontroller och helst en ny fysisk verifieringsutskrift för att bedöma förbättring. Två jämförda modellytor ger inte ny uppmätt utskriftsnoggrannhet.

Leveransvägen med enbart numeriskt underlag för en senare iteration skiljs från utskriftsverifierad leverans. Den beskriver tillgängliga beräkningsresultat och begränsad omfattning. Den skapar ingen saknad verifiering och innebär inte att en äldre utskrift verifierar en ändrad ICC.

Kodreferenser: `proposeRefinement.m`, `continueRefinement.m`, `iterateProfile.m`, `refineVerification.m` och arbetsflödets hanterare för rad 15-19. Den faktiskt använda vägen dokumenteras i projektets underlag.

---PAGE---
## 8. Projektstatus, integritet och leverans

`inkprof-project.json` innehåller projektidentitet, utskriftsinställningar, filregister och historik. `workflow.json` innehåller arbetsstatus och artefaktlänkar. Projektinställningar är inte datorns körmiljö: lokala Python-/Argyll-sökvägar blir inte portabla data om skrivaren.

Ready betyder att nödvändig indata finns. Complete betyder att radens resultat eller beslut sparats. Locked anger att förutsättningar saknas. Stale anger att ett beroende ändrats och tidigare resultat behöver uppdateras. Ingen av dessa etiketter innebär ensam att utskriften klarar önskad noggrannhet.

SHA-256 identifierar exakta filinnehåll och kan upptäcka utbyte eller oavsiktlig ändring. Hashar visar inte om instrumentet placerades rätt, om utskriftsinställningarna stämde med verkligheten eller om mätningen var vetenskapligt lämplig. Okända fysiska uppgifter måste förbli okända. En ny revision ska bevara tidigare underlag och inte tyst räkna om hashar för orelaterade ändrade filer.

Leverans skapar en uttrycklig ICC-kopia och dokumenterar originalets och kopians hashar. Interaktiv namngivning kan uppdatera ICC-profilens interna beskrivning; leveranskopian kan därför legitimt skilja från byggkandidaten. Stödda val av v2/v4.4 och konverteringsunderlag ska vara synliga. Profilbygge och formatkonvertering är olika operationer.

Certifikat och supplement anger mätvillkor, vald profil och godkännandets omfattning. HTML-leveranser kan behöva stödfiler; flytta hela paketet. Registrerade rapporter får inte genereras om på plats: gör en ny arbetsflödesexport. Ett certifikat dokumenterar sparat underlag och operatörsbeslut, inte ackreditering eller automatiskt uppfyllda standardkrav.

Långa beräkningar visar aktivitet, arbetsfas och förfluten tid. Filval och användarbeslut är något annat än beräkning. Måldesignen i v1.2.2 skapar automatiskt separat v2-kompatibilitetskopia när den behövs; andra importvägar kan fortfarande begära bekräftelse.

---PAGE---
## Appendix A. Installation, beroenden och licens

| Komponent | Funktion och krav |
| --- | --- |
| MATLAB | App, geometri och samordning. Base MATLAB R2025b testad på macOS; innebär inte verifiering av Windows/Linux. |
| Python | Extern arbetare. Körkontrollen accepterar Python 3.10+ inom 3.x; analyskraven anger testade/stödda 3.11-3.13. Paketen måste passa vald tolk. |
| ArgyllCMS | Installeras separat. Relevanta vägar använder targen, printtarg, chartread/spotread, colprof, xicclu, profcheck och närliggande verktyg. |
| NumPy, SciPy, colour-science | Numerisk och spektral analys. Exakta låsningar finns i requirements-analysis.txt. |
| Pillow / LittleCMS | ICC-behandling och jämförelser; ursprunglig profil och transformvillkor spelar roll. |
| tifffile, imagecodecs | Diagnostik av RGB16-TIFF och komprimerad TIFF vid behov. |
| ReportLab | PDF-rapporter via requirements-report.txt. |

En projektlokal `.venv` rekommenderas för isolerad Python; en uttryckligt konfigurerad tolk stöds också. Miljöskapande och paketinstallation hör till installationen, inte varje målberäkning. `setupInkProf(CheckPython=true)` kontrollerar vald Python; `startInkProfApp` öppnar appen. Chartread-bryggan använder standardbiblioteket, medan analys och rapportering behöver de ytterligare requirements-filerna.

Mätbryggan innehåller POSIX-beroende vägar. Testad instrumentanvändning omfattar i1Pro 2 på macOS; andra system och instrument kräver egen verifiering. Fungerande kommunikation bevisar inte korrekt instrumentkalibrering eller rätt mätvillkor.

InkProf-kod, tester och dokumentation omfattas av GPL-3.0-or-later utan garanti. MATLAB, Python, ArgyllCMS och externa bibliotek har egna villkor. Medföljande undantag omfattar CxF3-schema, typsnitt och material som anges i `LICENSE_SCOPE.md`, `THIRD_PARTY_NOTICES.md` och `licenses/inventory.json`. Användarens mätdata och inlästa profiler får inte ny licens bara för att projektet exporteras.

---PAGE---
## Appendix B. Filer: vad behövs och var finns det?

Sökvägarna beskriver ett typiskt projekt. Behåll kompletta genererade paket. UUID och namngivna undermappar varierar; använd appen i stället för att bygga strukturen manuellt.

| Plats relativt projektet | Innehåll och ansvar |
| --- | --- |
| inkprof-project.json | Identitet, inställningar, register och historik; skapas av appen |
| workflow.json | Sparad status och artefaktlänkar; skapas av appen |
| sources/ | Importerat källmaterial; bevara ursprungsunderlaget |
| targets/ | TI1-definition och JSON, renderad TIFF16/TI2, chart/layout och paketdata |
| measurements/ | Mätsessioner och revisioner; parade JSON/TI3 samt motsvarande chart-underlag |
| profiles/inputs/<id>/ | Låst B1: profile-input.json, measurement.json, chart.json, source.ti3, profiling.ti3 |
| profiles/... | B2-recept och B3-jobb; faktisk undermapp anges i arbetsflödet |
| <jobb>/engine.ti3 | Data som gavs till profileringsmotorn |
| <jobb>/status.json; worker.log | Jobbets utfall och driftunderlag |
| <jobb>/result/profile.icc | Lyckad ICC-kandidat |
| <jobb>/checks/<id>/ | Diagnostikrapporter för Fit, Grid och C1 |
| verification/<namn-id>/ | C2-referens, renderat mål och tillhörande verifieringsunderlag |
| analyses/; reports/ | Analyser, beslut och leverans-/rapportartefakter |
| profiles/exports/ | ICC-exportkvitton samt ursprungs- och leveransidentiteter |

Installationen innehåller `src/`, `bridge/`, `profiles/`, `analysis/`, `schemas/`, `resources/`, `config/` och kravfiler. Det är programresurser, inte ersättning för projektets filer. Gemensam `.icc-v2-cache` under installationens projects/ är en konverteringscache, inte fullständig projektbackup.

För ett nytt mätflöde tillför användaren fysisk skrivare/papper/bläck, inställningar, faktisk utskrift och instrumentavläsningar. En valfri befintlig ICC styr punktplacering men ersätter inte mätdata. Matchande TI1/JSON/TI2/layout och mätrevisioner skapas eller importeras genom appen. Enbart TIFF eller enbart Lab garanterar inte att identitetskedjan finns kvar.

---PAGE---
## Appendix C. Avstämning och kodreferenser

| Fråga | Underlag att bevara |
| --- | --- |
| Vilket fysiskt utskriftssystem? | Projektets material- och utskriftsinställningar, utskriftsväg och torkning |
| Vilket mål och vilka RGB-värden? | Definition JSON/TI1, utskriven TI2/TIFF16, layout och hashar |
| Vilka mätningar? | Vald accepterad revision, mätvillkor/instrument, chart-koppling och käll-TI3 |
| Vilka byggdata och inställningar? | Låst B1-paket, B2-recept, B3-argument/logg/status |
| Exakt vilken ICC kontrollerades och levererades? | ICC-hashar i kontroller, verifieringsreferenser och exportkvitton |
| Vad verifierades fysiskt? | C2-paket, motsvarande utskriftsmätning och C3-rapport |
| Vad godkändes? | Uttryckligt beslut om avsedd användning och leveransomfattning, inte bara klar rad |

Primära implementationsreferenser är kodfilerna i respektive kapitel. Referenser utan katalogprefix avser `src/+inkprof/`. Publik källkod och release: https://github.com/chto0703009/InkProf-public samt https://github.com/chto0703009/InkProf-public/releases/tag/v1.2.2.

Fördjupning i repot: `docs/usage/rgb-target-designer.md`, `docs/usage/workflow-v1.0.md`, `docs/usage/profiling-paths.md`, `docs/usage/profiling-best-practice.md`, `docs/usage/verify-existing-icc.md`, `docs/usage/measurement-certificate.md`, `docs/releases/v1.2.2.md`, `VALIDATION.txt` och licensfilerna. Äldre guider kan behålla historiska versionsrubriker; här används implementationen i v1.2.2.

För v1.2.2 omfattar riktade MATLAB-releasekontroller 23 godkända tester för ICC-kompatibilitet, aktivitet, RGB-generering och definitionssparning. Den automatiska kompatibilitetsvägen kontrollerades också med ett befintligt cachat v4-original: v2-header skapades, originalets SHA-256 förblev oförändrad och aktiviteten avslutades. Det är inte en ny fullständig testsvit eller fysisk validering av skrivare/instrument.

Begränsningar kvarstår: samplad diagnostik täcker inte alla transformindata; profiljämförelse är inte mätning; okända förhållanden kan inte återskapas från filnamn; FWA-simulering är inte uppmätt M1; verifieringsfärger som senare används för träning ändrar roll. Bevara underlaget som behövs för tolkning i stället för att enbart lita på ICC-filen.

### Implementation för target och utskriftskopia

Implementation: MeasurementDialog och measurementTargetInfo behåller bindningen till förberedd session och visar metadata/förhandsvisning. ProjectWorkflow.savePrintCopy använder printDeliveryFolder och writePrintDeliveryInfo. Kopierade TIFF verifieras med SHA, kvittot binder originalets TI2/manifest och arbetsflödesidentitet och historiken får print-copy-saved. Mappnamnet använder project.name och inte printing.profileName.

---PAGE---
## Appendix D. Mättargetens identitet och spårbara utskriftskopior

### Grundtarget eller C2-verifiering?

Steg 3. Measure / select measurement revision läser grundtargeten från steg 2. En C2-utskrift hör till C2. Measure / select verification revision. Är rätt paket redan valt går du direkt till den mätningen utan att skapa en ny target. När alla rader lästs: Save and finish, sedan C3. Compare model and print och Review feedback.

### Target locked är avsiktligt

En förberedd mätning är bunden till sin TI2. Den grå Choose chart-knappen heter nu Target locked. För att byta: stäng mätfönstret och välj motsvarande target i arbetsflödet. Byt inte till ett liknande kort mitt i en förberedd eller delvis inläst session.

### Detta visas i fönstret

Sammanfattningen visar patchantal, registrerad targettyp, sidantal, sparad lokal tid och UTC. Target details visar hela sökvägen och erbjuder sidförhandsvisning. Saknade historiska uppgifter gissas inte. Jämför med utskriftens sidfot. Paketets skapelsetid bevisar inte utskriftsdatum eller torktid.

### Mappnamn

Exempel: My printer paper_iter-1_c2_20261024-123456. Prefixet är sparat projektnamn följt av arbetsflödets iteration vid kopiering, steg och lokal kopieringstid. Namnkrock ger en ny numrerad mapp och skriver inte över tidigare leverans. Projektnamnet används, inte en separat ICC-/profilbeskrivning.

### PROJECT_INFO.txt

UTF-8-filen innehåller exakt projektnamn och ID, projektets ursprungliga sökväg, arbetssteg, aktuell iteration/iterations-ID, targetens ursprungsiteration/ID när historiken kan styrka den, lokala tider och UTC, registrerad targetbeskrivning, ursprunglig TI2 och SHA-256, projektets utskriftsinställningar samt kopierade filnamn med SHA-256. Okänt ursprung förblir okänt.

### Kopior och original

PRINTING.txt innehåller utskriftsinstruktioner. print-delivery.json innehåller strukturerat kvitto; kopieringen registreras även i projektets rapporter/historik. TIFF kopieras och kontrolleras byte för byte. En hash identifierar inte det fysiska arket: matcha sidfoten och dokumenterade inställningar. TIFF-leveransen ersätter inte originalets TI2/layout vid mätning.

### Targetens iteration kan vara äldre

En grund- eller C2-target kan ha skapats i en tidigare iteration. Mappnamnet anger iterationen vid kopiering. PROJECT_INFO.txt anger separat targetens ursprung när matchande historik finns. Skapelsedatum och kopieringsdatum är skilda händelser och bevisar inte fysisk utskriftstid.

### Kopia av hela targetpaketet

Den alternativa kopieringen av komplett targetpaket från förfiningsverktyg använder också projektbaserat namn och projektinformation när ursprunget finns i ett identifierat projekt. Utan projektkontext används ett generellt läsbart namn; projekt och iteration hittas inte på.
