% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function value=version()
%VERSION Return the source release identifier, independent of project schemas.
p=inkprof.paths();value=strtrim(string(fileread(fullfile(p.Root,'VERSION'))));
end
