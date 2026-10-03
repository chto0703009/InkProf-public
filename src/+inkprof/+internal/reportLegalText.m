% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function legal=reportLegalText()
% Shared existing report wording; shown only in the appendix after signatures.
legal.reproductionLiability="Utföraren av profileringen ansvarar inte för avvikelser som enbart beror på inneboende, fysiska begränsningar hos den aktuella kombinationen skrivare, papper och bläck, förutsatt att uppdraget i övrigt har utförts fackmässigt och enligt avtal. En ICC-profil innebär inte någon utfästelse om återgivning av färger, svärta, kontrast eller tonomfång utöver denna kombinations faktiska förmåga. Denna ansvarsbegränsning omfattar inte fel i utförarens eget arbete, bristfälliga instruktioner eller rekommendationer, avvikelser från uttryckligen avtalade åtaganden eller ansvar som följer av tvingande lag.";
legal.clientPrintResponsibility="Om beställaren (uppdragsgivaren) har skrivit ut målbilderna ansvarar beställaren för att utskrifterna har utförts enligt lämnade instruktioner och för att samtliga lämnade uppgifter är korrekta och fullständiga. Detta omfattar bland annat skrivare, papper, bläck, drivrutins- och färghanteringsinställningar, skalning, torktid samt hantering av utskrifterna. Utföraren av profileringen ansvarar inte för beställarens utskriftsarbete eller för fel i profil eller resultat i den mån dessa orsakas av brister i beställarens utskrifter eller av felaktiga eller ofullständiga uppgifter från beställaren. Mätcertifikatet redovisar resultatet för det mottagna underlaget; det innebär inte att utföraren har verifierat beställarens utskriftsprocess eller uppgifter. Denna ansvarsfördelning begränsar inte utförarens ansvar för egna fel, bristfälliga instruktioner eller skyldigheter enligt tvingande lag.";
legal.warrantyNotice=inkprof.internal.warrantyNotice();
end
