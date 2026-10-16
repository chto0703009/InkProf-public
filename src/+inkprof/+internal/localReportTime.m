% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function value=localReportTime(utc)
% Display historical instants with the computer's local zone and DST offset.
if nargin==0
 t=datetime('now','TimeZone','local');
else
 t=datetime(string(utc),'InputFormat',"yyyy-MM-dd'T'HH:mm:ss'Z'",'TimeZone','UTC');
 t.TimeZone='local';
end
t.Format='yyyy-MM-dd HH:mm:ss XXX';
value=string(t)+" ("+string(t.TimeZone)+")";
end
