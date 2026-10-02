# InkProf - mätcertifikat

Mätcertifikatet är ett överlämningsdokument för en sparad ICC-profil. Det sammanfattar projektets förutsättningar, mätresultat och användarens bedömning för en uppdragsgivare. Det ersätter benämningen slutrapport i appens leveranssteg.

## Projekt och resultat

Certifikatet innehåller projektets namn och ID, projektansvarig, dokumentets användare och datum, iteration samt ett unikt certifikat-ID. Skrivare, papper och pappersyta, bläck, drivrutin/RIP, mediaval, utskriftskvalitet, utskriftsprogram, färghantering, torktid och övriga skrivarinställningar hämtas från projektdefinitionen. Saknade uppgifter visas som **Ej angivet**; de gissas inte.

Den levererade profilens SHA-256 identifierar exakt vilken ICC-fil resultatet gäller. Träningsfel och resultat från kontrollutskriften redovisas separat. Mätvillkor, eventuell FWA/OBA-kompensation, källunderlag, bedömning och historik följer med. Certifikatet redovisar underlaget; det innebär inte ackreditering, kalibreringscertifiering av instrumentet eller automatisk ISO-överensstämmelse.

## FWA/OBA - val och resultat

Certifikatet redovisar faktisk användning av FWA, projektets val, simulerad belysning och profilens tränings- och kontrollresultat (antal patchar, ΔE00-medel, P95 och maximum). Saknad dokumentation markeras som okänd. Resultat för en kompenserad profil är inte i sig bevis för förbättring genom FWA; en kontrollerad jämförelse utan kompensation redovisas inte automatiskt. Se [FWA/OBA](optical-brighteners.md).

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

## Kompakt lista över patchavvikelser

Mätresultat och patchavvikelser samlas i ett färgfokuserat avsnitt utan separat statistiktabell. Den visuella bilagan upprepar inte patchlistan; fullständiga numeriska resultat finns kvar i JSON och textunderlaget.

PDF och HTML visar tre kolumner med färgprov, referens-ID, sida/koordinat, patchtyp och uppmätt ΔE00 mot önskat D50-Lab. Alla unika kontrollpatchar med ΔE00 > 5 tas med och sorteras med störst fel först. Urvalet görs före avrundning; inga poster begränsas till en topp-lista. Färg-, grå- och challenge-patchar ingår. Upprepningar och pappersvit FWA-referens utesluts. Listan sidbryts vid behov. Om inga överskridanden finns anges det uttryckligen; saknat patchunderlag anges som ej bedömbart.

Gränsen är en **ISO-relaterad jämförelsereferens**, inte en generell klassning som ”utanför ISO”. MediaStandard Print 2018, tabell 30, återger ISO 12647-7:2016 med max ΔE00 5 för samtliga fält i Fogra MediaWedge. Andra kriterier och särskilda patchgrupper har andra gränser och färgskillnadsmått. InkProfs eget RGB-kontrollmål är inte denna kontrollkil, och listan bedömer inte fullständig ISO-överensstämmelse. InkProfs grådiagnostik med ΔE00 2 är inte ISO:s gråbalansmått och används inte som urvalsgräns i denna lista.

sRGB-provet beräknas från uppmätt Lab D50 via Bradford-anpassning till D65 och sRGB-kodning. Färger utanför sRGB klipps och märks med *. Hexvärdet sparas och visas som text även om dokumentet skrivs ut utan färg. ΔE00-värdet kommer från C3-mätjämförelsen och beräknas inte från skärmens sRGB-färg. JSON lagrar urvalsgräns, källa, antal bedömda patchar, fel, överskridande och färgdata för varje post.

Källa: [Bundesverband Druck und Medien (bvdm), MediaStandard Print 2018, tabell 30, tryckt sida 50](https://www.medienverbaende.de/fileadmin/user_upload/01_Global/Downloads_PDF_DOC/Downloads_Technik/MediaStandard_Print_2018.pdf), kontrollerad 2026-10-02.

## Instrumentidentitet

Vid mätimport sparas instrumentbeteckning och serienummer i mätningens JSON
(`instrument.model`, `instrument.serialNumber`). Källan dokumenteras; serienummer
från instrumentets utskrift används endast när utskriften är kopplad till
mätningen via SHA-256. Saknade uppgifter anges som okända och motstridiga
serienummer stoppas. Instrumentidentitet är inte ett intyg om kalibrering.

Mätcertifikatets JSON innehåller `instruments.measurement` och
`instruments.c2measurement`, med respektive mätnings kontrollsumma. Beteckning
och serienummer visas separat för profilering och kontroll i PDF, HTML och
text. Äldre mätningar kan använda sin sparade, kontrollsummeverifierade
instrumentutskrift utan att originalmätningen ändras.

Bundesverband Druck und Medien (bvdm) är Tysklands branschorganisation för tryck och medier och utgivare av *MediaStandard Print*. ISO betyder International Organization for Standardization (Internationella standardiseringsorganisationen). Branschpublikationen sammanfattar standardkrav; den ersätter inte själva ISO-standarden.

Se även [förkortningar och begrepp](abbreviations.md).


## Exported ICC filename and display name

External ICC delivery defaults to `<project-name>_<YYMMDD>.icc`. The chosen
filename, without its extension, is also written into the ICC profile description
so colour-managed applications can display the same name. Renaming a file later
in Finder does not update this internal description.

Only the delivery copy is renamed internally. The checked project candidate is
preserved. All ICC tag payloads except the profile description remain byte-identical;
the file structure and ICC v4 profile ID are updated as required. This changes the
file checksum without changing the colour transform tables.

The delivery JSON and external PDF/HTML report identify both the delivered file
and its source candidate, with separate SHA-256 checksums. The portable report
bundle includes the named delivery in `underlag/delivered/` and the original
candidate as `underlag/profile.icc`. Existing exports are not modified retroactively;
export again to obtain the matching filename and internal display name.

In step 14, **Open selected step results → Save ICC and report copies...**
opens the ICC save dialog first, followed by the report destination dialog.
The PDF and HTML choices in the results list open the existing reports.
