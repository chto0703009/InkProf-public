% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testProfileJobProgressMessage
tests=functiontests(localfunctions);
end
function testFinalStageWins(tc)
log=join(["About to adjust a and b output curves for white point";"About to create grid position input curves";"Create final clut from scattered data"],newline);
m=inkprof.internal.profileJobProgressMessage(log,125);
verifyTrue(tc,contains(m,"final colour lookup table"));
verifyTrue(tc,contains(m,"2 min 05 sec"));
end
function testStartingAndWhitePoint(tc)
verifyTrue(tc,contains(inkprof.internal.profileJobProgressMessage("",0),"fitting"));
verifyTrue(tc,contains(inkprof.internal.profileJobProgressMessage("About to adjust a and b output curves for white point",1),"white-point"));
end
