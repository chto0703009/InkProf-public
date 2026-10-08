% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testPrintFooter
tests=functiontests(localfunctions);
end
function testFilenameAndPatchArea(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
dpi=100;blank=repmat(uint16(65535),round(210*dpi/25.4),round(297*dpi/25.4),3);
a=inkprof.internal.drawPrintFurniture(blank,dpi,1,2,"2026-09-26 12:00","/Users/christer/Desktop/InkProf/projects/example-a/target_01.tif");
b=inkprof.internal.drawPrintFurniture(blank,dpi,1,2,"2026-09-26 12:00","/Users/christer/Desktop/InkProf/projects/example-b/target_01.tif");
different=any(a~=b,3);[y,x]=find(different);
verifyNotEmpty(tc,x);
verifyGreaterThan(tc,min(y)/dpi*25.4,190);
verifyGreaterThan(tc,min(x)/dpi*25.4,55);
verifyLessThan(tc,max(x)/dpi*25.4,242);
verifyEqual(tc,a(100:750,:,:),blank(100:750,:,:));
% Full-page footers must leave the last 8 mm white, including wrapped paths.
last=ceil((210-8)*dpi/25.4);
verifyEqual(tc,a(last:end,:,:),blank(last:end,:,:));
verifyError(tc,@()inkprof.internal.drawPrintFurniture(blank,dpi,1,1,"2026-09-26 12:00",join(repmat("W",1,300),"")), 'inkprof:Label');
end

function testSmallPaperKeepsSafeBottomMargin(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
path="/Users/christer/Desktop/InkProf/projects/example/profiles/iterations/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/refinement-print/print/target_01.tif";
for dpi=[100 300]
 for paper=[148 210;210 148;165 164.5]'
  pixels=floor(paper'*dpi/25.4);
  blank=repmat(uint16(65535),pixels(2),pixels(1),3);
  a=inkprof.internal.drawPrintFurniture(blank,dpi,1,2,"2026-10-03 12:00",path,"Source: target.ti1 | generated | 80 patches");
  last=pixels(2)-floor(8*dpi/25.4)+1;
  verifyEqual(tc,a(last:end,:,:),blank(last:end,:,:));
  % Even a wrapped full path must stay in the reserved furniture band.
  first=ceil(20*dpi/25.4);stop=floor((paper(2)-30)*dpi/25.4);
  verifyEqual(tc,a(first:stop,:,:),blank(first:stop,:,:));
  verifyTrue(tc,any(a(stop+1:last-1,:,:)~=65535,'all'));
 end
end
end
function testA5PackagePreservesPatchPixels(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
folder=string(tempname);cleanup=onCleanup(@()rmdir(folder,'s'));
for paper=[148 210;210 148]'
 package=fullfile(folder,"a5-"+paper(1));
 inkprof.createTarget(package,PatchCount=80,GraySteps=5,PaperSizeMm=paper',DPI=100);
 check=inkprof.verifyPackage(package);
 verifyEqual(tc,check.maxTi2PixelErrorCodes,0);
 metadata=jsondecode(fileread(fullfile(package,'target.json')));
 verifyEqual(tc,metadata.printSettings.footerReservedMm,30);
 pages=dir(fullfile(package,'target*.tif'));
 for k=1:numel(pages)
  im=imread(fullfile(pages(k).folder,pages(k).name));
  verifyTrue(tc,all(im(end-floor(8*100/25.4)+1:end,:,:) == 65535,'all'));
 end
end
end

function testLongSummaryDoesNotBlockSmallTarget(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
dpi=100;blank=repmat(uint16(65535),round(210*dpi/25.4),round(148*dpi/25.4),3);
summary="Source: "+join(repmat("long-verification-source-",1,20),"")+" | 128 patches";
a=inkprof.internal.drawPrintFurniture(blank,dpi,1,1,"2026-10-07 10:34","/short/target.tif",summary);
verifyTrue(tc,any(a~=blank,'all'));
first=ceil(20*dpi/25.4);last=floor((210-30)*dpi/25.4);
verifyEqual(tc,a(first:last,:,:),blank(first:last,:,:));
verifyEqual(tc,a(end-floor(8*dpi/25.4)+1:end,:,:),blank(end-floor(8*dpi/25.4)+1:end,:,:));
end
