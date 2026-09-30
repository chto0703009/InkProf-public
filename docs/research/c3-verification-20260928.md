# C3 – första uppmätta kontrollen, 2026-09-28

**Diagnostiskt resultat; profilen är inte utskriftsgodkänd.**
Utskriftskedjan ska granskas med skärmdumpar. Användaren rapporterar Photoshop
Printer Manages Colors, Absolute Colorimetric och gråat Off i drivrutinen.
Målet hade redan fått profilkonverteringen i InkProf.

Profil: Epson 3880, Glossy, B2A High. ICC SHA256:
`90ac68bb407ceacc1b59edb0e838e76d0d54dcf1218d49ff8ee57d4cb8cc1258`.
Historiskt projektnamn `Canon-575-20260927` anger inte faktisk skrivarmodell.
Mätning: `matning-dialog-20260928-090743-312/measurement-20260928-091102619.json`.
Mål: `Epson3880-Glossy-C2-absolute-128-e0c7a41d-a244-4ce7-b634-169966ff44ee`.

Alla 128 källpatchar matchar ID, RGB och fysisk koordinat. Spektral analys:
Argyll profcheck D50/1931_2 utan FWA, ΔE00 mot önskat absolut Lab.

| Grupp | Antal | Medel ΔE00 | P95 | Max |
|---|---:|---:|---:|---:|
| Alla unika, inklusive challenge | 116 | 2,0593 | 10,0306 | 15,3044 |
| Modellbedömt nåbara, unika | 104 | 1,0732 | 2,1228 | 4,9045 |
| Gråskala | 24 | 0,8140 | 1,3094 | 1,3679 |
| Övriga vanliga färger | 80 | 1,1509 | 2,3058 | 4,9045 |
| Avsiktliga challenge-färger | 12 | 10,6054 | 15,0751 | 15,3044 |

Gråskalan: medel ΔL*=+0,2375, Δa*=+0,3169, Δb*=−0,4134.
Medel uppmätt C*ab=0,5686, max=1,2026. Det antyder en liten genomsnittlig
röd/blå avvikelse; detta är ingen bestämd orsak eller godkännandegräns.

Störst fel bland modellbedömt nåbara: **L4**, ID43, ΔE00=4,9045.
Störst totalt: **N5**, ID113, en challenge-patch, ΔE00=15,3044.
Den senares avvikelse mot profilens förutsägelse är 1,0527: det stora felet
mot önskad färg ska därför inte utan vidare tolkas som dålig modellanpassning.

Tolv upprepade tryckta patchar: medel ΔE00=0,3116, max=0,5082.
Fram-/återsvep: medel ΔE00=0,0777, max=0,2813 (lagrad XYZ-baserad kontroll).
Det stöder god repeterbarhet i denna mätning, inte verifierad utskriftsnoggrannhet.

Analysen är implementerad via `inkprof.checkVerificationTarget`. Fyra Python-
tester täcker referensval, patchidentitet, koordinater/RGB, fullständighet,
upprepningar och hashfel. Verklig MATLAB-körning och GUI-filter är kontrollerade.

Nästa beslut kräver verifierad utskriftskedja och överenskomna acceptansgränser.
Originalmätningen bevaras. Ingen automatisk profiloptimering eller omprofilering
har gjorts; ISSUE-001 om invers och mätbrus förblir öppen.
