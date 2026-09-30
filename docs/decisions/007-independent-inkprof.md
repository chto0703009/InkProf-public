# 007 - Självständigt InkProf

Datum: 2026-09-26. Status: beslutad arkitektur. Ersätter beroendet av SpectraLab i tidigare planer och beslut 006.

InkProf ska kunna installeras och köras utan Camera-41 och SpectraLab. Projektet äger sin chartmodell, sina mätningar, färgberäkningar och sin historik. Ingen sökväg till dessa projekt ska behövas i MATLAB-path, Python-miljö eller lokal konfiguration.

## Ansvar

- **InkProf / MATLAB Base:** import, validering, patchidentitet, layout, intern JSON, analys, export och användarflöde. Egen spektral kolorimetri och patchomläsning byggs inom InkProf.
- **InkProfs Python-brygga:** interaktiv processkommunikation, loggning och livscykel för Argyll. Inga parallella färgberäkningar.
- **ArgyllCMS:** instrumentåtkomst, radmätning med `chartread`, senare punktmätning med `spotread` och profilbygge med `colprof`.

MATLAB Base är basplattform utan obligatoriska tilläggstoolboxar. Python behövs för den interaktiva bryggan, inte för targetgenerering. Den nuvarande bryggan använder POSIX-PTY; Windows-stöd för mätning återstår. Sökvägar konfigureras per dator enligt [Python-anvisningen](../usage/python-runtime.md).

## Data och omläsning

JSON är den auktoritativa interna modellen. Argylls TI1/TI2/TI3 är primära utbytesformat. Vid mätning exporteras JSON till TI2; chartread-resultatet TI3 valideras och läses tillbaka till JSON. Ursprungliga filer bevaras.

En egen kommande omläsningsfunktion ska identifiera patchen med stabilt ID och fysisk position, bevara tidigare mätningar och skapa en ny revision med mätvillkor, tid, orsak och ursprung. Användaren ska kunna godkänna eller avvisa ersättningen. Endast godkända revisioner väljs till analys/export. Radomläsning i chartread och separat punktomläsning är olika arbetsflöden. Endast en instrumentprocess får vara aktiv åt gången.

## Erfarenhet utan körberoende

SpectraLab och Camera-41 är kunskapsunderlag. Eventuell återanvänd kod införlivas och underhålls i InkProf med kontrollerad licens, ursprungsnotis och egna tester. InkProf behåller GPL-3.0-or-later. Samma licens innebär inte gemensam installation eller synkroniserade versioner. ChromIQ är en valfri jämförelseväg; dess källkod ska inte användas för den fortsatta implementationen.

## Implementerat och återstående

Targetflödet och den nya chartread-prototypen har egna implementationer. Prototypen omfattar chart-JSON, TI2-export, interaktiv brygga och TI3-import till separata JSON-resultat. Den är provad med simulerad process och syntetiska mätdata, inte med fysisk mätning.

Egen punktomläsning med godkännande/revisionsval, komplett kolorimetri, mätexport och ICC-flöde återstår. En sparad TI3 eller avslutad process räcker inte som bevis för komplett mätning.

## Godkännande av självständigheten

Installera på en miljö utan de andra projekten. Prova target/import/export och simulerad mätning med endast deklarerade beroenden. Verifiera därefter fysisk kalibrering, radmätning, avbrott, återupptagning och instrumentfrisläppning. Numeriska färgberäkningar ska provas mot oberoende referensdata, inte bara mot ursprungskoden.

## Terminalväg, 2026-09-26

Python äger den interaktiva mätningen genom `startMeasurement`; MATLAB återtar resultatet genom `finishMeasurement`. Chartread hanterar radomläsning, medan InkProf bevarar körningsresultat och kopplingen till chart-JSON. Detta är skilt från den senare egna punktomläsningen. Se [mätanvisningen](../usage/chart-measurement.md).
