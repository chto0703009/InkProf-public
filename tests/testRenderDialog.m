% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testRenderDialog
 tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
tc.TestData.root=root;
end
function testDefaultsAndSizes(tc)
f=inkprof.renderTarget();cleanup=onCleanup(@()delete(f));
verifyEqual(tc,findobj(f,'Tag','renderWidth').Value,297);
verifyEqual(tc,findobj(f,'Tag','renderHeight').Value,210);
verifyEqual(tc,findobj(f,'Tag','renderDPI').Value,300);
p=findobj(f,'Tag','renderPaper');p.Value='A3 portrait';p.ValueChangedFcn(p,[]);
verifyEqual(tc,findobj(f,'Tag','renderHeight').Value,420);
h=findobj(f,'Tag','renderHeight');h.Value=600;h.ValueChangedFcn(h,[]);
verifyEqual(tc,p.Value,'Custom');
verifyEqual(tc,findobj(f,'Tag','renderWidth').Limits,[61 320]);
s=findobj(f,'Tag','renderSource');s.Value=fullfile(tc.TestData.root,'example.pxf');s.ValueChangedFcn(s,[]);
verifyEqual(tc,findobj(f,'Tag','renderName').Value,'example-TIFF16');
end
function testLongPageMetadata(tc)
w=string(tempname);cleanup=onCleanup(@()remove(w));
m=inkprof.createTarget(w,PatchCount=20,GraySteps=3,DPI=100,PaperSizeMm=[297 420],SpacerMode="colored");
t=jsondecode(fileread(fullfile(w,'target.json')));
verifyEqual(tc,t.printSettings.paperSizeMm,[297;420]);
verifyEqual(tc,t.printSettings.dpi,100);
verifyEqual(tc,string(t.printSettings.outputFolder),w);
verifyEqual(tc,string(t.printSettings.lengthPolicy),"user-selected");
verifyEqual(tc,t.printSettings.tiffBitsPerChannel,16);
verifyFalse(tc,t.printSettings.embeddedICCProfile);
verifyEqual(tc,m.printSettings.paperSizeMm,[297 420]);
r=inkprof.verifyPackage(w);verifyEqual(tc,r.pages(1).sizeMm,[297 420],'AbsTol',.26);
end
function remove(w)
if isfolder(w),rmdir(w,'s');end
end
function testPageCountBeforeSaving(tc)
source=fullfile(tc.TestData.root,'tests','fixtures','targets','chart-575','source.pxf');
f=inkprof.renderTarget(source);cleanup=onCleanup(@()delete(f));
set(findobj(f,'Tag','renderDPI'),'Value',100);
b=findobj(f,'Tag','renderCalculate');b.ButtonPushedFcn(b,[]);
verifyNotEmpty(tc,f.UserData.pageCount);
verifyEqual(tc,findobj(f,'Tag','previewPage').Text,'Page 1 of 2');
verifyEqual(tc,string(f.WindowStyle),"alwaysontop");
prev=findobj(f,'Tag','previewPrevious');next=findobj(f,'Tag','previewNext');
verifyEqual(tc,string(prev.Enable),"off");
next.ButtonPushedFcn(next,[]);
verifyEqual(tc,findobj(f,'Tag','previewPage').Text,'Page 2 of 2');
verifyEqual(tc,string(next.Enable),"off");
prev.ButtonPushedFcn(prev,[]);
verifyEqual(tc,findobj(f,'Tag','previewPage').Text,'Page 1 of 2');
verifyGreaterThan(tc,numel(findobj(f,'Tag','renderPreview').ImageSource),3);
w=string(tempname);cleanPackage=onCleanup(@()remove(w));
m=inkprof.createTarget(w,Source=source,DPI=100,PaperSizeMm=[297 210],SpacerMode="colored");
verifyEqual(tc,f.UserData.pageCount,m.pageCount);
exportapp(f,'/tmp/inkprof-pages-preview.png');
h=findobj(f,'Tag','renderHeight');h.Value=420;h.ValueChangedFcn(h,[]);
verifyEmpty(tc,f.UserData.pageCount);
verifyEqual(tc,string(prev.Enable),"off");verifyEqual(tc,string(next.Enable),"off");
verifyTrue(tc,contains(findobj(f,'Tag','renderPageCount').Text,'not calculated'));
end
function testPreviewPageOrder(tc)
m.files=struct('name',{'target_10-preview.png','target_2-preview.png','target_1-preview.png','argyll/target-preview.png','target.ti2'});
verifyEqual(tc,inkprof.internal.previewFiles(m),["target_1-preview.png","target_2-preview.png","target_10-preview.png"]);
end
