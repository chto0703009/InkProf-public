# Import av mätfil inför analys och profilering

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

Status: grundflöde implementerat 2026-09-27. `inkprof.importMeasurement`
öppnar filval för TI3/MXF och använder samma interna mätmodell och
punktmätningsrevisioner. Begränsningar och kvarstående verifiering anges nedan.

## Varning: MXF kan behöva kompletterande uppgifter

**En importerad MXF kan innehålla kompletta mätvärden men ändå sakna uppgifter som behövs för en spårbar och reproducerbar profilering.** Kontrollera och komplettera vid behov:

- Skrivarmodell och exakt pappersprodukt; Glossy/Matte anger bara pappersytan.
- Drivrutin/version, medietyp, utskriftskvalitet och relevanta utskriftsalternativ.
- Utskriftsprogram och färghantering: om utskriften var utan profilkonvertering eller vilken profil som applicerades och hur.
- Mätvillkor, instrument och kalibreringsstandard när dessa inte framgår entydigt.

Saknade uppgifter ska redovisas som **unknown**, inte fyllas i genom antaganden. Generiska eller motsägelsefulla metadatafält ska inte behandlas som bekräftade utskriftsinställningar. Kompletteringar ska avse den faktiska utskrift som mättes, inte en senare utskrift eller programmets nuvarande standardval.

Dokumentationskrav: användarens kompletteringar ska sparas i JSON med tydligt ursprung som användaruppgift, åtskilda från källfilens metadata. Original-MXF och tidigare mätvärden ska bevaras oförändrade. Fullständigt patchantal är inte i sig bekräftelse på fullständig utskriftsproveniens.

I nuvarande arbetsflöde granskas uppgifterna i B1 och utskriftsuppgifter kompletteras i [B2:s receptdialog](profile-recipe.md). Dessa tillägg gäller det nya receptet och ändrar inte det låsta B1-underlaget. Kravet ovan beskriver också önskad tydlighet i importdialogen; denna dokumentationsändring inför ingen ny dialogfunktion.

## Användaren väljer mätfilen

InkProf ska låta användaren välja en mätfil, normalt **TI3 eller MXF**.
Användaren ska inte behöva hitta eller ange en JSON-fil. JSON är InkProfs
interna datamodell och skapas efter validerad import.

**TI2** beskriver normalt targetets patchdefinition och layout, inte den
utförda mätningen. En TI2 kan användas som kompletterande targetunderlag.
Om användaren väljer en TI2 utan mätdata ska programmet förklara detta och
be om mätfilen. Filändelsen ensam är inte bevis på filens innehåll.

## Kontroll före import

InkProf ska kontrollera:

- Att filen går att tolka och att innehållet motsvarar ett stött format.
- Att styrvärdena är RGB. CMYK ska rapporteras som fel färgformat för InkProf.
- Patchantal, identiteter, dubbletter och koppling mellan styrvärden och
  mätvärden. Upprepade RGB-värden är tillåtna men får inte användas som
  ensamma unika identiteter.
- Att uppmätta spektra och/eller XYZ/Lab finns, med deklarerade eller
  verifierbart härledda skalor och numeriskt giltiga värden. Reflektans över
  100 procent får inte klippas automatiskt; orsak och mätvillkor måste beaktas.
- Våglängder, spektralintervall och tillhörande färgspecifikationer.
- Mätvillkor såsom M0/M1/M2, instrument och kalibreringsstandard när dessa
  finns. Saknade eller härledda uppgifter ska redovisas som sådana.
- Patcharnas ordning, koordinater och sidindelning när dessa finns i källan.
  Saknad layout får inte ersättas med en gissning om hur utskriften såg ut.
- Överensstämmelse med projektets target, om ett sådant finns: patchidentitet,
  RGB och tillgänglig fysisk layout. Vid olika layouter krävs en verifierad
  koppling mellan definitionerna.

Flera mätvillkor eller upprepade mätningar ska bevaras separat och identifieras.
Programmet får inte tyst välja den första gruppen eller medelvärdesbilda dem.
Misstänkt omvänd rad ska ge en diagnos, inte automatisk omordning av mätdata.

## Resultat i importfönstret

Fönstret ska visa källfil, format, antal patchar, tillgängliga mätvärden,
mätvillkor och resultat av targetmatchning, samt fel och varningar.

Om filen innehåller tillräckliga och entydiga targetuppgifter ska ingen extra
fil krävas. Saknas nödvändiga uppgifter ska användaren få välja en
kompletterande targetfil, exempelvis TI2. En tvetydig patchkoppling ska stoppa
importen som användbart profileringsunderlag tills den har lösts.

En lyckad import betyder att data har tolkats och kopplats korrekt. Det är
inte ett bevis på mätkvalitet eller på att en ICC-profil blir korrekt.
Olösta kvalitetsvarningar ska följa med till senare analys och profilering.
Alla texter i det implementerade användargränssnittet ska vara på engelska.

## Intern JSON och spårbarhet

Efter godkänd import ska InkProf spara data i projektets gemensamma interna
JSON-modell och uppdatera projektmanifestet. Följande ska bevaras:

- Originalfil och dess hash, ursprungligt filnamn och källsökväg.
- Styrvärden, mätvärden, skalor och en explicit patchkoppling.
- Källans ordning, koordinater, sidor och metadata, inklusive papperstyp.
- Mätvillkor och instrumentuppgifter, med skillnad mellan rapporterat,
  härlett och okänt.
- Importörens version, importtid, valideringsresultat och varningar.
- Eventuella transformationer, exempelvis skalomräkning, med spårbarhet till
  originalvärden. Okänd metadata ska bevaras utan att kallas verifierad.

Originalfilen ska inte ändras. Användaren fortsätter arbeta med projektet och
mätningen; JSON behöver inte exponeras som obligatoriskt filval.

## Verifiering

TI3 → JSON och MXF → JSON ska verifieras mot kända referensfiler, med kontroll
av samtliga patchkopplingar, RGB-värden, spektra och relevant metadata.
Testerna ska även täcka dubblettfärger, omordnade objekt, flera mätvillkor,
saknade uppgifter och felaktiga kopplingar.

Det lyckade importprovet av InkProfs exporterade MXF i i1Profiler verifierar
inte ensamt den omvända importkedjan MXF → JSON. Den kräver egna tester.

Se även [MXF-formatet](../research/i1profiler-interchange/mxf.md) och
[kontroll av svepriktning](row-direction-check.md).

## Körning i MATLAB

```matlab
cd('/Users/christer/Desktop/InkProf')
paths = setupInkProf();
[result, measurementFile, sessionFolder] = inkprof.importMeasurement();
```

Välj TI3 eller MXF. Färgkartan öppnas efter import; markera en patch och välj
ommätning på samma sätt som för InkProfs egna mätningar. `measurementFile`
returneras för skriptbruk men behöver inte väljas av användaren.

Med angivna filer, utan förhandsvisning:

```matlab
[result, measurementFile, sessionFolder] = inkprof.importMeasurement( ...
    'measurement.ti3', TargetFile='printed-target.ti2', ShowPreview=false);
```

TI3 kräver matchande TI2; intilliggande TI2 hittas automatiskt och kontrolleras.
I det interaktiva flödet öppnas ett kompletterande filval om ingen finns.
`SessionFolder` kan anges; den måste vara ny. Annars skapas en unik mätmapp
i källans InkProf-projekt, eller under den konfigurerade projektkatalogen.
Projektmanifestet uppdateras när importen ligger i ett registrerat projekt.

## Implementerad MXF-variant och ommätning

Den första adaptern stöder RGB CxF3/Prism med reflektansspektra, explicita
Page/Row/Column och deklarerad spektralspecifikation. RGB 0–255 omvandlas till
procent, reflektansfaktorer till procent utan klippning eller omsampling.
XYZ beräknas med InkProfs dokumenterade D50/2°-integration; ursprungliga
färgvärden och metadata bevaras i originalfilen och objektens XML i JSON.

Varje mätgrupp måste ha en entydig positionskoppling till targetet. Ingen
matchning görs enbart på färg eller objektens ordning. Käll-ID, namn, fysisk
sida/rad/kolumn och den interna ID-kopplingen sparas. Sidornas radnummer
översätts till InkProfs globala radnummer; originalsidan bevaras. Tomma
layoutpositioner markeras som presentationsutfyllnad, inte uppmätta patchar.

Om flera M-villkor finns måste `Condition="M0"`, `"M1"` eller `"M2"` anges
uttryckligen. Andra grupper bevaras i originalfilen och som separat käll-XML
i importinformationen; de blandas inte med den valda mätningen.

MXF utan säker layout, blandade spektralnät/kalibreringsstandarder eller enbart
kolorimetriska värden avvisas i denna första adapter med ett felmeddelande.
Kompletterande layoutmatchning för sådana MXF-varianter återstår; programmet
ska inte gissa. Den konverterade TI2-filen beskriver importlayouten, men är
inte en verifierad instruktion för att skanna om hela det externa targetet.

Punktommätning stöder för närvarande i1Pro 2, M0 utan FWA och kompatibel
kalibreringsstandard/våglängdsuppsättning. Känt serienummer måste stämma.
Andra importer kan analyseras men får inte punktmätas med denna M0-rutin.
TI3 med okänt mätvillkor förblir okänt; ett uttryckligt `Condition`-val loggas
som användaruppgift och får inte motsäga källans rapporterade villkor.

Efter **Accept replacement** sparas en ny JSON-revision och en uppdaterad
TI3 som kan användas som mätunderlag för Argylls ICC-generering. Original-MXF,
original-TI3 och tidigare revisioner bevaras. Korrekt filformat ersätter inte
granskning av kvarstående mätvarningar före profilering.

Automatiserade tester använder syntetiska spektra och simulerad ommätning;
de kontaktar inte instrumentet. Tester täcker dubbeluppsättningar av RGB,
omordnade objekt, flera sidor, villkorsval, felaktiga koordinater och skalor,
serienummerkontroll, enskild ersättning samt återimport av den nya TI3-filen.
