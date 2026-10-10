% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function name=projectDeliveryProfileName(record)
% Use the profile identity entered in Project details, without another prompt.
name=string(record.name);
if isfield(record,'printing')&&isstruct(record.printing)&&isfield(record.printing,'profileName')
    saved=strtrim(string(record.printing.profileName));
    if isscalar(saved)&&strlength(saved)>0,name=saved;end
end
name=inkprof.internal.projectFolderName(name);
end
