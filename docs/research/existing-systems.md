# Granskning av befintliga program

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Datum: 2026-09-24. Kodläsning och begränsade tester; ingen fullständig produktvalidering.

## SpectraLab v1.2.1-dev

Lokalt granskat i `/Users/christer/Desktop/SpectraLab/SpectraLab_v1.2.1-dev`.

- Befintlig mätväg genom Argyll `spotread`.
- Kanoniska spektrala arkiv med identitet och innehållshash.
- Patchsessioner med varierbart antal rader/kolumner; namngiven targetdefinition för ColorChecker Digital SG.
- Reflektans till XYZ/Lab med explicit illuminant och observatör.
- Befintlig CGATS-export saknar device-RGB/CMYK och är inte en komplett profilerings-TI3.
- Historiskt kunskapsunderlag. InkProf ska ha egen implementation utan anrop till SpectraLabs API; se [beslut 007](../decisions/007-independent-inkprof.md).

## Camera-41 v0.9.0-dev

Lokalt granskat i `/Users/christer/Desktop/Camera-41/Camera-41_v0.9.0-dev`.

- Modell för verifierad, läsande import av SpectraLab-data.
- Tydliga beroenden, mätroller och ursprungsreferenser.
- OpenCV-adapter och perspektivgeometri för SG140, inte generell utskriftskarta.
- Det specifika spektrala intervallet 400–730 nm ska inte kopieras som en generell InkProf-begränsning.

## ChromIQ - commit 92e6ead0

Källa: https://github.com/itsab1989/ChromIQ

- Grafiskt arbetsflöde kring Argyll med egna tillägg, exempelvis layout och modifierad kartläsare.
- Betamotorn bygger en modell device → Lab, inverterar modellen och skriver ICC-tabeller.
- Fast använder egen implementation. Bit-exact i RGB/CMYK-gränssnittet går till `colprof`. Maximum accuracy använder egen robust anpassning och korsvaliderad utjämning.
- Tillval omfattar brusmodell, spektral Yule–Nielsen/Neugebauer-hybrid och alternativ gamut mapping.
- Den spektrala hybriden aktiveras inte för vanligt RGB-underlag. Minst 200 patchar krävs i granskad kod.
- ICC v2/v4 kan innehålla samma färgtabeller; versionsnummer innebär inte bättre färgprecision.
- Dokumentationen anger att flerbläcksmotorn inte är verifierad på verklig flerkanalshårdvara. Ett jämförelsetest kräver en mätfil på utvecklarens lokala dator.

### Utförd begränsad kontroll

I ChromIQ kördes:

```text
.venv/bin/python -m pytest -q tests/test_engine_accurate_mode.py -k 'delta_e_2000 or average_endpoints or project_tac or accurate_fit'
```

Resultat: **15 passerade, 13 bortvalda**. Kontrollen omfattade ΔE00, ändpunktsmedelvärden, bläckbegränsning och robust anpassning. Den visar inte fysisk utskriftskvalitet och är inte ett InkProf-test.

## ColorThink 4 och i1Profiler

ColorThink används som förebild för begriplig profilinspektion, färglistor och gamutjämförelse. i1Profiler används som förebild för sammanhängande profileringsflöde och iterativ förbättring, samt möjlig jämförelsemotor. Funktioner varierar med licens och version. Ingen kod eller kommersiell algoritm från produkterna har importerats.

Källor och den fullständiga jämförelsen finns i projektplanen.


## Komplettering 2026-09-25: Mirage och Canon PRO-2600

Mirage visar `High Quality (600x600 dpi, 12-bit)` för PRO-2600. Se [källanteckning, tolkning och originalbild](canon-pro-2600-mirage-12-bit.md). Angivet utskriftsbitdjup ska hållas åtskilt från ICC-tabellprecision och antal bläckpatroner.
