# ICC-läsare A1

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Implementerad 2026-09-27. MATLAB Base använder InkProfs valda Python. Läsaren kräver endast Pythons standardbibliotek.

```matlab
cd('/Users/christer/Desktop/InkProf')
setupInkProf();
[profile, jsonFile] = inkprof.readICC();
```

Välj en `.icc` eller `.icm`. Fönstret visar beskrivning, version, klass, enhetsfärgrymd, PCS, taggar och varningar. Avbryt i filvalet ger inget resultat och sparar inget.

Skriptanvändning:

```matlab
[profile, jsonFile] = inkprof.readICC('min-profil.icc', ...
    OutputFolder='mitt-projekt/profiles/inspections', ShowDialog=false);
```

Originalprofilen ändras inte. En unik JSON sparas under projektets `profiles/inspections` om källan ligger i ett InkProf-projekt, annars under `projects/icc-inspections`. `OutputFolder` kan anges uttryckligen. Finns ett projektmanifest där resultatet sparas uppdateras det. Utanför projektet är resultatet fristående. Originalets sökväg och SHA-256 finns i JSON; A1 kopierar inte själva profilen. Oförändrad profilimport/Spara som hör till A2.

Stöd: ICC v2/v4-huvud, taggförteckning, desc/mluc/text/XYZ. Övriga typer redovisas men avkodas inte. Delade dataintervall tillåts; trunkerade profiler, felaktiga katalogintervall, duplicerade signaturer och partiell överlappning avvisas. Fel i en avkodad tagg visas som varning. Profiler större än 256 MiB avvisas av en uttrycklig resursgräns.

`rgbOutputCandidate` anger klass prtr, RGB och Lab/XYZ PCS. Det är inte ett godkännande för profilering. Ingen LUT-utvärdering, full ICC-konformitetskontroll eller kvalitetsbedömning utförs. Icke-RGB kan inspekteras. ICC-profil-ID redovisas men dess checksumma verifieras inte.

Verifiering: nio Python-felhanterings-/formatprov, MATLAB-integration inklusive dialog, samt tre lokala Epson 3880-profiler (2.1/2.4/4.2) med beskrivningar jämförda mot LittleCMS. Ingen instrumentmätning behövs.

## A2 – import och Spara som

A1 godkändes av användaren 2026-09-27. A2 lägger till knapparna **Import into project** och **Save copy as…** i samma fönster.

Importera till ett befintligt InkProf-projekt. Om ett nytt behövs skapas det först:

```matlab
paths = inkprof.paths();
project = inkprof.createProject(fullfile(paths.Projects,'mina-profiler'));
[profileFile, record] = inkprof.importICC('', project);
```

Tom källsökväg öppnar filval. `inkprof.importICC()` låter även användaren välja projektmapp. Avbryt lämnar projektet orört. Importen får en unik undermapp under `profiles/imported` med originalets filnamn och `inspection.json`. Kopian valideras före publicering, hash jämförs med källan och manifestet uppdateras. JSON använder en relativ källsökväg och bevarar ursprunglig sökväg som proveniens. Ingen automatisk konvertering eller profilredigering görs; även okända taggar bevaras byte för byte.

```matlab
[savedFile, receipt] = inkprof.saveICC(profileFile);
```

Det öppnar Spara som. Filnamnsbyte ändrar inte profilens interna beskrivning. En befintlig destination kräver bekräftelse. I skript används en uttrycklig sökväg och vid avsiktlig ersättning `Overwrite=true`. Ursprung och destination får inte vara samma fil. Felaktig källprofil avvisas innan en befintlig destination ersätts.

Efter kopiering kontrolleras SHA-256. Om källan hör till ett projekt sparas ett exportkvitto under `profiles/exports`, med destination, hash och tid, och manifestet uppdateras. Exportkvittot dokumenterar exporttillfället; det övervakar inte senare förändringar av externa filer.

A2:s integrationstest kontrollerar import, hashidentisk export, skydd mot oavsiktlig ersättning, ogiltig källa, manifestlänk samt att den importerade profilen går att hitta efter flytt av projektmappen. Användaracceptans av A2 återstår.
