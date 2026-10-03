% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testRowGuides
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
end
function testBoundariesBothSidesKeepScanClear(tc)
dpi=254;image=repmat(uint16(65535),600,1000,3);
image(:,301:700,:)=12345;
[out,info]=inkprof.internal.drawRowGuides(image,dpi,[30 70],[20 28 36]);
verifyEqual(tc,out(:,301:700,:),image(:,301:700,:));
verifyEqual(tc,info.xSpansMm,[18 24;76 82]);
verifyEqual(tc,out(201,200,1),uint16(round(.35*65535)));
verifyEqual(tc,out(201,790,1),uint16(round(.35*65535)));
verifyEqual(tc,out(241,1:300,:),image(241,1:300,:)); % row centre/start white
verifyEqual(tc,out(241,701:end,:),image(241,701:end,:)); % end white
verifyEqual(tc,out(:,241:300,:),image(:,241:300,:)); % 6 mm clear gap
verifyEqual(tc,out(:,701:760,:),image(:,701:760,:));
end
