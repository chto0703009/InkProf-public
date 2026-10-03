% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testTargetRowLabels
tests=functiontests(localfunctions);
end
function testBothMargins(tc)
root=string(tempname);mkdir(root);cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
for paper=["A4-landscape","A3-portrait"]
 out=fullfile(root,paper);inkprof.createTarget(out,Paper=paper,PatchCount=40,GraySteps=3,DPI=100,PaperLayout=struct('preferences',struct('MaxScanMm',320,'MaxLengthMm',500,'RollWidthMm',329)));
 r=inkprof.verifyPackage(out);verifyTrue(tc,r.horizontalRowsVerified);
 pages=dir(fullfile(out,'target*.tif'));pixels=imread(fullfile(pages(1).folder,pages(1).name));
 yy=ceil(25*100/25.4):size(pixels,1)-ceil(25*100/25.4);
 left=pixels(yy,1:ceil(12*100/25.4),1);right=pixels(yy,end-ceil(12*100/25.4)+1:end,1);
 verifyGreaterThan(tc,nnz(left==32768),0);verifyEqual(tc,nnz(right==32768),nnz(left==32768));
end
end
