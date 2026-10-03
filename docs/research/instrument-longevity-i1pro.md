# Projektmotivering: fortsatt användning av i1Pro och i1Pro 2

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Dokumenterat 2026-09-25 utifrån X-Rites egna supportuppgifter.

## Varför detta motiverar InkProf

X-Rite har tagit bort stödet för äldre spektrofotometrar i senare versioner av i1Profiler. Ett instrument kan därmed fortfarande vara användbart för mätning men sakna stöd i den aktuella tillverkarprogramvaran. Att behålla en äldre programversion kan i sin tur binda användaren till äldre operativsystem och drivrutiner.

InkProf ska ge en alternativ, dokumenterad väg för mätning, analys och ICC-profilering med ArgyllCMS och InkProfs egna rutiner. Syftet är att förlänga den praktiska användningstiden för fungerande instrument, tillvarata befintliga investeringar och minska beroendet av en enskild leverantörs programlivscykel. Öppna dataformat och bevarade originalmätningar gör resultaten lättare att återanvända när program eller datorer byts.

## Verifierade uppgifter

| Instrument | X-Rites uppgift | Källa |
|---|---|---|
| Första generationens i1Pro, revision A-D | Stödet togs bort från i1Profiler 3.2.0. X-Rite hänvisar till 3.1.1 för fortsatt användning i kompatibel miljö. | [X-Rite: i1Pro 1 Support Dropped in i1Profiler 3.2.0](https://www.xrite.com/de/service-support/i1pro1supportdroppedini1profiler320) |
| i1Pro 2 och i1iO 2 | Versionsinformationen för i1Profiler 3.8.7 anger att instrumenten inte längre stöds. | [X-Rite: i1Profiler 3.8.7](https://www.xrite.com/it-it/service-support/downloads/i/i1profiler-i1publish_v3_8_7) |
| i1Pro 2 / iO2 på macOS | X-Rites kompatibilitetsnotering anger 3.8.6 som sista i1Profiler-version med stöd. | [X-Rite: i1Pro 2 EOL Notes](https://www.xrite.com/pt-pt/service-support/i1pro-2-eol-notes-compatibility-issues-with-windows-11-macos) |

Uppgifterna avser olika instrumentgenerationer och olika programversioner. De ska inte beskrivas som ett gemensamt datum när alla äldre instrument slutade fungera. Befintliga installationer kan fortfarande vara användbara i kompatibla miljöer.

## Vad InkProf behöver verifiera

ArgyllCMS dokumenterar hantering av Eye-One Pro och i1Pro 2 i sin [instrumentdokumentation](https://www.argyllcms.com/doc/instruments.html). Det ger en teknisk grund för fortsatt användning, men är inte ett genomfört kompatibilitetstest av InkProf.

För varje stödd kombination ska instrumentmodell/revision, operativsystem, Argyll-version och mätläge registreras och provas. Både punktmätning och radmätning ska verifieras där de ska erbjudas. Instrumentets kalibrering, repeterbarhet och skick måste bedömas; alternativ programvara ersätter inte fysisk service eller bevisar mätkvalitet.

Kopplingen mellan MATLAB, Python-bryggan och Argyll beskrivs i [arkitekturdokument 002](../decisions/002-matlab-python-chartread.md).
