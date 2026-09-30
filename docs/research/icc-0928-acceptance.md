# Acceptans inför ny verifieringsutskrift, 2026-09-28

Användaren accepterade att gå vidare och begärde commit/push efter granskning av den nya 575-mätningen. Acceptansen gäller fungerande B1–B3 och numeriska kontroller som underlag för nästa C2. Den är inte ett godkännande av profilens uppmätta utskriftskvalitet.

- Källa: `InkProf-575-from-TI2-v2_0928.mxf`, 575 RGB-patchar, M0/XRGA, i1 Pro 2, 36 spektralband 380–730 nm.
- Låst underlag: `a3b30fac-483d-4da7-9caf-f1fc61c45aa0`.
- Recept: `192c7980-83ed-4d78-81c0-ce9862bb27b2`, spectral.
- Profiljobb: `f1864640-237e-49ff-b08e-89c754744923`.
- ICC SHA-256: `1eca263b2b7d9fd08db64fa4535949ab99724267a88fbae2023634b1d52d430f`.
- Anpassning till 575 mätpunkter: medel ΔE00 0,6715; max 3,5527.
- Rundgång på 729 RGB-punkter, relativ kolorimetri: medel ΔE00 0,4142; max 2,5648.
- Neutral Lab-rundgång inom modellen: medel ΔE00 0,0554; max 0,3535.
- Inga ljushetsvändningar i testad RGB-gråramp. En kandidat till lokal rampojämnhet kvarstår för granskning; maximal andra differens 1,2104 Lab-enheter vid steg 1/256.

B1 verifierar den positionerade original-MXF-filens hash, patch-ID, positioner och RGB genom ny import när TI2 saknar uppskattad XYZ. Detta är identitetskontroll, inte bevis för korrekt fysisk svepriktning. Mätvärdena jämförs också mellan vald JSON-revision och TI3.

Nästa steg: skapa ett nytt C2-mål med denna profil och kontrastmarkörer, dokumentera utskriftsinställningarna, skriva ut utan ytterligare profilkonvertering och mäta. Äldre C2-resultat gäller andra profil-/utskriftsförhållanden och godkänner inte denna kandidat. ISSUE-001 om mätbrus/konditionstal kvarstår.
