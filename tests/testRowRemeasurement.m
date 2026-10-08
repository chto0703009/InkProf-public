% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testRowRemeasurement
tests=functiontests(localfunctions);
end
function testPrepareAndReplaceOnlySelectedRow(tc)
[w,file]=fixture("alternating");cleanup=onCleanup(@()rmdir(w,'s'));original=jsondecode(fileread(file));hash=inkprof.internal.sha256(file);
[folder,q]=inkprof.prepareRowRemeasurement(file,2,"2");
verifyEqual(tc,q.page,2);verifyEqual(tc,q.row,"2");verifyEqual(tc,q.expectedDirection,"reverse");
verifyEqual(tc,string(q.settings.scanMode),"alternating");
chart=jsondecode(fileread(fullfile(folder,'session','chart.json')));
verifyEqual(tc,string({chart.patches.sampleLoc}),["1A","1B","1C"]);
% Partial rereads and mismatched conditions must not produce a revision.
candidate=makeCandidate(folder,q);
c=jsondecode(fileread(candidate));c.complete=false;inkprof.internal.writeJson(candidate,c);
verifyError(tc,@()inkprof.acceptRowRemeasurement(file,candidate,fullfile(folder,'request.json')),'inkprof:Integrity');
c.complete=true;c.measurementCondition.interpreted="M2";inkprof.internal.writeJson(candidate,c);
verifyError(tc,@()inkprof.acceptRowRemeasurement(file,candidate,fullfile(folder,'request.json')),'inkprof:Condition');
c.measurementCondition.interpreted="M0";inkprof.internal.writeJson(candidate,c);
[result,out]=inkprof.acceptRowRemeasurement(file,candidate,fullfile(folder,'request.json'));
verifyTrue(tc,isfile(out));verifyEqual(tc,inkprof.internal.sha256(file),hash);
unchanged=~ismember(original.chartIndex,q.chartIndices);
verifyEqual(tc,result.data.xyz(unchanged,:),original.data.xyz(unchanged,:));
verifyEqual(tc,result.data.spectra(unchanged,:),original.data.spectra(unchanged,:));
verifyEqual(tc,result.data.ids,original.data.ids);verifyEqual(tc,result.data.locations,original.data.locations);
verifyEqual(tc,result.data.xyz(~unchanged,:),original.data.xyz(~unchanged,:)+1);
verifyEqual(tc,string(result.rowOverrides.scanMode),"alternating");
verifyEqual(tc,string(result.rowOverrides.row),"2");
verifyError(tc,@()inkprof.acceptRowRemeasurement(file,candidate,fullfile(folder,'request.json')),'inkprof:Exists');
preview=inkprof.previewMeasurement(fileparts(out),result);cfig=onCleanup(@()delete(preview));
verifyEqual(tc,string(findall(preview,'Tag','remeasureRow').Enable),"on");
end
function testRejectWrongPageAndRetainPairedMode(tc)
[w,file]=fixture("paired");cleanup=onCleanup(@()rmdir(w,'s'));
verifyError(tc,@()inkprof.prepareRowRemeasurement(file,1,"2"),'inkprof:Identity');
[folder,q]=inkprof.prepareRowRemeasurement(file,2,"2");verifyEqual(tc,string(q.settings.scanMode),"paired");
candidate=makeCandidate(folder,q);
verifyError(tc,@()inkprof.acceptRowRemeasurement(file,candidate,fullfile(folder,'request.json')),'inkprof:Measurement');
[pairedFolder,pairedQ]=inkprof.prepareRowRemeasurement(file,2,"2");
pairedCandidate=makeCandidate(pairedFolder,pairedQ,true);
[r,~]=inkprof.acceptRowRemeasurement(file,pairedCandidate,fullfile(pairedFolder,'request.json'));
verifyTrue(tc,r.rowOverrides.directionComparison.available);
verifyTrue(tc,isfile(fullfile(pairedFolder,'session','paired','chart.ti3')));
f=inkprof.remeasureRow(file,2,"2");cf=onCleanup(@()delete(f));
verifyEqual(tc,string(findall(f,'Tag','rowRereadPage').Value),"2");
verifyEqual(tc,string(findall(f,'Tag','rowRereadRow').Value),"2");
end
function testPairedRowDialogFlow(tc)
assumeTrue(tc,isunix);[w,file]=fixture("paired");cleanup=onCleanup(@()rmdir(w,'s'));
root=fileparts(fileparts(mfilename('fullpath')));bin=fullfile(w,'bin');mkdir(bin);
for name=["targen","printtarg"],f=fopen(fullfile(bin,name),'w');fclose(f);end
runtime=inkprof.checkPython();source=string(fileread(fullfile(root,'tests','fixtures','fake_chartread_dialog.py')));
source=replace(source,"NUMBER_OF_FIELDS 10","NUMBER_OF_FIELDS 11");
source=replace(source,"SPEC_400 SPEC_500","SPEC_400 SPEC_500 SPEC_600");
source=replace(source,"['10','20','30','10','20']","['10','20','30','10','20','30']");
source=replace(source,"['CTI3',","['CTI3','DEVCALSTD XRGA','INKPROF_MEASUREMENT_CONDITION M0','TARGET_INSTRUMENT ""X-Rite i1 Pro 2""',");
script=fullfile(bin,'chartread');fid=fopen(script,'w');fprintf(fid,'#!%s\n%s',runtime.executable,source);fclose(fid);java.io.File(char(script)).setExecutable(true);
f=inkprof.remeasureRow(file,2,"2",ArgyllBin=bin);cf=onCleanup(@()closeIfValid(f));
click(f,'rowRereadStart');dialog=f.UserData.measurementDialog;click(dialog.Figure,'begin');
for attempt=1:3,waitFor(dialog.Figure,'calibrate');click(dialog.Figure,'calibrate');end
waitFor(dialog.Figure,'forward');
labels=findall(dialog.Figure,'Type','uilabel');texts=string({labels.Text});
verifyTrue(tc,any(contains(texts,"Page 2/2 · Row 2 · FORWARD scan (1/2)")));
hardware(dialog);waitFor(dialog.Figure,'retry');click(dialog.Figure,'retry');waitFor(dialog.Figure,'forward');hardware(dialog);
waitFor(dialog.Figure,'forward');labels=findall(dialog.Figure,'Type','uilabel');texts=string({labels.Text});
verifyTrue(tc,any(contains(texts,"Page 2/2 · Row 2 · REVERSE scan (2/2)")));
hardware(dialog);waitFor(dialog.Figure,'save');click(dialog.Figure,'save');
waitFor(f,'rowRereadAccept');verifyEqual(tc,size(findall(f,'Tag','rowRereadReview').Data,1),3);
click(f,'rowRereadAccept');verifyFalse(tc,isgraphics(f));
previews=findall(groot,'Tag','InkProfMeasurementResult');for preview=reshape(previews,1,[]),delete(preview);end
end
function click(f,tag)
b=findall(f,'Tag',tag);cb=b.ButtonPushedFcn;cb(b,[]);
end
function waitFor(f,tag)
t=tic;while toc(t)<30
 drawnow;pause(.1);b=findall(f,'Tag',tag);if ~isempty(b)&&strcmp(b.Enable,'on'),return;end
end
error('Test:Timeout','Timed out waiting for %s.',tag);
end
function hardware(dialog)
folder=dialog.Folder;if dialog.Figure.UserData.scanMode=="paired",folder=fullfile(folder,'paired');end
file=fullfile(folder,'instrument-button');fid=fopen(file,'w');fclose(fid);
t=tic;while isfile(file)&&toc(t)<10,pause(.1);drawnow;end
end
function closeIfValid(f)
if isgraphics(f),delete(f);end
end
function [w,file]=fixture(mode)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);
fields=["SAMPLE_ID","SAMPLE_LOC","RGB_R","RGB_G","RGB_B","XYZ_X","XYZ_Y","XYZ_Z","SPEC_400","SPEC_500","SPEC_600"];
% Shuffled source-record order, with the row spread through the table.
order=[4 1 5 2 6 3];data=strings(6,numel(fields));
for k=1:6
 id=order(k);r=1+(id>3);col=char('A'+mod(id-1,3));
 data(k,:)=[string(id),string(r)+string(col),string([10*id,5*id,15*id,20+id,25+id,30+id,40+id,50+id,60+id])];
end
metadata={ ["COLOR_REP","RGB"], ["STEPS_IN_PASS","3"], ["PASSES_IN_STRIPS2","1,1"], ...
 ["STRIP_INDEX_PATTERN","0-9,@-9,@-9;1-999"], ["PATCH_INDEX_PATTERN","A-Z,A-Z;A-Z"], ...
 ["SPECTRAL_BANDS","3"], ["SPECTRAL_START_NM","400"], ["SPECTRAL_END_NM","600"], ...
 ["TARGET_INSTRUMENT","X-Rite i1 Pro 2"], ["DEVCALSTD","XRGA"], ...
 ["INKPROF_MEASUREMENT_CONDITION","M0"]};
t=struct('signature',"CTI2",'fields',fields,'metadata',{metadata},'data',data);doc=struct('documentType',"inkprof.cgats",'tables',t);
ti2=fullfile(w,'target.ti2');inkprof.exportCgats(ti2,doc);folder=fullfile(w,'session');inkprof.prepareChart(ti2,folder);
s=struct('chartJSONSHA256',inkprof.internal.sha256(fullfile(folder,'chart.json')),'requestedCondition',"M0", ...
 'scanMode',mode,'direction',"forward",'scanTolerance',1,'port',0);
inkprof.internal.writeJson(fullfile(folder,'measurement-settings.json'),s);
doc.tables.signature="CTI3";doc.tables.metadata{1}=["COLOR_REP","RGB_XYZ"];
f=fullfile(w,'source.ti3');inkprof.exportCgats(f,doc);inkprof.importChartMeasurement(folder,f);
files=dir(fullfile(folder,'measurement-*.json'));file=fullfile(files(1).folder,files(1).name);
end
function file=makeCandidate(folder,q,paired)
if nargin<3,paired=false;end
physical=fullfile(folder,'session');
session=physical;
if paired,inkprof.internal.preparePairedChart(physical);session=fullfile(physical,'paired');end
doc=inkprof.importCgats(fullfile(session,'source.ti2'));
t=doc.tables(1);t.signature="CTI3";t.metadata{1}=["COLOR_REP","RGB_XYZ"];
cols=ismember(t.fields,["XYZ_X","XYZ_Y","XYZ_Z"]);t.data(:,cols)=string(str2double(t.data(:,cols))+1);
doc.tables=t;ti3=fullfile(folder,'new.ti3');inkprof.exportCgats(ti3,doc);
s=q.settings;s.chartJSONSHA256=inkprof.internal.sha256(fullfile(session,'chart.json'));
inkprof.internal.writeJson(fullfile(session,'measurement-settings.json'),s);
if paired
 copyfile(ti3,fullfile(session,'chart.ti3'));
 raw=inkprof.importChartMeasurement(session,ti3);r=inkprof.internal.averagePairedMeasurement(physical,raw);session=physical;
else,r=inkprof.importChartMeasurement(session,ti3);end
files=dir(fullfile(session,'measurement-*.json'));file="";
for entry=reshape(files,1,[])
 p=fullfile(entry.folder,entry.name);saved=jsondecode(fileread(p));
 if string(saved.sourceTI3SHA256)==string(r.sourceTI3SHA256),file=p;break;end
end
end
