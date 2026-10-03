% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testSpotMeasurement
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));tc.TestData.root=root;
end
function [file,w]=fixture(tc)
w=string(tempname);mkdir(w);
% Small self-contained chart and measurement, no local user files or hardware.
p=struct('index',{},'sampleId',{},'sampleLoc',{},'rgbPercent',{},'isPadding',{});
for i=1:3,p(i)=struct('index',i,'sampleId',string(i),'sampleLoc',"1"+string(char(64+i)),'rgbPercent',[i i i]*20,'isPadding',false);end
chart=struct('patches',p,'stepsInPass',3,'passesInStrips',1);
inkprof.internal.writeJson(fullfile(w,'chart.json'),chart);
fields=["SAMPLE_ID","SAMPLE_LOC","RGB_R","RGB_G","RGB_B","XYZ_X","XYZ_Y","XYZ_Z","SPEC_380","SPEC_390","SPEC_400"];
values=["1","1A","20","20","20","10","11","12","10","11","12";"2","1B","40","40","40","20","21","22","20","21","22";"3","1C","60","60","60","30","31","32","30","31","32"];
metadata={["DEVICE_CLASS","OUTPUT"];["COLOR_REP","RGB_XYZ"];["DEVCALSTD","XRGA"]};
t=struct('signature','CTI3','metadata',{metadata},'fields',fields,'data',values);
inkprof.exportCgats(fullfile(w,'original.ti3'),struct('documentType','inkprof.cgats','tables',t));
data=struct('ids',string((1:3)'),'locations',["1A";"1B";"1C"],'rgbPercent',[20 20 20;40 40 40;60 60 60], ...
 'xyz',[10 11 12;20 21 22;30 31 32],'spectra',[10 11 12;20 21 22;30 31 32],'wavelengthNm',[380 390 400],'lab',[],'xyz100',[],'spectralFraction',[],'metadata',{metadata});
r=struct('schemaVersion',1,'documentType','inkprof.chart-measurement','chartIndex',[1;2;3], ...
 'chartJSONSHA256',inkprof.internal.sha256(fullfile(w,'chart.json')),'sourceTI3SHA256',inkprof.internal.sha256(fullfile(w,'original.ti3')), ...
 'sourcePath','obsolete/moved/path.ti3','metadata',{metadata},'data',data,'complete',true,'measuredSourcePatches',3,'expectedSourcePatches',3, ...
 'measurementCondition',struct('interpreted','M0','requested','M0','fwaApplied',false,'instrument','X-Rite i1 Pro 2'), ...
 'pairedReadings',struct('rawEvidence','Preserve this object unchanged','originalChartIndex',[1;2;3],'spectralRmsDifference',[.1;.2;.3]));
file=fullfile(w,'measurement-20260927.json');inkprof.internal.writeJson(file,r);
end
function [candidate,a]=candidateFor(file)
a=inkprof.preparePatchRemeasurement(file,'B1');q=jsondecode(fileread(fullfile(a,'request.json')));
c=struct('schemaVersion',1,'documentType','inkprof.spot-candidate','request',q,'calibrationStandard','XRGA','spectralScale',100,'illuminant','D50','observer','1931_2','measurementCondition','M0 (fixture)','instrumentSerial','TEST','wavelengthNm',[380 390 400],'xyz',[20.1 21.1 22.1],'lab',[50 1 2],'spectra',[20.1 21.1 22.1]);
candidate=fullfile(a,'candidate.json');inkprof.internal.writeJson(candidate,c);
end
function testReplacementAndRejections(tc)
[file,w]=fixture(tc);clean=onCleanup(@()rmdir(w,'s'));r=jsondecode(fileread(file));hash=inkprof.internal.sha256(file);
[candidate,a]=candidateFor(file);c=jsondecode(fileread(candidate));bad=c;bad.wavelengthNm(2)=391;inkprof.internal.writeJson(candidate,bad);
verifyError(tc,@()inkprof.acceptPatchRemeasurement(file,candidate),'inkprof:Spectrum');verifyEqual(tc,numel(dir(fullfile(w,'measurement-*.json'))),1);
inkprof.internal.writeJson(candidate,c);[updated,out]=inkprof.acceptPatchRemeasurement(file,candidate);
verifyEqual(tc,inkprof.internal.sha256(file),hash);verifyEqual(tc,updated.data.xyz([1 3],:),r.data.xyz([1 3],:));verifyEqual(tc,updated.data.spectra([1 3],:),r.data.spectra([1 3],:));verifyEqual(tc,updated.pairedReadings,r.pairedReadings);
verifyEqual(tc,updated.data.xyz(2,:),[20.1 21.1 22.1]);verifyTrue(tc,isfile(out));verifyTrue(tc,isfile(fullfile(a,'decision.json')));
verifyError(tc,@()inkprof.acceptPatchRemeasurement(file,candidate),'inkprof:Exists');
% Newest saved revision is used, while unrelated measurement settings are ignored.
inkprof.internal.writeJson(fullfile(w,'measurement-settings.json'),struct('documentType','inkprof.measurement-settings'));
f=inkprof.previewMeasurement(w);closer=onCleanup(@()delete(f));verifyEqual(tc,numel(findall(f,'Type','rectangle')),3);verifyEqual(tc,string(findall(f,'Tag','remeasurePatch').Enable),"on");
end
function testModalFakeInstrument(tc)
[file,w]=fixture(tc);clean=onCleanup(@()rmdir(w,'s'));
% Fixture emits 36 bands, so expand the measurement definition accordingly.
r=jsondecode(fileread(file));r.data.wavelengthNm=380:10:730;r.data.spectra=repmat(12,3,36);inkprof.internal.writeJson(file,r);
bin=fullfile(w,'bin');mkdir(bin);runtime=inkprof.checkPython();
for name=["targen","printtarg"],f=fopen(fullfile(bin,name),'w');fclose(f);end
source=fileread(fullfile(tc.TestData.root,'tests','fixtures','fake_spotread.py'));script=fullfile(bin,'spotread');f=fopen(script,'w');fprintf(f,'#!%s\n%s',runtime.executable,source);fclose(f);java.io.File(char(script)).setExecutable(true);
fig=inkprof.remeasurePatch(file,'B1',ArgyllBin=bin);closer=onCleanup(@()deleteValid(fig));
action=findall(fig,'Tag','spotAction');action.ButtonPushedFcn(action,[]);
for caption=["Calibrate","Calibrate","Measure patch"]
 waitEnabled(action);verifyEqual(tc,string(action.Text),caption);action.ButtonPushedFcn(action,[]);
end
accept=findall(fig,'Tag','spotAccept');waitEnabled(accept);
verifyTrue(tc,contains(string(findall(fig,'Tag','spotComparison').Text),'dE00'));
review=findall(fig,'Tag','spotReviewValues');verifyEqual(tc,string(review.Visible),"on");
verifySize(tc,review.Data,[6 4]);verifyEqual(tc,string(review.Data{4,4}),"-10.000");verifyEqual(tc,review.Data{4,2},20);verifyEqual(tc,review.Data{4,3},10);
verifyTrue(tc,contains(string(accept.Text),'Accept B1 (dE00'));
folder=fig.UserData.attemptFolder;verifyTrue(tc,isfile(fullfile(folder,'candidate.json')));
fig.CloseRequestFcn(fig,[]);decision=jsondecode(fileread(fullfile(folder,'decision.json')));verifyEqual(tc,string(decision.decision),"discarded");verifyEqual(tc,numel(dir(fullfile(w,'measurement-*.json'))),1);
end
function waitEnabled(button)
t=tic;while string(button.Enable)~="on"&&toc(t)<20,pause(.1);drawnow;end
assert(string(button.Enable)=="on",'Test timed out waiting for instrument prompt.');
end
function deleteValid(fig)
if isvalid(fig),delete(fig);end
end
