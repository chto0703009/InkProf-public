% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function folder=printDeliveryFolder(parent,projectName,cycle,step)
%PRINTDELIVERYFOLDER Readable, collision-safe external print folder.
name=inkprof.internal.projectFolderName(projectName);
step=inkprof.internal.projectFolderName(step);
stamp=string(datetime('now','Format','yyyyMMdd-HHmmss'));
base=name+"_iter-"+string(cycle)+"_"+step+"_"+stamp;
folder=fullfile(parent,base);index=1;
while isfolder(folder)||isfile(folder),index=index+1;folder=fullfile(parent,base+"_"+index);end
[ok,msg]=mkdir(folder);assert(ok,'inkprof:PrintCopy','%s',msg);
end
