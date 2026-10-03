% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function s=shadowReportSummary(w)
% Report the saved build recipe, never infer what an older ICC used.
s=struct('summaryText',"Skugganpassning: äldre recept saknar dokumenterad skugginställning.");
job=w.output('profile','job');recipe=fullfile(fileparts(job),'recipe.json');
if ~isfile(recipe),return;end
r=jsondecode(fileread(recipe));
if ~isfield(r,'engine')||~isfield(r.engine,'shadow'),return;end
s=r.engine.shadow;s.recipeSHA256=inkprof.internal.sha256(recipe);
if s.enabled
 s.summaryText=string(sprintf('Skugganpassning använd vid profilbygget: colprof -V %.3g. Patchviktning %.3g; begärt högst %d extra skuggpatchar vid nästa målskapande. Patchantalet är ett inställningsvärde, inte ett intyg om genomförda mätningar.',s.gridEmphasis,s.patchEmphasis,s.extraPatches));
else
 s.summaryText="Skugganpassning vid profilbygget: avstängd. Standardfördelning används.";
end
end
