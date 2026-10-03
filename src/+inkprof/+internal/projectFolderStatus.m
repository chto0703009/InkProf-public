% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function status=projectFolderStatus(folder)
%PROJECTFOLDERSTATUS Compare the directory name, not the machine-specific parent.
root=inkprof.internal.absolutePath(folder);
r=jsondecode(fileread(fullfile(root,'inkprof-project.json')));
[~,actual]=fileparts(root);
saved=string(r.name);if isfield(r,'folderName'),saved=string(r.folderName);end
status=struct('changed',actual~=saved,'actualName',actual,'savedName',saved);
end
