# InkProf - mätcertifikat

Mätcertifikatet är ett överlämningsdokument för en sparad ICC-profil. Det sammanfattar projektets förutsättningar, mätresultat och användarens bedömning för en uppdragsgivare. Det ersätter benämningen slutrapport i appens leveranssteg.

## Projekt och resultat

Certifikatet innehåller projektets namn och ID, projektansvarig, dokumentets användare och datum, iteration samt ett unikt certifikat-ID. Skrivare, papper och pappersyta, bläck, drivrutin/RIP, mediaval, utskriftskvalitet, utskriftsprogram, färghantering, torktid och övriga skrivarinställningar hämtas från projektdefinitionen. Saknade uppgifter visas som **Ej angivet**; de gissas inte.

Den levererade profilens SHA-256 identifierar exakt vilken ICC-fil resultatet gäller. Träningsfel och resultat från kontrollutskriften redovisas separat. Mätvillkor, eventuell FWA/OBA-kompensation, källunderlag, bedömning och historik följer med. Certifikatet redovisar underlaget; det innebär inte ackreditering, kalibreringscertifiering av instrumentet eller automatisk ISO-överensstämmelse.

## Fysisk återgivningsförmåga och resultatets gränser

Resultatet med en ICC-profil är beroende av vad kombinationen **skrivare, papper och bläck** fysiskt kan återge. Papperets vithet, yta och optiska vitmedel, bläckets egenskaper samt skrivarens och drivrutinens inställningar begränsar färgomfång, svärta, kontrast och tonåtergivning.

En ICC-profil beskriver denna kombination och hjälper färghanteringen att återge färger inom dess förmåga. Den kan inte skapa färger eller kontrast som material och utrustning inte kan återge. Det finns därför en fysisk gräns för hur nära en önskad referens utskriften kan komma. Färger utanför färgomfånget behöver anpassas.

Fler mätpunkter eller ytterligare profiliterationer garanterar inte ett bättre resultat. Uppmätta avvikelser påverkas även av utskriftsstabilitet, torktid, mätvillkor och betraktningsljus. Resultatet gäller de dokumenterade villkoren; ändringar kan kräva ny profilering och verifiering. Detta förklaras även i PDF-, HTML- och textversionen av mätcertifikatet.

## Ansvar för utrustningens och materialens begränsningar (liability)

Utföraren av profileringen ansvarar inte för avvikelser som enbart beror på inneboende, fysiska begränsningar hos den aktuella kombinationen skrivare, papper och bläck, förutsatt att uppdraget i övrigt har utförts fackmässigt och enligt avtal. En ICC-profil innebär inte någon utfästelse om återgivning av färger, svärta, kontrast eller tonomfång utöver denna kombinations faktiska förmåga. Denna ansvarsbegränsning omfattar inte fel i utförarens eget arbete, bristfälliga instruktioner eller rekommendationer, avvikelser från uttryckligen avtalade åtaganden eller ansvar som följer av tvingande lag.

Även denna ansvarsfördelning bör ingå i uppdragsavtalet före arbetets början och behöver bedömas utifrån uppdraget och tillämplig lag. Den är ingen garanti för att varje ansvarsbegränsning kan göras gällande.

## Beställarens utskrifter och uppgifter

Följande text finns i PDF, HTML, text och JSON:

Om beställaren (uppdragsgivaren) har skrivit ut målbilderna ansvarar beställaren för att utskrifterna har utförts enligt lämnade instruktioner och för att samtliga lämnade uppgifter är korrekta och fullständiga. Detta omfattar bland annat skrivare, papper, bläck, drivrutins- och färghanteringsinställningar, skalning, torktid samt hantering av utskrifterna. Utföraren av profileringen ansvarar inte för beställarens utskriftsarbete eller för fel i profil eller resultat i den mån dessa orsakas av brister i beställarens utskrifter eller av felaktiga eller ofullständiga uppgifter från beställaren. Mätcertifikatet redovisar resultatet för det mottagna underlaget; det innebär inte att utföraren har verifierat beställarens utskriftsprocess eller uppgifter. Denna ansvarsfördelning begränsar inte utförarens ansvar för egna fel, bristfälliga instruktioner eller skyldigheter enligt tvingande lag.

Ansvarsfördelningen bör göras till en del av uppdragsavtalet och lämnas till beställaren före uppdragets början. Att texten finns i ett efterföljande mätcertifikat, eller att utföraren undertecknar certifikatet, visar inte i sig att beställaren har accepterat ett avtalsvillkor. Texten är ett generellt avtalsunderlag och behöver bedömas för det aktuella uppdraget; den är ingen garanti för juridisk giltighet. Vid behov bör villkoret granskas av jurist, särskilt vid konsumentuppdrag.

Avgränsningen mot tvingande lag och utförarens egna fel är avsiktlig. Konsumentverket beskriver att villkor som begränsar konsumentens lagliga rättigheter vid näringsidkarens avtalsbrott kan vara oskäliga. Se [Konsumentverkets exempel på oskäliga avtalsvillkor](https://www.konsumentverket.se/marknadsratt-foretag/exempel-pa-oskaliga-avtalsvillkor-for-foretag/) och [lagen om avtalsvillkor i konsumentförhållanden](https://www.riksdagen.se/sv/dokument-och-lagar/dokument/svensk-forfattningssamling/lag-19941512-om-avtalsvillkor-i_sfs-1994-1512/) (kontrollerat 2026-10-02).

## Datum och underskrift på papper

PDF-filen har dokumentdatum, användare och sidnummer med totalt sidantal i sidfoten. Sista sidan innehåller projekt, certifikat-ID, dokumentdatum och profilens SHA-256 samt plats för **ort och datum, underskrift, namnförtydligande och organisation/roll**. Signeringsdatum fylls i för hand och kan skilja sig från dokumentdatum.

Underskriften bekräftar att undertecknaren har granskat dokumentets förutsättningar, resultat och begränsningar. InkProf skriver inte under åt användaren. JSON-filen anger `signature.status = unsigned`; en underskrift på papper uppdaterar inte automatiskt appen och är ingen digital signatur.

## Arbetsgång och leverans

1. Kontrollera uppgifterna i **Project details** före profilering och leverans.
2. Slutför profilering, kontrollmätning och bedömning.
3. Välj **Save ICC and measurement certificate**. Välj egna filnamn och platser för ICC och certifikat.
4. Öppna dokumentet med **Open certificate**, granska PDF-filen, skriv ut och signera sista sidan.
5. Lämna över ICC-filen tillsammans med mätcertifikatet. HTML-versionens tillhörande resursmapp måste följa med om HTML lämnas över.

Äldre exporter skrivs inte om automatiskt. Kör leveranssteget igen för ett nytt certifikat. Interna `final-report.*`-filnamn och JSON-typen `inkprof.final-report` behålls för kompatibilitet med befintliga projekt. Det synliga dokumentnamnet är **Mätcertifikat**. Appens föreslagna externa filnamn är `measurement-certificate.pdf`.
