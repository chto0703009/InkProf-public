% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function requireRgb(values,scale)
%REQUIRERGB Reject non-RGB target/export data before writing any file.
assert(isnumeric(values)&&ismatrix(values)&&~isempty(values)&&size(values,2)==3, ...
    'inkprof:ColorFormat','Fel färgformat: InkProf stöder endast RGB-target och RGB-mätunderlag.');
assert(isscalar(scale)&&isfinite(scale)&&scale>0&&all(isfinite(values)&values>=0&values<=scale,'all'), ...
    'inkprof:Scale','RGB-värden ligger utanför den angivna skalan.');
end
