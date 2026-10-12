# InkProf v1.1.0 — stabil källkodsutgåva

Publicerad 2026-10-12. [Hämta v1.1.0](https://github.com/chto0703009/InkProf-public/releases/tag/v1.1.0). [English description](README.md).

InkProf är en MATLAB-app för RGB-skrivarprofilering: färgmål, spektralmätning, ICC-profiler, utskriftsverifiering och spårbar refinement.

## Nytt i 1.1.0

- Skalrefinement placerar nya mätpunkter innanför gamutytan, över hela skalet eller i valda områden. Tjockleken anges som geometriskt ΔE76-avstånd. Förslagen visas före utskrift.
- Alla refinementverktyg samlas på samma ställe. Sparade mål registreras utan att tryckta patchordningar ändras, och appen föreslår nästa steg.
- Certifikat innehåller ColorChecker-rutor. Fullständiga mätlistor och tekniska detaljer finns i en separat PDF-bilaga, även för numerisk leverans i steg 19.
- Tydligare aktivitet, kontroll av RGB-patchar på varje sida och förbättrad HTML-rotation.

## Installation och dokumentation

Detta är källkod, inte en fristående app. Installera MATLAB, Python och ArgyllCMS separat. Se [installationsanvisningen](README.md#install-and-start).

- [Svensk handbok](docs/usage/InkProf-anvandarhandbok-svenska.pdf)
- [Engelsk handbok](docs/usage/InkProf-user-handbook-English.pdf)
- [Svensk presentation](docs/usage/InkProf-presentation-svenska.pdf)
- [Releaseinformation](docs/releases/v1.1.0.md)
- [Validering](VALIDATION.txt)

Appens gränssnitt är engelskt. Testad miljö är macOS; Windows/Linux och alla instrumentlägen är inte kvalificerade. En numerisk kontroll ersätter inte en separat utskrift och mätning. Certifikat är inte ackrediterad certifiering eller intyg om full ISO-överensstämmelse.

Överlämna hela leveransmappen så att HTML-filens underlag, bilder och mätbilaga följer med. Privata projekt, profiler, mätfiler och externa program ingår inte i releasen.

InkProf är fri programvara enligt GPL version 3 eller senare, utan garanti. Se [LICENSE](LICENSE), [licensomfattning](LICENSE_SCOPE.md) och [tredjepartsnotiser](THIRD_PARTY_NOTICES.md).
