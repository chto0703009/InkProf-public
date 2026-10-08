% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testTargetInfo
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));tc.TestData.root=root;
end
function testImportsAndDegenerateGrid(tc)
p=fullfile(tc.TestData.root,'tests','fixtures','targets','chart-575','source.pxf');
t=inkprof.importTarget(p);i=t.targetInfo;
verifyEqual(tc,i.source.fileName,"source.pxf");verifyEqual(tc,i.source.sha256,t.sourceSHA256);
verifyEqual(tc,i.patchCount,575);verifyEqual(tc,i.generation.method,"unknown");verifyEqual(tc,i.network.dimension,3);verifyEqual(tc,i.network.cubeCornerCount,8);
verifyTrue(tc,contains(i.footerText,"imported PXF"));
a=inkprof.internal.targetInfo([0 0 0;.5 .5 .5;1 1 1],"");
verifyEqual(tc,a.network.dimension,1);verifyEmpty(tc,a.network.maxEdge);
end
function testArgyllAndSummaryPixels(tc)
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
p=fullfile(w,'generated');inkprof.createTarget(p,PatchCount=20,GraySteps=3,DPI=100);
t=jsondecode(fileread(fullfile(p,'target.json')));m=jsondecode(fileread(fullfile(p,'manifest.json')));l=jsondecode(fileread(fullfile(p,'layout.json')));
verifyEqual(tc,t.targetInfo,m.targetInfo);verifyEqual(tc,t.targetInfo,l.targetInfo);
verifyEqual(tc,string(t.targetInfo.generation.method),"argyll");
verifyEqual(tc,string(t.targetInfo.source.path),fullfile(p,'source','generated.ti1'));
verifyEqual(tc,string(t.targetInfo.source.sha256),inkprof.internal.sha256(fullfile(p,'source','generated.ti1')));
dpi=100;blank=repmat(uint16(65535),round(195*dpi/25.4),round(263*dpi/25.4),3);
a=inkprof.internal.drawPrintFurniture(blank,dpi,1,1,"2026-09-26 12:00","/short/target.tif","Source: source.pxf | imported PXF | 575 patches");
b=inkprof.internal.drawPrintFurniture(blank,dpi,1,1,"2026-09-26 12:00","/short/target.tif");
[y,~]=find(any(a~=b,3));verifyNotEmpty(tc,y);
% Summary sits above the footer, whose baseline is inset 12 mm from the edge.
verifyGreaterThan(tc,min(y)/dpi*25.4,176);verifyLessThan(tc,max(y)/dpi*25.4,180);
end

function testCgatsMetadata(tc)
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
target=struct('documentType',"inkprof.target",'ids',["1";"2"],'names',["a";"b"], ...
    'rgbOriginal',[0 0 0;100 100 100],'rgbScale',100);
file=fullfile(w,'input.cgats');inkprof.exportCgats(file,target);
i=inkprof.importTarget(file,RGBScale=100);
verifyEqual(tc,i.targetInfo.network.dimension,1);
verifyEqual(tc,i.targetInfo.source.fileName,"input.cgats");
verifyTrue(tc,isfield(i.targetInfo.source.declaredMetadata,'ORIGINATOR'));
end
