# ISSUE-001 – Inversens känslighet för mätbrus

Status: **Öppen**. Registrerad 2026-09-27 på användarens begäran.
Berör C1/C2 (validering) och D4 (egen invers).

## Problem och belägg

575-profilens framåtmodell uppvisar svaga riktningar och alternativa RGB-lösningar, främst i undersökta gröna/cyana områden. Ett undersökt lokalt Jacobian-konditionstal är cirka 48; andra punkter har högre och mer stegberoende värden. Detta indikerar möjlig känslighet för mätbrus. Faktisk brusförstärkning genom hela kedjan mätning → modell → invers är ännu inte kvantifierad.

Tätare B2A minskar tabellens approximationsfel men stänger inte denna issue. Stor RGB-avvikelse ensam är inte bevis för stort färgfel. Se [inversundersökningen](../research/inverse-error-investigation.md).

## Undersökning som återstår

- Upprepa mätningar av samma patchar under kontrollerade villkor, inklusive känsliga gröna/cyana områden, gråskala och stabila referenspunkter. Skilj instrumentets repeterbarhet från utskriftens variation.
- Uppskatta mätvariation i spektra och Lab; dokumentera mätvillkor, antal upprepningar och relevanta korrelationer.
- Perturbera mätunderlaget med en empiriskt motiverad brusmodell och bygg om profilerna med oförändrade inställningar. Bevara frön, indatarevisioner, recept och resultat i JSON. Enbart störning av PCS-indata till en redan byggd profil räcker inte för denna kontroll.
- Utvärdera färgfel, RGB-spridning och eventuella hopp mellan närliggande inverslösningar separat. Kontrollera olika differenssteg och skalning vid bedömning av Jacobianen.
- Jämför vid behov upprepning/medelvärdesbildning, kompletterande patchar, modellutjämning och regulariserad invers. Kontrollera avvägningen mellan stabilitet och färgnoggrannhet mot oberoende mätningar.

## Kriterier för stängning

1. Repeterbarhet och brusförstärkning har kvantifierats med spårbara data.
2. Toleranser för färgfel och inversens jämnhet har bestämts och motiverats för användningen; inget godtyckligt konditionstal används som ensam gräns.
3. Kandidaten uppfyller dessa toleranser på oberoende verifieringsdata, eller har tydligt avgränsade begränsningar som användaren accepterar.
4. Resultat, åtgärd eller accepterad kvarvarande risk dokumenteras och frågan stängs uttryckligen.

ICC-utvecklingen kan fortsätta medan frågan är öppen. Robusthet mot mätbrus får inte betraktas som verifierad enbart genom lågt träningsfel, bättre roundtrip eller tätare B2A.

## Beslut 2026-09-27

Användaren vill låta frågan ligga kvar tills avvikelser kan kopplas bättre till konditionstal och brus. C1 får fortsätta och avslutas inom sin numeriska omfattning utan att en full brusstudie utförs nu. Flyttalsjämförelse och lokala PCS-störningsprov ger inte i sig belägg för mätbrusorsakade fel. Ingen sådan orsak har verifierats i detta steg.
