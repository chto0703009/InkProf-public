# Roterbar Lab-vy av verifieringsmål

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

`fig = inkprof.showVerificationLab(referenceFile)` öppnar en vanlig MATLAB-figur med rotation och zoom. Input är `verification.json` från ett färdigrenderat C2-paket. Utan argument öppnas filväljare. MATLAB Base räcker.

Punkterna visar `predictedLabD50Absolute`, alltså profilens framåtberäknade Lab efter att respektive profils invers och RGB16-kvantisering använts. De är inte målets önskade Lab eller uppmätta värden. Punktmolnet visar de valda patcharna, inte hela skrivarens gamut eller dess yta.

Axlar: a*, b*, L*. Färgvisningen omvandlar Lab D50 via Bradford till D65 och sRGB. Färger utanför sRGB klipps endast i visningen; koordinaterna ändras inte. Originaldata bevaras. Välj Data Tips i figurens verktygsrad för koordinat, ID och Lab. Rotation är aktiv från start.

`Visible=false` kan användas vid export eller kontroll utan att öppna fönstret. Figurens `UserData` innehåller referensfil, Lab, koordinater, ID, visnings-RGB och klippningsflagga.

## Markera största träningsfelet

`inkprof.showVerificationLab(referenceFile,FitReport=fitFile)` lägger till punkten med högst `deltaE00` i `profile-fit.json`. Rapportens profilhash måste matcha verifieringsmålets ICC. Svart/gul ring visar profilens prediktion för den ursprungliga träningspatchens RGB; ett kryss visar dess uppmätta Lab och en linje binder ihop dem. Linjens euklidiska Lab-längd är inte ΔE00. Punkten är ett separat diagnostiskt överlägg och behöver inte sammanfalla med de nya verifieringspatcharna. För kandidat 3 i 991-körningen är maximum 4,4397 ΔE00 vid tidigare kompletteringsmål U22. Detta är inte mätresultatet för den nya utskriften.
