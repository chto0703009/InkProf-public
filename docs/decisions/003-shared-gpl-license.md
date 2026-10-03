# 003 - Gemensam GPL-licens för InkProf och Camera-41

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Datum: 2026-09-25. Status: beslutat av projektägaren och implementerat.

## Bakgrund

Projektägaren har beslutat att InkProf och Camera-41 ska ha samma GPL-licens för att underlätta återanvändning mellan projekten. Vid kontroll saknade Camera-41 v0.9.0-dev en licensdeklaration. Det fanns därför ingen befintlig versionsangivelse att kopiera.

## Beslut

Båda projektens egen kod och dokumentation ges samma licens: **GNU General Public License version 3 eller senare**, SPDX-identifierare `GPL-3.0-or-later`.

InkProf ska uttryckligen presenteras som ett projekt med **öppen källkod och fri programvara**. Källkoden får studeras, ändras och distribueras enligt GPL-3.0-or-later. Varumärkesreglerna i beslut 005 begränsar inte dessa licensrättigheter; de skiljer projektets egen identitet från sakliga hänvisningar till kompatibla tredjepartsprodukter.

Den fullständiga GPL v3-texten ligger i respektive repos `LICENSE`. README anger uttryckligen möjligheten att välja en senare version. Det skiljer valet från `GPL-3.0-only`.

## Omfattning

- Gäller projektens eget material där ingen annan uttrycklig licens eller rättighetsnotis anges.
- Befintliga rättighetsnotiser ska bevaras när kod flyttas mellan projekten. Kodens ursprung och version ska dokumenteras.
- Tredjepartskod, publikationer, externa data och andra separat licensierade delar får inte omlicensieras genom detta beslut.
- MATLAB och andra externa beroenden behåller sina egna villkor. Detta beslut är inte en bedömning av alla möjliga kombinationer eller distributionsformer.
- Äldre planversioners uppgift om att licensvalet återstår är historisk och ersätts av detta beslut.

## Infört

InkProf: `LICENSE`, README och grundbeslutet uppdaterade.

Camera-41: motsvarande `LICENSE` och README-deklaration införda i den aktuella arbetskopian `Camera-41_v0.9.0-dev`. `.gitignore` tillåter nu licensfilen. Historiska versionsmappar har inte ändrats.

Ingen tredjepartskod har importerats genom licensändringen.

## Källa

Den oförändrade licenstexten har hämtats från [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.txt).

## Relaterat beslut

- [005 - Format- och operationsbaserade namn i publikt API](005-format-based-public-api.md)

## Förtydligande 2026-09-26

Samma licensval innebär inget körberoende till Camera-41 eller SpectraLab. InkProf installeras och versionshanteras självständigt enligt [beslut 007](007-independent-inkprof.md). Återanvänd kod kräver dokumenterat ursprung och bevarade licensnotiser.

## Löpande rättighetskontroll 2026-09-27

Projektägaren kräver att även övriga rutiner och beroenden hanteras med respekt för upphovsrätt och korrekt attribution. [Tredjepartsnotiser](../../THIRD_PARTY_NOTICES.md) och [versions-/hashinventering](../../licenses/inventory.json) dokumenterar granskade paket. Nya eller anpassade rutiner ska ha identifierat ursprung, kontrollerad licens och bevarade copyrightnotiser. En copyrightnotis ersätter inte tillstånd eller skyldigheter att tillhandahålla källkod. Oklarheter ska dokumenteras och lösas före relevant distribution.

Installerad ArgyllCMS 3.5.0 anger AGPLv3, inte enbart GPL. MATLAB förblir ett separat proprietärt beroende. Den konkreta distributionsformen måste bedömas; denna notis lämnar ingen generell garanti om intrångsfrihet.
