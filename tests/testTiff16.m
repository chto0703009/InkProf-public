% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testTiff16
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
tc.TestData.source=fullfile(root,'tests','fixtures','targets','chart-575','source.pxf');
tc.TestData.reference=fullfile(root,'tests','fixtures','targets','chart-575','reference.tif');
tc.TestData.work=string(tempname);mkdir(tc.TestData.work);
end
function teardownOnce(tc)
rmdir(tc.TestData.work,'s');
end
function testModelAndScale(tc)
w=tc.TestData.work;
a=inkprof.createTiff16(tc.TestData.source,tc.TestData.reference,fullfile(w,'base.tif'),DPI=100,WriteTxfCandidate=false,Date="2026-09-26",Time="12:00");
t=inkprof.importTarget(tc.TestData.source);t.rgbOriginal=t.rgbOriginal/255*100;t.rgbScale=100;
source=fullfile(w,'scaled.cgats');inkprof.exportCgats(source,t);
b=inkprof.createTiff16(source,tc.TestData.reference,fullfile(w,'scaled.tiff'),RGBScale=100,DPI=100,WriteTxfCandidate=false,Date="2026-09-26",Time="12:00");
ia=imread(a.file);ib=imread(b.file);
% Filenames differ in the footer; all pixels above that band remain equal.
cut=floor((a.heightMm-12)*100/25.4);
verifyEqual(tc,ia(1:cut,:,:),ib(1:cut,:,:));
verifyNotEqual(tc,ia,ib);
m=jsondecode(fileread(b.manifest));verifyEqual(tc,string(m.tiff),"scaled.tiff");
for f=reshape(m.files,1,[])
 verifyEqual(tc,inkprof.internal.sha256(fullfile(w,f.name)),string(f.sha256));
end
l=jsondecode(fileread(b.layout));verifyEqual(tc,numel(l.patches),580);
verifyEqual(tc,sum([l.patches.isPadding]),5);
verifyEqual(tc,[a.widthMm a.heightMm a.rows a.columns],[263 195 20 29]);
verifyEqual(tc,l.patches(1).rectMm(:)',[14.75 24.5 8 8]);
verifyEqual(tc,string(l.patches(27).column),"2A");
verifyFalse(tc,contains(lower(a.title),'i1profiler'));
end
function testFailureDoesNotPublish(tc)
w=tc.TestData.work;template=fullfile(w,'invalid.pxf');fid=fopen(template,'w');fprintf(fid,'invalid XML');fclose(fid);
out=fullfile(w,'failure.tif');
failed=false;
try
 inkprof.createTiff16(tc.TestData.source,tc.TestData.reference,out,DPI=100,TxfTemplate=template);
catch
 failed=true;
end
verifyTrue(tc,failed);verifyEmpty(tc,dir(fullfile(w,'failure*')));
end
function testCandidateCollision(tc)
w=tc.TestData.work;file=fullfile(w,'collision-candidate.txf');fid=fopen(file,'w');fprintf(fid,'keep');fclose(fid);
verifyError(tc,@()inkprof.createTiff16(tc.TestData.source,tc.TestData.reference,fullfile(w,'collision.tif'),DPI=100),'inkprof:Exists');
verifyEqual(tc,fileread(file),'keep');verifyFalse(tc,isfile(fullfile(w,'collision.tif')));
end
function testCompactA4(tc)
out=fullfile(tc.TestData.work,'compact');
inkprof.createTarget(out,Source=tc.TestData.source,CompactA4=true,DPI=100);
l=jsondecode(fileread(fullfile(out,'layout.json')));
verifyEqual(tc,numel(unique([l.patches.page])),1);
r=reshape([l.patches.rectMm],4,[])';
verifyEqual(tc,numel(unique(r(:,1))),29);verifyEqual(tc,numel(unique(r(:,2))),20);
inkprof.verifyPackage(out);
end
function testMultiplePages(tc)
w=tc.TestData.work;root=fileparts(fileparts(mfilename('fullpath')));
source=fullfile(root,'tests','fixtures','i1profiler','chart-2033','Chart 2033 Patches.txf');
a=inkprof.createTiff16(source,fullfile(w,'multi.tif'),DPI=100,Randomize=true,Seed=42);
map=jsondecode(fileread(a.layout));
verifyEqual(tc,numel(a.txfCandidate),4);
for k=1:4
    tx=inkprof.importTarget(fullfile(w,a.txfCandidate(k)));verifyEqual(tc,numel(tx.ids),580);
    page=map.patches([map.patches.page]==k);[~,order]=sortrows(reshape([page.rectMm],4,[])',[1 2]);page=page(order);
    verifyEqual(tc,tx.rgbOriginal,reshape([page.rgb16],3,[])'/257);
    verifyEqual(tc,tx.names,string({page.sampleLoc})');
    verifyEqual(tc,tx.sourceLayout.MeasurementDevice,"i1Pro 2");
    verifyEqual(tc,str2double(tx.sourceLayout.PatchSizeWidthPercent),100/18,AbsTol=1e-12);
end
verifyEqual(tc,a.pageCount,4);verifyEqual(tc,numel(a.tiffs),4);verifyEqual(tc,a.fillers,287);
l=jsondecode(fileread(a.layout));p=l.patches;verifyEqual(tc,numel(p),2320);
verifyEqual(tc,string(p(581).sampleLoc),"21A");verifyEqual(tc,string(p(1741).sampleLoc),"61A");
verifyEqual(tc,sort(str2double(string({p(~[p.isPadding]).sampleId}))),1:2033);
t=inkprof.internal.readCgats(a.ti2);verifyEqual(tc,t.headers.PASSES_IN_STRIPS2,"20,20,20,20");
b=inkprof.createTiff16(source,fullfile(w,'repeat.tiff'),DPI=100,Randomize=true,Seed=42,WriteTxfCandidate=false);
lb=jsondecode(fileread(b.layout));verifyEqual(tc,l.patches,lb.patches);
% A small chart uses the same page template without requiring a reference image.
target=inkprof.importTarget(source);target.ids=target.ids(1:7);target.names=target.names(1:7);target.rgbOriginal=target.rgbOriginal(1:7,:);
f=fullfile(w,'seven.cgats');inkprof.exportCgats(f,target);
c=inkprof.createTiff16(f,fullfile(w,'seven.tif'),RGBScale=255,DPI=100,WriteTxfCandidate=false);
verifyEqual(tc,c.pageCount,1);verifyEqual(tc,c.sourcePatches,7);verifyEqual(tc,c.fillers,573);
end

function testRejectNonRgbExport(tc)
layout=struct('rgbPercent',[0 0 0 0],'rgb16',[0 0 0 0]);
target=struct('documentType',"inkprof.target",'rgbOriginal',[0 0 0 0],'rgbScale',100);
f=fullfile(tc.TestData.work,'not-rgb');
verifyError(tc,@()inkprof.exportCgats(f,target),'inkprof:ColorFormat');
verifyError(tc,@()inkprof.internal.writeMeasurementTi2(f,layout),'inkprof:ColorFormat');
verifyError(tc,@()inkprof.internal.writeTxfCandidate(f,tc.TestData.source,layout),'inkprof:ColorFormat');
verifyError(tc,@()inkprof.internal.writeExchangeCgats(f,f+"-layout",target,layout),'inkprof:ColorFormat');
verifyFalse(tc,isfile(f));
end
