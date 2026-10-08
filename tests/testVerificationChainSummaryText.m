% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testVerificationChainSummaryText
tests=functiontests(localfunctions);
end
function testAvailableStagesProduceScalarString(tc)
s=struct('mean',1.2,'max',3.4);
d=struct('inverse',struct('summary',s),'tiff',struct('status',"available",'mismatchCount',0,'checkedCount',152,'maxChannelCodeError',0),'print',struct('status',"available",'summary',s));
t=inkprof.internal.verificationChainSummaryText(d);
verifyClass(tc,t,'string');verifySize(tc,t,[1 1]);
verifyTrue(tc,contains(t,'0 mismatches / 152 patches'));verifyEqual(tc,numel(splitlines(t)),3);
end
function testUnavailableStages(tc)
d=struct('inverse',struct('summary',struct('mean',0,'max',0)),'tiff',struct('status',"unavailable",'reason',"Missing TIFF"),'print',struct('status',"unavailable"));
verifyTrue(tc,contains(inkprof.internal.verificationChainSummaryText(d),'Missing TIFF'));
verifyTrue(tc,contains(inkprof.internal.verificationChainSummaryText([]),'unavailable'));
end
