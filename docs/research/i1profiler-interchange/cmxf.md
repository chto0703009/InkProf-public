# CMXF: i1Profiler Chart Measurements

Datum: 2026-09-25. Status: preliminärt läs-/skrivkontrakt för InkProf.

## Källbelagd roll

`.cmxf` är CxF3-baserade targetmätningar med Lab och/eller spektra, utan patcharnas RGB/CMYK-styrvärden. Layout och en färgrymdsetikett kan ändå finnas som extra information; etiketten ersätter inte styrvärdena. [S4] Se [gemensamma regler, källor och begränsningar](README.md).

## Föreslagen betydelse i InkProf

CMXF importeras som ett mätpaket. Det kan användas för spektral eller kolorimetrisk analys även om det ännu inte är kopplat till en targetdefinition. För att bygga en skrivarmodell behövs separat tillgång till vilka styrvärden som gav respektive mätning.

## Importkrav

- Bevara mätidentiteter, ordning, spektra, kolorimetri och alla tillgängliga villkor.
- Läs layout om den finns, men skilj placering från patchens identitet.
- Koppla till ett separat PXF/TXF/TI1/TI2 eller ett verifierat internt target innan data används för profilering.
- Kontrollera att kopplingen är entydig. Antalet patchar och en liknande visuell färgordning räcker inte som bevis.
- Tillåt analys av okopplade mätningar, men markera att profileringsunderlaget saknar styrvärden.

## Exportkrav

Exportera vald mätmängd och dokumentera dess targetkoppling i projektet eller ett följe-manifest. Om målvarianten inte kan bära alla mätvillkor ska dessa delas eller väljas uttryckligt med förlustrapport.

Skriv inte RGB/CMYK-styrvärden i CMXF för att försöka göra formatet till MXF. Använd i stället en verifierad MXF-export när mottagaren behöver både styrvärden och mätningar. Exakta layoutresurser och krav på färgspecifikation måste provas mot mottagarversionen.

## Vad kan och kan inte återställas?

CMXF + korrekt targetkoppling kan ge underlag för TI3 eller MXF. CMXF ensam räcker normalt inte. En transformation från Lab till RGB med en ICC-profil ger en möjlig färgreproduktion, inte bevis för vilka RGB-värden som ursprungligen skrevs ut. Sådana beräknade värden får inte presenteras som ursprungliga styrvärden.

Om MXF exporteras till CMXF försvinner styrvärdenas plats i själva mätfilen. Återställbarheten beror då på att originalet eller en separat targetdefinition och ID-karta finns kvar.

## Verifieringsfall

Prova samma mätpaket med korrekt, saknat och avsiktligt felaktigt target. Bara den verifierade kopplingen ska kunna användas för profilering. Prova dessutom flera mätvillkor och en fil där enbart kolorimetri finns; frånvaron av spektra ska förbli synlig.

## Praktisk granskning av i1Profiler 3.8.5

Se [verifieringsrapporten](ui-verification-3.8.5.md) för observerade menyval, utförd MXF-import, spektral CGATS-export och TIFF-export. Rapporten skiljer utförda prov från återstående format- och layoutverifiering.
