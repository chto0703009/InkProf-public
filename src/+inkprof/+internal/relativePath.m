% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function relative=relativePath(root,file)
% Canonical, confined relative path with consistent UTF-16 indexing.
root=inkprof.internal.absolutePath(root);
file=inkprof.internal.absolutePath(file);
assert(startsWith(file,root+filesep),'inkprof:WorkflowPath','The file must be inside the selected folder: %s',file);
chars=char(file);
relative=replace(string(chars(numel(char(root))+2:end)),"\","/");
end
