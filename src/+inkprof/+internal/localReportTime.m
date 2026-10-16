% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function value=localReportTime(utc,zone)
% Display historical instants with the computer's local zone and DST offset.
if nargin<2,zone='local';end
if nargin==0
 t=datetime('now','TimeZone',zone);
else
 stamp=regexprep(string(utc),'\.\d+(?=Z$|[+-]\d\d:\d\d$)','');
 stamp=regexprep(stamp,'Z$','+00:00');
 t=datetime(stamp,'InputFormat',"yyyy-MM-dd'T'HH:mm:ssXXX",'TimeZone','UTC');
 t.TimeZone=zone;
end
t.Format='yyyy-MM-dd HH:mm:ss XXX';
value=string(t)+" ("+string(t.TimeZone)+")";
end
