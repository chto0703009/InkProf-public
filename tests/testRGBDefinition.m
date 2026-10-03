% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testRGBDefinition
 tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
end
function testDefinitionAndRender(tc)
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
d=inkprof.designRGBTarget(Levels=2,GraySteps=3,MaxPoints=24,ControlCount=3,RepeatCount=2);
s=inkprof.saveRGBDefinition(d,fullfile(w,'mesh.ti1'));
a=dir(w);verifyEqual(tc,sort(string({a(~[a.isdir]).name})),["mesh.json","mesh.ti1"]);
r=jsondecode(fileread(s.json));verifyFalse(tc,isfield(r,'print'));
t=inkprof.importTarget(s.ti1);verifyEqual(tc,t.rgbPercent,d.rgb*100,'AbsTol',1e-10);
verifyEqual(tc,string(t.targetInfo.generation.method),"mesh");
verifyEqual(tc,t.targetInfo.network.pointCount,d.fitCount);
hash=inkprof.internal.sha256(s.json);
m=inkprof.createTarget(fullfile(w,'print'),Source=s.ti1,Paper="A4-landscape",DPI=100);
verifyEqual(tc,string(m.targetInfo.generation.method),"mesh");
verifyEqual(tc,inkprof.internal.sha256(s.json),hash);
verifyEqual(tc,inkprof.internal.sha256(fullfile(w,'print','source','original.json')),hash);
verifyError(tc,@()inkprof.saveRGBDefinition(d,s.ti1),'inkprof:Exists');
r.definition.ti1SHA256='bad';inkprof.internal.writeJson(s.json,r);
verifyError(tc,@()inkprof.importTarget(s.ti1),'inkprof:Integrity');
end
function testDesignWindowSeparation(tc)
f=inkprof.designTarget();cleanup=onCleanup(@()delete(f));
verifyEmpty(tc,findobj(f,'Tag','dpi'));verifyEmpty(tc,findobj(f,'Tag','shuffle'));
verifyEqual(tc,findobj(f,'Tag','saveDesign').Text,'Save definition: TI1 + JSON…');
end
