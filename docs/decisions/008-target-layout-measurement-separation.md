# 008 – Patchdefinition, utskriftslayout och mätresultat

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Datum: 2026-09-26. Status: beslutad specifikation. Beslutet beskriver önskat beteende; formatstöd och fysisk kompatibilitet måste verifieras separat.

## Grundprincip

InkProf bestämmer standarden för mål som InkProf skapar. InkProf ska samtidigt kunna analysera mätresultat från andra utskrifts- och mätprogram. En patchdefinition, en fysisk utskriftslayout och ett mätresultat är tre olika slags information.

## Formatstöd och bevarande av ursprunglig layout

InkProf ska hantera samtliga format som ingår i projektets formatspecifikation, utifrån vad varje fil faktiskt innehåller: patchdefinition, utskriftslayout, mätdata eller en kombination. Detta omfattar bland annat PXF, TXF, MXF/CMXF, TI1/TI2/TI3, relevanta CGATS-varianter och TIFF-baserade mål. InkProfs egen utskriftsstandard är inte ett villkor för import eller analys. Målet om formatstöd innebär inte att varje adapter eller dialekt redan är implementerad och verifierad.

Vid import ska originalfilen och dess beskrivning av hur målet såg ut vid mätningen bevaras: patchidentiteter, styrvärden och kanalbeskrivning, ordning, sid-/rad-/kolumnindelning, koordinater, patchmått, orientering, utfyllnad och markörer där uppgifterna finns. Mätningar ska förbli knutna till denna ursprungliga layout. Saknade eller motsägande uppgifter ska redovisas; de får inte ersättas tyst med InkProfs standardvärden.

## Import av patchdefinitioner och skapande av nya utskrifter

Import och omlayout är separata operationer. Import av en stödd PXF, TXF, TI1 eller CGATS-definition ska bevara tillgängliga originaluppgifter i intern JSON och arkiverad källfil. Importen får inte i sig ändra ordningen, lägga till kontrastmarkörer eller omtolka ett redan uppmätt mål som en ny InkProf-layout.

När användaren väljer att skapa ett nytt RGB-mål från definitionen får InkProf skapa en egen layout enligt [utskriftsstandarden](../usage/target-print-standard.md). Den nya layouten ska vara en separat version med spårbar koppling till originalets patchidentiteter och RGB-värden. Ursprunglig layout och tidigare mätningar ska bevaras.

Om patcharna randomiseras (scrambling) ska den exakta permutationens koppling mellan identitet, rad, kolumn och sida följa med i JSON och relevanta mätfiler, exempelvis TI2. Upprepade RGB-värden får inte användas som enda identitetsnyckel. Den aktuella RGB-begränsningen för att skapa nya mål ska inte användas för att tyst kassera kanaler eller metadata i importerade dokument; färgmodeller som en viss analys ännu inte stöder ska rapporteras uttryckligen.

## Kontrastmarkörer vid radmätning

Kontrastmarkörer ska vara standard i nya InkProf-mål avsedda för radmätning, även om det senare mätprogrammet är i1Profiler. De ska beskrivas som en del av layouten och vara förenliga med det valda instrumentets mätunderlag. De är avgränsningar, inte källpatchar eller färgprov för profilberäkningen. Utfyllnad är en separat kategori.

Stöd för kontrastfält i ett utskriftsformat innebär inte automatiskt stöd för samma layout i ett annat mätprogram. Varje adapter måste verifiera mottagarens layouttolkning. I Argyll-flödet ska TIFF och TI2 genereras som ett sammanhängande paket med samma spacerinställningar; godtyckliga färgfält får inte läggas till i bilden efteråt.

## Import av mätresultat

En stödd MXF ska kunna importeras till den interna mätmodellen och analyseras på samma principiella sätt som TI3 eller annan stödd mätdata. Det kräver inte att utskriften skapades av InkProf eller innehöll kontrastmarkörer: mätningen är redan utförd.

Importen ska kontrollera och bevara:

- Patchidentitet och entydig koppling till RGB-styrvärden; sida och position när de behövs för identifieringen.
- Spektra, våglängder, enheter och skala, utan tyst ersättning med enbart XYZ/Lab.
- Mätvillkor såsom M0/M1/M2, instrument och tillgänglig mätgeometri. Olika villkor hålls åtskilda; okända uppgifter förblir okända.
- Originalfil, ursprung, saknade eller duplicerade mätningar och eventuell begränsning i formatadaptern.

Om patchkopplingen inte kan fastställas ska det rapporteras; värden får inte tyst tilldelas patchar genom antagen ordning. Filändelsen MXF är inte ensam ett löfte om stöd för varje variant. Analysens kvalitet beror också på mätningens kvalitet, inte bara på att filen kan läsas.

## TIFF-bilder och fysisk radmätning

En TIFF-bild beskriver bildpixlar och kan innehålla upplösning och annan metadata, men är inte automatiskt en fullständig patchdefinition eller mätfil. InkProf ska läsa tillgänglig information och koppla bilden till dess tillhörande definition där sådan finns. Patchidentiteter, mätvillkor eller spektraldata får inte hittas på utifrån bilden. Om bildbaserad patchidentifiering behövs ska den redovisas som härledd och verifieras mot definitionen eller användarens uppgifter.

Den praktiska läsbarhetsbegränsning som observerats gäller instrumentets radmätning av ett utskrivet mål, inte en generell begränsning av import av externa filformat. Snarlika intilliggande patchar kan göra gränser svåra att identifiera. Scrambling kan minska risken genom att ändra grannskapet, men slumpning garanterar inte tillräcklig kontrast mellan varje par. Kontrastmarkörer behålls som stöd i nya InkProf-mål för radmätning.

Scrambling eller tillagda kontrastmarkörer kräver en ny fysisk utskrift och matchande layout-/mätunderlag. De får inte användas för att i efterhand ändra definitionen för ett befintligt ark eller dess mätningar. Redan utskrivna externa mål ska hanteras enligt sin faktiska layout. Om radmätning av ett sådant ark är problematisk kan det mätas i ursprungsprogrammet och resultatet importeras, eller ersättas av en separat ny utskrift från samma patchdefinition.

## Erfarenhet från i1Pro 2-provet

Sessionen `matning-A4-20260926-123236` omfattade 143 källpatchar och fyra utfyllnader på sju rader, med kontrastmarkörer. Alla rader accepterades och samtliga källpatchar kunde importeras. Användaren förklarade första radens omsvep med att arket satt för långt till höger i släden. Detta ska inte redovisas som ett fel i patchigenkänningen.

Centrering behövs praktiskt för utrymme att börja och avsluta svepet på papper. Kontrastmarkörerna behålls även eftersom användaren har erfarenhet av liknande avläsningsproblem i i1Profiler. Provet visar ett fungerande fall, inte en generell garanti eller ett isolerat bevis på varje layoutändrings effekt.

## Implementationsstatus och acceptans

RGB-patchimport, Argyll-kontrastfält och TI3-import finns. En generell MXF-adapter och mottagarverifiering ska inte betraktas som färdiga enbart för att enskilda MXF-filer har analyserats med hjälpskript.

Vid detta beslut är `createTarget` fortfarande förvalt till `SpacerMode="auto"`; kontrastprovet använder uttryckligen `SpacerMode="colored"`. Den fasta 29 × 20-mallen saknar kontrastfält. Att göra kontrastmarkörer till förval i samtliga radmätningslayouter återstår att genomföra enligt denna specifikation.

Acceptans kräver dels verifierad TIFF/layout/patchkoppling, dels fysisk radmätning av det valda flödet. För mätimport krävs verifiering mot verkliga formatvarianter och bevarade data/metadata. Dessa kontroller ska redovisas separat.
