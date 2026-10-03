% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function yes=isFinderMetadata(path)
% Finder view preferences are not profiling evidence, including legacy entries.
path=replace(string(path),"\","/");
yes=path==".DS_Store"|endsWith(path,"/.DS_Store");
end
