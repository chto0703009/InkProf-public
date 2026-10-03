% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function path=absolutePath(path)
% MATLAB cd and the JVM's user.dir can differ after test/framework callbacks.
path=string(path);
if ~java.io.File(char(path)).isAbsolute(),path=fullfile(string(pwd),path);end
path=string(java.io.File(char(path)).getCanonicalPath());
end
