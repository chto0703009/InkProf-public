% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function profileGridTrialDialog(w,parent)
[choice,ok]=inkprof.internal.withFocus(parent,@listdlg,'PromptString', ...
 'Build a separate candidate from the same locked measurements:', ...
 'SelectionMode','single','ListString',{'B2A: High','B2A: Ultra','A2B and B2A: High','A2B and B2A: Ultra'}, ...
 'InitialValue',2,'Name','Higher ICC grid trial','ListSize',[380 120]);
if ~ok,return;end
quality="high";if mod(choice,2)==0,quality="ultra";end
tables="B2A";if choice>2,tables="both";end
progress=inkprof.internal.calculationProgress("Higher ICC grid trial", ...
 "Building a separate candidate, inspecting actual grids and checking photographic gradients.",Parent=parent);
[result,folder]=inkprof.rebuildProfileGrid(fileparts(w.output('input','input')), ...
 fileparts(w.output('profile','job')),Quality=quality,Tables=tables);
clear progress;
assert(result.status=="succeeded",'inkprof:GridTrial','Grid trial did not succeed. See %s',folder);
if ~result.gridIncreased,uialert(parent,'The generated tables did not have a larger grid. Inspect the saved comparison; no increase is claimed.','Grid trial');end
inkprof.internal.showGridTrialVerification(result,folder);
end
