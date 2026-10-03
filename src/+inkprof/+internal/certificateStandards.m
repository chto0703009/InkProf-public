% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function r=certificateStandards()
%CERTIFICATESTANDARDS Versioned, non-certifying bvdm/ISO reference.
p=inkprof.paths();
r=jsondecode(fileread(fullfile(p.Root,'resources','certificate-standards.json')));
end
