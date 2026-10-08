% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testTxfExport
tests=functiontests(localfunctions);
end
function testMappingAndGuards(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
work=string(tempname);mkdir(work);clean=onCleanup(@()rmdir(work,'s'));
package=fullfile(work,'target');out=fullfile(work,'txf');
template=fullfile(root,'tests','fixtures','i1profiler','chart-2033','Chart 2033 Patches.txf');
t=inkprof.importTarget(template);t.ids=t.ids(1:200);t.names=t.names(1:200);t.rgbOriginal=t.rgbOriginal(1:200,:);
source=fullfile(work,'patches.txt');inkprof.exportCgats(source,t);
% Allow the full temporary path in the footer, including macOS temp roots.
inkprof.createTarget(package,Source=source,RGBScale=255,PaperSizeMm=[210 120],DPI=100,Randomize=true,Seed=42);
verifyError(tc,@()inkprof.exportTxfTarget(package,out),'inkprof:UnverifiedTXF');
r=inkprof.exportTxfTarget(package,out,Experimental=true,Template=template);
verifyTrue(tc,r.rgb16RoundTripVerified);verifyFalse(tc,r.receiverLayoutVerified);
verifyGreaterThan(tc,numel(r.files),1);
verifyEqual(tc,sum(~[r.mapping.isPadding]),200);
for f=reshape(r.files,1,[])
 t=inkprof.importTarget(fullfile(out,f.file));m=r.mapping([r.mapping.page]==f.page);
 verifyEqual(tc,round(t.rgbOriginal*257),reshape([m.rgb16],3,[])');
 verifyEqual(tc,t.names,string({m.coordinate})');
 verifyEqual(tc,numel(m),f.rows*f.columns);
 verifyEqual(tc,t.sourceLayout.ScramblePatches,"False");
 verifyEqual(tc,str2double(t.sourceLayout.PatchSizeWidthPercent),100/6,AbsTol=1e-12);
 verifyEqual(tc,str2double(t.sourceLayout.PatchSizeHeightPercent),0);
end
verifyError(tc,@()inkprof.exportTxfTarget(package,out,Experimental=true,Template=template),'inkprof:Exists');
fractional=fullfile(work,'fractional');inkprof.createTarget(fractional,PatchCount=20,GraySteps=3,DPI=100);
verifyError(tc,@()inkprof.exportTxfTarget(fractional,fullfile(work,'bad'),Experimental=true,Template=template),'inkprof:TXFPrecision');
end
