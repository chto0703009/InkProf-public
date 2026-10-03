% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function name=iccDeliveryName(projectName,date)
% Human-readable external filename; ICC contents remain byte-identical.
arguments
 projectName (1,1) string
 date (1,1) datetime = datetime('now')
end
date.Format='yyMMdd';
name=inkprof.internal.projectFolderName(projectName)+"_"+string(date)+".icc";
end
