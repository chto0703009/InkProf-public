% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function stem=certificateDeliveryName(profileName,cycle,iterationId)
% A readable profile name plus a stable iteration identity.
name=inkprof.internal.projectFolderName(string(profileName));
code=string(iterationId);
assert(~isempty(regexp(char(code),'^[A-Za-z0-9-]{8,64}$','once')),'inkprof:Delivery','The iteration requires a valid unique identifier.');
stem=name+"_iter-"+string(cycle)+"_"+extractAfter(code,strlength(code)-8);
end
