% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function file=pendingVerification(w)
% Return a frozen C2 for the current ICC only, never an older iteration. Saved TIFFs or printing alone do not count as measurement.
file="";if w.valid('c2measurement'),return;end
if w.valid('c2')&&isfield(w.State.steps.c2.outputs,'reference')
 file=w.output('c2','reference');
elseif isfield(w.State.steps.profile.outputs,'verification')
 file=w.output('profile','verification');
end
if file=="",return;end
r=jsondecode(fileread(file));
assert(string(r.printerProfile.sha256)==inkprof.internal.sha256(w.output('profile','profile')),'inkprof:Verification','C2 belongs to another profile.');
end
