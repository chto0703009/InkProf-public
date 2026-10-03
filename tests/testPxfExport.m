% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testPxfExport
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));tc.TestData.root=root;
end
function testFractionalDuplicateAndEscaping(tc)
w=string(tempname);mkdir(w);clean=onCleanup(@()rmdir(w,'s'));
t=struct('signature','CTI1','metadata',{{["COLOR_REP","RGB"]}},'fields',["SAMPLE_ID","SAMPLE_NAME","RGB_R","RGB_G","RGB_B"], ...
 'data',["id1","A&B <test>","12.3456789","50","99.1234567";"id2","second","12.3456789","50","99.1234567"]);
source=fullfile(w,'source.ti1');inkprof.exportCgats(source,struct('documentType','inkprof.cgats','tables',t));
out=fullfile(w,'result.pxf');verifyError(tc,@()inkprof.exportPxfTarget(source,out),'inkprof:PXFPrecision');r=inkprof.exportPxfTarget(source,out,Name="Test & RGB",RGBEncoding="float");
verifyEqual(tc,r.patchCount,2);verifyEqual(tc,r.excludedPaddingCount,0);verifyLessThan(tc,r.maxRGBPercentRoundtripError,1e-10);
b=inkprof.importTarget(out);verifyEqual(tc,b.names,["Target1";"Target2"]);verifyEqual(tc,string({r.mapping.sourceName})',["A&B <test>";"second"]);verifyEqual(tc,b.rgbPercent(1,:),[12.3456789 50 99.1234567],'AbsTol',1e-10);
verifyTrue(tc,contains(fileread(out),'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'));
verifyError(tc,@()inkprof.exportPxfTarget(source,out),'inkprof:Exists');
end
function testTi2PaddingAndCoordinates(tc)
w=string(tempname);mkdir(w);clean=onCleanup(@()rmdir(w,'s'));
% Produce valid Argyll chart including generated padding without a device.
pkg=fullfile(w,'chart');inkprof.createTarget(pkg,PatchCount=20,GraySteps=3,DPI=100);
source=fullfile(pkg,'target.ti2');t=inkprof.importTarget(source);
r=inkprof.exportPxfTarget(source,fullfile(w,'from-ti2.pxf'),RGBEncoding="float");
verifyEqual(tc,r.patchCount,numel(t.ids));verifyEqual(tc,r.excludedPaddingCount,sum([t.sourceLayout.patches.isPadding]));
verifyEqual(tc,string({r.mapping.sourceId})',t.ids);verifyTrue(tc,all(strlength(string({r.mapping.sourceLocation}))>0));
back=inkprof.importTarget(fullfile(w,'from-ti2.pxf'));verifyEqual(tc,back.rgbPercent,t.rgbPercent,'AbsTol',1e-10);
end
function testCmykRejected(tc)
w=string(tempname);mkdir(w);clean=onCleanup(@()rmdir(w,'s'));source=fullfile(w,'bad.ti1');
f=fopen(source,'w');fprintf(f,'CTI1\nCOLOR_REP CMYK\nNUMBER_OF_FIELDS 5\nBEGIN_DATA_FORMAT\nSAMPLE_ID CMYK_C CMYK_M CMYK_Y CMYK_K\nEND_DATA_FORMAT\nNUMBER_OF_SETS 1\nBEGIN_DATA\n1 0 0 0 0\nEND_DATA\n');fclose(f);
verifyError(tc,@()inkprof.exportPxfTarget(source,fullfile(w,'bad.pxf')),'inkprof:ColorFormat');verifyFalse(tc,isfile(fullfile(w,'bad.pxf')));
end
