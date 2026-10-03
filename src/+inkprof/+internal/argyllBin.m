% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [folder,source]=argyllBin(requested)
p=inkprof.paths();
[folder,source]=inkprof.internal.resolveArgyllBin(string(requested),p.Root,p.ArgyllBin, ...
 string(getenv('ARGYLL_BIN')),inkprof.internal.argyllCandidates(),p.ArgyllConfigLegacy);
end
