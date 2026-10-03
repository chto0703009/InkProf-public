% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testShadowSettings
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testMatteAndOverrides(tc)
s=inkprof.internal.shadowSettings(struct('paperSurface',"Matte"));
verifyTrue(tc,s.enabled);verifyEqual(tc,s.extraPatches,48);verifyEqual(tc,s.gridEmphasis,1.3);
s=inkprof.internal.shadowSettings(struct('paperSurface',"Glossy"));verifyFalse(tc,s.enabled);
s=inkprof.internal.shadowSettings(struct('paperSurface',"Matte",'shadowMode',"standard"));verifyFalse(tc,s.enabled);
s=inkprof.internal.shadowSettings(struct('paperSurface',"Matte",'shadowExtraPatches',12,'shadowGridEmphasis',1.5));verifyEqual(tc,s.extraPatches,12);verifyEqual(tc,s.gridEmphasis,1.5);
end
function testRejectInvalid(tc)
verifyError(tc,@()inkprof.internal.shadowSettings(struct('shadowMode',"magic")),'inkprof:Shadows');
verifyError(tc,@()inkprof.internal.shadowSettings(struct('shadowExtraPatches',2.5)),'inkprof:Shadows');
end
function testArgyllDarkDistribution(tc)
a=inkprof.designRGBTarget(Method="argyll",MaxPoints=150,ControlCount=0,RepeatCount=0,GraySteps=9,ShadowEmphasis=2);
verifyTrue(tc,any(string(a.argyllRun.arguments)=="-V2"));
end
