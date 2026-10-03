% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testTi2Target
tests=functiontests(localfunctions);
end
function testImportAndRelayout(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
a=fullfile(w,'original');inkprof.createTarget(a,PatchCount=20,GraySteps=3,DPI=100);
source=fullfile(a,'target.ti2');t=inkprof.importTarget(source);
verifyEqual(tc,numel(t.ids),20);
verifyFalse(tc,any(t.ids=="0"));
verifyEqual(tc,t.rgbScale,100);
verifyTrue(tc,any([t.sourceLayout.patches.isPadding]));
real=t.sourceLayout.patches(~[t.sourceLayout.patches.isPadding]);
verifyEqual(tc,t.rgbOriginal,vertcat(real.rgbPercent));
verifyEqual(tc,t.ids,string({real.sampleId})');
verifyTrue(tc,contains(t.xyzStatus,"not measurements"));
verifyError(tc,@()inkprof.importTarget(source,RGBScale=255),'inkprof:Scale');
b=fullfile(w,'new');inkprof.createTarget(b,Source=source,DPI=100,SpacerMode="colored");
r=inkprof.verifyPackage(b);verifyTrue(tc,r.passed);verifyEqual(tc,r.sourcePatches,20);
verifyEqual(tc,fileread(fullfile(b,'source','original.ti2')),fileread(source));
f=inkprof.createTiff16(source,fullfile(w,'from-ti2.tif'),DPI=100,WriteTxfCandidate=false);
verifyEqual(tc,f.sourcePatches,20);
verifyTrue(tc,isfile(f.file));
end
