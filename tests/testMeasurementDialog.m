% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testMeasurementDialog
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));tc.TestData.root=root;
end
function testPromptBoundaries(tc)
f=@inkprof.internal.chartPrompt;
s=f("Place the instrument on its reflective white reference S/N 1,"+newline+"or hit Esc or Q to abort:");verifyEqual(tc,s.kind,"calibration");
s=f("Ready to read strip pass 3"+newline+"Trigger instrument switch or any other key to sta");verifyEqual(tc,s.kind,"busy");
s=f("Ready to read strip pass 7 (!! ALL ROWS READ !!)"+newline+"Trigger instrument switch or any other key to start:");verifyTrue(tc,s.allRead);verifyEqual(tc,s.row,7);
s=f(s.text+newline+"Ready to read strip pass 7 (This row has been read)"+newline+"Trigger instrument switch or any other key to start:");verifyFalse(tc,s.allRead);
s=f("Hit Return to use it anyway, any other key to retry, Esc or 'q' to give up:");verifyEqual(tc,s.kind,"unexpected");
s=f("Hit Esc to give up, any other key to retry:");verifyEqual(tc,s.kind,"retry");
s=f("Strip read failed due to communication problem."+newline+"Hit Esc or 'q' to give up, any other key to retry:");verifyEqual(tc,s.kind,"retry");
s=f("Ready to read strip pass 144 (!! ALL ROWS READ !!)"+newline+"Trigger instrument switch to start reading.");verifyEqual(tc,s.kind,"row");verifyTrue(tc,s.allRead);
s=f("Ready to read strip pass 144 (!! ALL ROWS READ !!)"+newline+"Press any other key to start:");verifyEqual(tc,s.kind,"row");verifyTrue(tc,s.allRead);
s=f("Hit any key to retry, or Esc or Q to abort:");verifyEqual(tc,s.kind,"calibrationRetry");
s=f("Unknown instrument question:");verifyEqual(tc,s.kind,"busy");
end
function testStartupErrorVisible(tc)
dialog=inkprof.MeasurementDialog("",Source=fullfile(tempdir,'missing-inkprof-chart.ti2'));
cleanup=onCleanup(@()delete(dialog));
press(dialog,'begin');
logs=findall(dialog.Figure,'Type','uitextarea');
verifyTrue(tc,any(contains(string(logs.Value),'Measurement could not start:')));
verifyEqual(tc,string(findobj(dialog.Figure,'Tag','begin').Enable),"on");
end
function testModalFlow(tc)
runFlow(tc,"alternating");
end
function testPairedModalFlow(tc)
runFlow(tc,"paired");
end
function testRepeatedStartDuringPreparation(tc)
runFlow(tc,"paired",true);
end
function runFlow(tc,mode,reenter)
if nargin<3,reenter=false;end
assumeTrue(tc,isunix);
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
pkg=fullfile(w,'target');inkprof.createTarget(pkg,PatchCount=20,GraySteps=3,DPI=100);
delete(fullfile(pkg,'print-controls.json')); % Exercise the already-printed legacy workflow.
folder=fullfile(w,'session');inkprof.prepareChart(fullfile(pkg,'target.ti2'),folder);
bin=fullfile(w,'bin');mkdir(bin);
for name=["targen","printtarg"],f=fopen(fullfile(bin,name),'w');fclose(f);end
runtime=inkprof.checkPython();script=fullfile(bin,'chartread');
source=fileread(fullfile(tc.TestData.root,'tests','fixtures','fake_chartread_dialog.py'));
f=fopen(script,'w');fprintf(f,'#!%s\n%s',runtime.executable,source);fclose(f);java.io.File(char(script)).setExecutable(true);
dialog=inkprof.MeasurementDialog(folder,ArgyllBin=bin,ScanMode=mode);closer=onCleanup(@()delete(dialog));
verifyEqual(tc,string(dialog.Figure.WindowStyle),"modal");
verifyEqual(tc,string(findobj(dialog.Figure,'Tag','direction').Value),mode);
verifyFalse(tc,isfile(fullfile(folder,'chartread-input.json')));
if reenter
dialogDeadline=inkprofTestDialogDeadline(45); %#ok<NASGU>
    secondStart=timer('StartDelay',.01,'TimerFcn',@(~,~)press(dialog,'begin'));
    timerCleanup=onCleanup(@()delete(secondStart));
    start(secondStart);
end
press(dialog,'begin');
waitButton(dialog,'calibrate');
if reenter
    runs=dir(fullfile(folder,'paired','run-*.json'));
    verifyEqual(tc,numel(runs),1,'Preparation must launch exactly one bridge.');
end
press(dialog,'calibrate');
for attempt=1:2
    waitButton(dialog,'calibrate');
    verifyEqual(tc,string(findobj(dialog.Figure,'Tag','calibrate').Text),"Retry calibration");
    verifyEmpty(tc,findobj(dialog.Figure,'Tag','scan'));
    verifyEqual(tc,string(findobj(dialog.Figure,'Tag','retry').Enable),"off");
    press(dialog,'calibrate');
    verifyEqual(tc,string(findobj(dialog.Figure,'Tag','calibrate').Enable),"off");
end
waitButton(dialog,'forward');verifyEqual(tc,string(findobj(dialog.Figure,'Tag','save').Enable),"off");hardwareScan(dialog);
waitButton(dialog,'retry');press(dialog,'retry');
waitButton(dialog,'forward');hardwareScan(dialog);
if mode=="paired"
    waitButton(dialog,'forward');
    % Inject a page transition into the synthetic instrument scenario.
    data=dialog.Figure.UserData;
    data.physicalChart.passesInStrips=[1 1];
    data.pairedPlan.passes(2).page=2;
    data.pairedPlan.passes(2).physicalRow="2";
    data.pairedPlan.passes(2).rowOnPage=1;
    dialog.Figure.UserData=data;
    t=tic;
    while string(findobj(dialog.Figure,'Tag','pageLoaded').Visible)~="on" && toc(t)<5
        pause(.1);drawnow;
    end
    verifyEqual(tc,string(findobj(dialog.Figure,'Tag','pageLoaded').Visible),"on");
    verifyEqual(tc,string(findobj(dialog.Figure,'Tag','forward').Enable),"off");
    keyfile=fullfile(folder,'paired','keys.txt');before=fileread(keyfile);
    press(dialog,'pageLoaded');pause(.2);drawnow;
    verifyEqual(tc,fileread(keyfile),before); % confirmation sends no instrument key
    verifyEqual(tc,string(findobj(dialog.Figure,'Tag','pageLoaded').Visible),"off");
    hardwareScan(dialog);
end
waitButton(dialog,'save');press(dialog,'save');
t=tic;while isempty(dialog.Result)&&toc(t)<15,pause(.1);drawnow;end
verifyFalse(tc,isempty(dialog.Result));verifyTrue(tc,dialog.Result.complete);
verifyEqual(tc,dialog.Result.measurementCondition.requested,"M0");
verifyEqual(tc,dialog.Result.measurementCondition.interpreted,"unknown");
verifyFalse(tc,dialog.Result.measurementCondition.fwaApplied);
preview=findall(groot,'Tag','InkProfMeasurementResult');
verifyEqual(tc,numel(preview),1);
% Save opens the saved-result overview; hardware rereads require a separate click.
verifyEmpty(tc,findall(groot,'Tag','InkProfSpotMeasurement'));
verifyEmpty(tc,findall(groot,'Tag','InkProfRowRemeasurement'));
verifyFalse(tc,isfolder(fullfile(folder,'spot-rereads')));
verifyFalse(tc,isfolder(fullfile(folder,'row-rereads')));
previewCleanup=onCleanup(@()delete(preview));
verifyTrue(tc,contains(join(string(findobj(preview,'Tag','patchDetails').Value)),"Patch"));
verifyTrue(tc,contains(string(findobj(preview,'Tag','patchValues').Text),"Target RGB (%)"));
verifyTrue(tc,contains(string(findobj(preview,'Tag','patchValues').Text),"indication only"));
% A directly supplied Lab value takes priority without converting spectra.
labResult=dialog.Result;
if mode=="paired"
 labResult.pairedReadings.directionComparison=struct('available',true,'threshold',1, ...
  'flaggedRows',struct('row',"1",'maxDeltaE00',1.88));
end
labResult.data.lab=repmat([51.25 -2.5 3.75],numel(labResult.chartIndex),1);
labPreview=inkprof.previewMeasurement(folder,labResult);
labCleanup=onCleanup(@()delete(labPreview));
if mode=="paired"
 verifyTrue(tc,contains(string(findobj(labPreview,'Tag','pairedWarning').Text),"row(s): 1"));
 savedChart=jsondecode(fileread(fullfile(folder,'chart.json')));
 verifyEqual(tc,numel(findall(labPreview,'Type','rectangle')),numel(savedChart.patches));
end
verifyTrue(tc,contains(string(findobj(labPreview,'Tag','patchValues').Text),"Measured Lab: L* 51.250   a* -2.500   b* 3.750"));
delete(labPreview);
verifyEqual(tc,string(dialog.Figure.WindowStyle),"normal");
runtimeFolder=folder;expectedKeys='    d';flag="-b";
if mode=="paired"
    runtimeFolder=fullfile(folder,'paired');expectedKeys='    d';flag="-B";
    verifyTrue(tc,isfield(dialog.Result,'pairedReadings'));
end
verifyEqual(tc,fileread(fullfile(runtimeFolder,'keys.txt')),expectedKeys);
record=dir(fullfile(runtimeFolder,'run-*.json'));data=jsondecode(fileread(fullfile(runtimeFolder,record(1).name)));
verifyTrue(tc,any(string(data.arguments)==flag));
end
function waitButton(dialog,tag)
t=tic;b=findobj(dialog.Figure,'Tag',tag);
while ~strcmp(b.Enable,'on')&&toc(t)<20,pause(.1);drawnow;end
assert(strcmp(b.Enable,'on'),'Timed out waiting for %s',tag);
end
function press(dialog,tag)
b=findobj(dialog.Figure,'Tag',tag);callback=b.ButtonPushedFcn;callback(b,[]);
end

function testEmptyDialogAndBadSource(tc)
d=inkprof.measureChart();c=onCleanup(@()delete(d));
verifyEqual(tc,string(findobj(d.Figure,'Tag','targetFile').Value),"");
verifyEqual(tc,string(findobj(d.Figure,'Tag','begin').Enable),"on");
verifyEqual(tc,string(findobj(d.Figure,'Tag','calibrate').Enable),"off");
press(d,'begin');
verifyEqual(tc,string(findobj(d.Figure,'Tag','begin').Enable),"on");
verifyFalse(tc,isfolder(d.Folder));
end

function testConditionEvidence(tc)
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
f=fopen(fullfile(w,'transcript-test.txt'),'w');fprintf(f,'U.V. filter ?: No\n');fclose(f);
c=inkprof.internal.measurementCondition(w,"test",{["TARGET_INSTRUMENT","X-Rite i1 Pro 2"]});
verifyEqual(tc,c.interpreted,"M0");verifyEqual(tc,c.reported,"unknown");
c=inkprof.internal.measurementCondition(w,"test",{["INSTRUMENT_FILTER","UVCUT"]});
verifyEqual(tc,c.reported,"M2");verifyEqual(tc,c.interpreted,"M2");
end

function testPageMapping(tc)
chart=struct('passesInStrips',[21 7],'stepsInPass',1, ...
 'patches',struct('sampleLoc',cellstr(string(1:28)+"A")));
a=inkprof.internal.measurementPage(chart,21);verifyEqual(tc,a.page,1);
b=inkprof.internal.measurementPage(chart,22);verifyEqual(tc,b.page,2);
verifyEqual(tc,b.row,"22");verifyEqual(tc,b.rowOnPage,1);verifyEqual(tc,b.totalPages,2);
a=inkprof.internal.measurementPage(chart,21);verifyEqual(tc,a.page,1);
plan=struct('passes',repmat(struct('page',2,'physicalRow',"22",'rowOnPage',1),1,44));
for pass=[43 44]
 a=inkprof.internal.measurementPage(chart,pass,plan);verifyEqual(tc,a.page,2);verifyEqual(tc,a.row,"22");
end
verifyError(tc,@()inkprof.internal.measurementPage(chart,29),'inkprof:Layout');
end

function testFourPagePairedLogUsesPrintedRows(tc)
chart=struct('passesInStrips',[19 19 19 15]);
pages=repelem(1:4,chart.passesInStrips);
passes=struct('page',{},'physicalRow',{},'rowOnPage',{},'phase',{},'expectedDirection',{});
for row=1:72
 for phase=1:2
  direction="forward";if phase==2,direction="reverse";end
  page=pages(row);
  passes(end+1)=struct('page',page,'physicalRow',string(row), ...
   'rowOnPage',row-sum(chart.passesInStrips(1:page-1)), ...
   'phase',phase,'expectedDirection',direction);
 end
end


plan=struct('passes',passes);
transcript=join("Ready to read strip pass "+string(1:144)+newline+"Strip read OK",newline);
shown=inkprof.internal.measurementLog(transcript,chart,plan);
verifyFalse(tc,contains(shown,"strip pass"));
verifyFalse(tc,contains(shown,"printed row 74"));
verifyTrue(tc,contains(shown,"printed row 72 on page 4/4 · FORWARD scan (1/2)"));
verifyTrue(tc,contains(shown,"printed row 72 on page 4/4 · REVERSE scan (2/2)"));
for row=[20 39 58]
 verifyTrue(tc,contains(shown,"printed row "+row+" on page "+pages(row)+"/4"));
end
state=inkprof.internal.chartPrompt(transcript+newline+"Ready to read strip pass 144"+newline+"Trigger instrument switch or any other key to start:");
verifyEqual(tc,state.row,144); % Raw protocol remains authoritative and unchanged.
end

function testLastRowRequiresBothInstrumentConfirmations(tc)
text=join("Ready to read strip pass "+string(1:142)+newline+"Strip read OK",newline);
text=text+newline+"Ready to read strip pass 143"+newline+"Trigger instrument switch or any other key to start:n"+newline+ ...
 "Ready to read strip pass 144"+newline+"Trigger instrument switch or any other key to start:n";
p=inkprof.internal.measurementProgress(text,144);
verifyEqual(tc,p.count,142);verifyEqual(tc,p.missing,[143 144]);
text=text+newline+"Ready to read strip pass 143"+newline+"Strip read failed due to misread";
p=inkprof.internal.measurementProgress(text,144);verifyEqual(tc,p.count,142);
text=text+newline+"Strip read OK"+newline+"Ready to read strip pass 144";
p=inkprof.internal.measurementProgress(text,144);verifyEqual(tc,p.count,143);verifyEqual(tc,p.missing,144);
text=text+newline+"Strip read OK";
p=inkprof.internal.measurementProgress(text,144);verifyEqual(tc,p.count,144);verifyEmpty(tc,p.missing);
% Re-reading the last sweep does not inflate the count.
p=inkprof.internal.measurementProgress(text+newline+"Strip read OK",144);verifyEqual(tc,p.count,144);
end

function hardwareScan(dialog)
folder=dialog.Folder;
if dialog.Figure.UserData.scanMode=="paired",folder=fullfile(folder,'paired');end
f=fopen(fullfile(folder,'instrument-button'),'w');fclose(f);
% Wait for the fixture to consume this press before another can be sent.
t=tic;while isfile(fullfile(folder,'instrument-button'))&&toc(t)<5,pause(.1);drawnow;end
assert(~isfile(fullfile(folder,'instrument-button')),'Hardware trigger not consumed');
pause(.4);drawnow;
end

function testShuffledPhysicalRows(tc)
% Source order must not determine the displayed physical row, on any page.
chart=struct('passesInStrips',[2 1],'stepsInPass',2, ...
 'patches',struct('sampleLoc',{'15B','13A','14B','15A','13B','14A'}));
for pass=1:3
 info=inkprof.internal.measurementPage(chart,pass);
 verifyEqual(tc,info.row,string(pass+12));
end
info=inkprof.internal.measurementPage(chart,3);
verifyEqual(tc,info.page,2);verifyEqual(tc,info.rowOnPage,1);
end

function testHardwareScanConfirmsPageOnce(tc)
chart=struct('passesInStrips',[1 2],'patches',struct('sampleLoc',{'1A','2A','3A'}));
f=@inkprof.internal.completedScanPage;
t="Ready to read strip pass 2"+newline+"Strip read O";
[page,offset]=f(t,0,chart);verifyEmpty(tc,page);verifyEqual(tc,offset,0);
t=t+"K"+newline+"Ready to read strip pass 3";
[page,offset]=f(t,offset,chart);verifyEqual(tc,page,2);
[page,nextOffset]=f(t,offset,chart);verifyEmpty(tc,page);verifyEqual(tc,nextOffset,offset);
% Navigation to page 1, and failed readings, must not confirm a new page.
t=t+newline+"Ready to read strip pass 1"+newline+"Strip read failed due to misread";
[page,offset]=f(t,offset,chart);verifyEmpty(tc,page);
t=t+newline+"Strip read OK"+newline+"Ready to read strip pass 2";
[page,~]=f(t,offset,chart);verifyEqual(tc,page,1); % completed page, not next page
end

function testPairedFirstSweepConfirmsNewPage(tc)
chart=struct('passesInStrips',[1 2]);
passes=struct('page',{1,1,2,2,2,2},'physicalRow',{"1","1","2","2","3","3"},'rowOnPage',{1,1,1,1,2,2});
plan=struct('passes',passes);
t="Ready to read strip pass 3"+newline+"Strip read OK"+newline+"Ready to read strip pass 4";
[page,offset]=inkprof.internal.completedScanPage(t,0,chart,plan);verifyEqual(tc,page,2);
[page,~]=inkprof.internal.completedScanPage(t,offset,chart,plan);verifyEmpty(tc,page);
end

function teardown(~)
deadlines=timerfindall('Name','InkProfTestDeadline');if ~isempty(deadlines),stop(deadlines);delete(deadlines);end
if isappdata(groot,'InkProfTestDialogExpired')
 expired=getappdata(groot,'InkProfTestDialogExpired');rmappdata(groot,'InkProfTestDialogExpired');
 assert(~expired,'inkprof:TestDialogTimeout','Dialog interaction did not finish before its deadline.');
end
end
