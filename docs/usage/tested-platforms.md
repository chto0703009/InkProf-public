# Testade plattformar / Tested platforms

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

## Svenska

**InkProf har testats på macOS. Programmet och dess arbetsflöde har inte testats på Windows eller Linux.**

MATLAB och Python finns för macOS, Windows och Linux. Det innebär inte att InkProf fungerar eller är verifierat på samtliga plattformar. Även ArgyllCMS, instrumentkommunikation, drivrutiner, filvägar och dialoger behöver fungera tillsammans och provas i respektive miljö.

Den interaktiva mätbryggan använder POSIX-funktioner. Linux är inte testat även om delar av implementationen är avsedda för POSIX-system. Instrumentmätning på Windows kräver dessutom en anpassad konsollösning och verifiering med instrumentet.

Exempel på Windows- eller Linux-kommandon i dokumentationen är inte belägg för att InkProf har testats där. macOS-testningen innebär inte att varje version av macOS eller varje instrumentmodell har verifierats.

## English

**InkProf has been tested on macOS. The application and its workflow have not been tested on Windows or Linux.**

MATLAB and Python are available for macOS, Windows and Linux. Their availability does not establish InkProf compatibility or validation on those platforms. ArgyllCMS, instrument communication, drivers, file paths and dialogs must also work together and be tested in each environment.

The interactive measurement bridge uses POSIX features. Linux remains untested even where the implementation targets POSIX systems. Windows instrument measurement additionally requires an adapted console transport and instrument testing.

Windows or Linux command examples in the documentation do not imply that InkProf has been tested there. Testing on macOS does not mean that every macOS version or instrument model has been verified.
