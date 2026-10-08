% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testArgyllRefinementCandidates
tests=functiontests(localfunctions);
end
function testPrintablePlacementAndExclusion(tc)
d=struct('rgb',[0 0 0;.5 .2 .1;1 1 1;.5 .2 .1],'fitCount',4);
p=inkprof.internal.argyllRefinementCandidates(d,[0 0 0],1);
verifyEqual(tc,numel(p.candidates),2);
verifyEqual(tc,p.candidates(2).rgbPercent,[100 100 100]);
verifyTrue(tc,startsWith(p.candidates(1).patchId,"argyll-"));
verifyFalse(tc,p.errorNorm.available);
end
