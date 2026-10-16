% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testLocalReportTime
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testWinterAndSummer(tc)
w=inkprof.internal.localReportTime("2026-01-15T12:00:00Z",'Europe/Stockholm');
s=inkprof.internal.localReportTime("2026-07-15T12:00:00+00:00",'Europe/Stockholm');
verifyTrue(tc,contains(w,'13:00:00 +01:00'));verifyTrue(tc,contains(s,'14:00:00 +02:00'));
end
function testOffsetAndDateBoundary(tc)
t=inkprof.internal.localReportTime("2026-07-15T23:30:00.123456+00:00",'Europe/Stockholm');
verifyTrue(tc,contains(t,'2026-07-16 01:30:00 +02:00'));
t=inkprof.internal.localReportTime("2026-07-16T01:30:00+02:00",'Europe/Stockholm');
verifyTrue(tc,contains(t,'2026-07-16 01:30:00 +02:00'));
end
