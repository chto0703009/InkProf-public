% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function s=shadowReportSummary(w)
% Report the saved build recipe, never infer what an older ICC used.
s=struct('summaryText',"Shadow processing: this older recipe has no documented shadow setting.");
job=w.output('profile','job');recipe=fullfile(fileparts(job),'recipe.json');
if ~isfile(recipe),return;end
r=jsondecode(fileread(recipe));
if ~isfield(r,'engine')||~isfield(r.engine,'shadow'),return;end
s=r.engine.shadow;s.recipeSHA256=inkprof.internal.sha256(recipe);
if s.enabled
 s.summaryText=string(sprintf('Shadow processing used during profiling: colprof -V %.3g. Patch weighting %.3g; at most %d extra shadow patches requested for the next target. The count is a setting, not evidence of completed measurements.',s.gridEmphasis,s.patchEmphasis,s.extraPatches));
else
 s.summaryText="Shadow processing during profiling: off. Standard distribution used.";
end
end
