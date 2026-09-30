# Radigenkänning: i1Profiler, Argyll och ChromIQ

Granskad 2026-09-26. ChromIQ-kod läst på uttrycklig begäran för analys; ingen kod kopierad eller mätmotor utbytt. Lokal revision: 92e6ead0.

## Slutsats för 575-utskriften

Det finns tre separata nivåer: instrumentdrivrutinen delar dragningens rådata i patchar; chartread kopplar patchar till rad/riktning och kontrollerar förväntade färger; Python/MATLAB sköter session och presentation. En förbättring i användargränssnittet innebär inte automatiskt bättre segmentering.

Den sparade mätningen har saknade rader 14-17 och en patchförskjutning på rad 13. M0-referensen från i1Profiler visar mycket svaga spektrala skillnader vid Z/2A på dessa rader. Det är en konkret hypotes för segmenteringsfelet, inte bevis på dess exakta mekanism.

## 1. i1Profiler

Det verkliga MXF-provet visar att dess mätväg klarar samma utskrift. Det kan bero på annan signalbehandling, geometrikunskap, trösklar eller annan insamlingsstrategi. MXF innehåller färdiga spektra och positioner, inte rå tidsserie eller segmenteringsalgoritm. Ingen specifik användarinställning för patchgränströskel har verifierats. Vi kan därför inte säga att en viss inställning går att överföra till Argyll.

## 2. Kontrastfält stöds i Argyll-flödet

printtarg har färgade kontrastfält (-c), svartvita (-b), inga (-n) och skalning av kontrastfälten (-A). Ett praktiskt genereringsprov med installerad ArgyllCMS 3.5.0 lyckades med -ii1 -c -T72 -p320x280 på en kopia av ett 256-patchtarget. TIFF och TI2 skapades. Ingen fysisk mätning av denna provlayout har gjorts.

Det korrekta sättet är att generera ett sammanhängande nytt TIFF/TI2-paket med printtarg eller en noggrant verifierad motsvarighet. Lägg inte bara in godtyckliga breda vita rutor i den gamla TIFF-filen: de kan tolkas som extra patchar och layouten är då ändrad. Kontrastfält kan ta utrymme från patchantal per rad; patcharnas lämpliga storlek och maximal totalbild 320 x 280 mm ska behållas. Den nya bilden måste skrivas ut. Den befintliga i1Profiler-definitionen gäller inte automatiskt för den nya layouten.

Randomisering är ett separat hjälpmedel för större skillnad mellan angränsande patchar, men garanterar inte alla gränser. För detta felsökningsprov är explicit kontrast ett tydligare ingrepp än att enbart blanda om allt.

## 3. ChromIQ har två mätvägar

workflow/measure_manager.py kan starta vanlig Argyll chartread med -v/-c och val för -B/-b (riktning), -S (dölj varningar), -N, -p (punktvis), -H, -r och extra argument. Dess alternativa native/chromiq-chartread är en modifierad chartread med JSON-protokoll, atomisk autosparning per rad, direkt radval och utökad rad-/riktningskontroll även för vissa icke-randomiserade target.

Kod för radidentifiering bedömer om raderna är tillräckligt åtskilda i förväntat Lab och om en rad skiljer sig från sin omvända ordning. Detta sker efter att instrumentdrivrutinen har levererat patchvärden. Det är inte en ny algoritm för att dela rådragningen i patchar.

native/instlib/PROVENANCE.md anger att instrumentbiblioteket kommer oförändrat från ArgyllCMS 3.5.0. SHA256 för i1pro_imp.c börjar 8b8516cdd89e21de, vilket stämmer med inventeringen. Funktionen i1pro_extract_patches_multimeas har separata kriterier för signalövergångar och patchernas interna konsistens. Fel I1PRO_RD_NOTENOUGHPATCHES uppstår här när för få kandidater hittas, före chartreads radidentifiering. Det finns därför inget källkodsstöd för att anta att ChromIQs modifierade chartread i sig löser just detta i1Pro-problem.

ChromIQs layoutkod har också val för färgade/svartvita/inga kontrastfält och fältskalning. Ett lyckat ChromIQ-prov måste därför använda exakt samma TIFF/TI2 om avsikten är att jämföra mätmotorer; en ny layout testar även utskriftens geometri och ordning.

Dess native-mätväg innehåller spektral TI3-sparning. Ett allmänt påstående att ChromIQ inte sparar spektra är alltså för brett; stödet måste bedömas per arbetsflöde.

## Tolerans är inte samma sak som patchgräns

chartread -T skalar toleransen för variation inom en identifierad patch. I den granskade i1Pro-koden är scan_toll_ratio kopplad till patch_cons_thr, medan övergångströskeln beräknas separat. Att höja -T är därför inte en direkt lösning på svaga gränser eller fel patchantal. -S döljer varningar, reparerar ingenting och bör inte användas för att acceptera rad 13. -B kan isolera riktningsval men återställer inte en borttappad patchgräns.

## Föreslagen provordning

1. Bevara nuvarande TI3/MXF och flagga rad 13 som olämplig för profilbygge.
2. Prova diagnostik på samma problemrad med Argyll, utan att undertrycka varningar. Punktmätning via chartread -p är en möjlig separat kontroll av färgvärden när radsegmentering fallerar.
3. Generera ett litet nytt provtarget med problemfärger och Argylls egna kontrastfält. Behåll patchstorlek och mätvillkor och skriv ut i faktisk storlek.
4. Jämför mot layout utan kontrastfält. Om förbättringen upprepas, inför valbar instrumentanpassad kontrastlayout i InkProf.
5. Pröva ChromIQ separat om önskat. Dess autosparning och tydligare händelser är användbara arkitekturidéer även om samma lågnivåfel kvarstår.

## Källor

- Argyll printtarg: https://www.argyllcms.com/doc/printtarg.html (även installerad dokumentation 3.5.0).
- Argyll chartread: https://www.argyllcms.com/doc/chartread.html (installerad dokumentation 3.5.0, avsnitt -T, -S, -B och -p).
- ChromIQ, revision 92e6ead0: workflow/measure_manager.py, workflow/chartread_engine.py, workflow/ti2_relayout.py.
- Samma revision: native/chartread_helper/chromiq_chartread.c samt native/instlib/i1pro_imp.c och PROVENANCE.md.
- Lokal mätanalys: projects/matning-575-20260926-111725/analys-575-20260926.md.
