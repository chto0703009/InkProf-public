% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function recordProjectStep(path,step)
% Existing standalone workflows remain supported; project members register work.
root=inkprof.internal.findProject(path);
if root=="",return;end
try,inkprof.updateProject(root,Step=step);
catch err
 warning('inkprof:ManifestUpdate','Artifacts were saved, but manifest update failed: %s. Run inkprof.updateProject("%s").',err.message,root);
end
end
