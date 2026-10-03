% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testDeviationRanking
tests=functiontests(localfunctions);
end
function testSortedSelectionAcrossPages(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);clean=onCleanup(@()rmdir(w,'s'));
p=struct('sampleLoc',{'1A','1B','2A','2B'},'sampleId',{'1','2','3','4'},'rgbPercent',{[10 10 10],[20 20 20],[30 30 30],[40 40 40]},'isPadding',{false,false,false,false});
inkprof.internal.writeJson(fullfile(w,'chart.json'),struct('patches',p,'passesInStrips',[1 1]));
r=struct('documentType','inkprof.chart-measurement','chartJSONSHA256',inkprof.internal.sha256(fullfile(w,'chart.json')), ...
 'sourceTI3SHA256','test','chartIndex',[1;2;3;4],'measuredSourcePatches',4,'expectedSourcePatches',4, ...
 'data',struct('lab',[],'xyz',ones(4,3),'spectra',[]), ...
 'pairedReadings',struct('originalChartIndex',[1;2;3;4],'spectralRmsDifference',zeros(4,1), ...
 'directionComparison',struct('available',true,'threshold',1,'maxDeltaE00',1.8,'patchDeltaE00',[.1;.7;1.8;.3],'flaggedRows',struct('row','2','maxDeltaE00',1.8))));
inkprof.internal.writeJson(fullfile(w,'measurement-test.json'),r);
f=inkprof.previewMeasurement(w);closer=onCleanup(@()delete(f));t=findall(f,'Tag','patchDeviationRanking');
verifyEqual(tc,string(t.Data(:,1)),["A2";"B1";"B2";"A1"]);
verifyEqual(tc,cell2mat(t.Data(:,3)),[1.8;.7;.3;.1]);
verifyTrue(tc,contains(string(findall(f,'Tag','patchValues').Text),'Patch A2'));
t.CellSelectionCallback(t,struct('Indices',[2 1]));
verifyTrue(tc,contains(string(findall(f,'Tag','patchValues').Text),'Patch B1'));
verifyEqual(tc,string(findall(f,'Tag','remeasurePatch').Enable),"on");
verifyEqual(tc,numel(findall(f,'Type','rectangle')),2);
boxes=findall(f,'Tag','measurementPatch');
for box=reshape(boxes,1,[])
 if box.UserData==2,verifyEqual(tc,box.EdgeColor,[1 0 0]);verifyEqual(tc,box.LineWidth,3);
 else,verifyEqual(tc,box.EdgeColor,[.8 .8 .8]);end
end
end
function testRedPatchUsesContrastingSelection(tc)
[border,inner]=inkprof.internal.selectionBorder([1 0 0]);
verifyEqual(tc,border,[0 1 1]);verifyEqual(tc,inner,[0 0 0]);
[border,~]=inkprof.internal.selectionBorder([.2 .2 .2]);verifyEqual(tc,border,[1 0 0]);
end
