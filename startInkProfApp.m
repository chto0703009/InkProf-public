% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function fig=startInkProfApp(projectFolder)
%STARTINKPROFAPP Set up InkProf and open the project workflow app.
arguments
 projectFolder (1,1) string = ""
end
setupInkProf();
fig=inkprof.app(projectFolder);
end
