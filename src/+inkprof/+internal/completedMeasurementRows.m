% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function keep=completedMeasurementRows(confirmed,paired)
% Paired rows are retained only when BOTH complete scans exist.
keep=logical(reshape(confirmed,1,[]));
if paired
 assert(mod(numel(keep),2)==0,'inkprof:Checkpoint','Invalid paired scan count.');
 whole=keep(1:2:end)&keep(2:2:end);keep=repelem(whole,2);
end
end
