% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function tests=testCertificateDeliveryName
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testLastEightIterationCharacters(tc)
uuid="12345678-abcd-1234-abcd-123456789abc";
stem=inkprof.internal.certificateDeliveryName("My printer paper",2,uuid);
verifyEqual(tc,stem,"My printer paper_iter-2_56789abc");
verifyNotEqual(tc,stem,inkprof.internal.certificateDeliveryName("My printer paper",2,"12345678-abcd-1234-abcd-123456789abd"));
verifyError(tc,@()inkprof.internal.certificateDeliveryName("../unsafe",2,uuid),'inkprof:ProjectName');
verifyError(tc,@()inkprof.internal.certificateDeliveryName("Paper",2,"../unsafe"),'inkprof:Delivery');
end
