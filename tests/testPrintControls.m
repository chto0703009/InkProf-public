% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function tests=testPrintControls
tests=functiontests(localfunctions);
end
function setupOnce(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testReferencePreservesXYZColumnsAndAveragesPages(tc)
r=struct('label',"R",'xyz',[40;21;2]);g=r;g.label="G";g.xyz=[20;40;10];b=r;b.label="B";b.xyz=[10;5;50];
xyz=inkprof.internal.printControlReferenceXYZ([r g b]);
verifyEqual(tc,xyz.R,[40 21 2]);verifyEqual(tc,xyz.G,[20 40 10]);verifyEqual(tc,xyz.B,[10 5 50]);
r2=r;r2.xyz=[42 23 4];g2=g;g2.xyz=[22 42 12];b2=b;b2.xyz=[12 7 52];
xyz=inkprof.internal.printControlReferenceXYZ([r g b r2 g2 b2]);
verifyEqual(tc,xyz.R,[41 22 3]);verifyEqual(tc,xyz.G,[21 41 11]);verifyEqual(tc,xyz.B,[11 6 51]);
r.xyz=21;verifyError(tc,@()inkprof.internal.printControlReferenceXYZ([r g b]),'inkprof:PrintControlReference');
end
function testSeparatePixelsAndProfilingCoverage(tc)
w=string(tempname);mkdir(w);clean=onCleanup(@()rmdir(w,'s'));
pkg=fullfile(w,'target');m=inkprof.createTarget(pkg,PatchCount=400,GraySteps=5,DPI=100,PaperSizeMm=[148 148]);
check=inkprof.verifyPackage(pkg);verifyEqual(tc,check.sourcePatches,400);verifyEqual(tc,check.maxTi2PixelErrorCodes,0);
controls=jsondecode(fileread(fullfile(pkg,'print-controls.json')));layout=jsondecode(fileread(fullfile(pkg,'layout.json')));
verifyGreaterThan(tc,m.pageCount,1);verifyEqual(tc,numel(controls.patches),3*m.pageCount);
for control=reshape(controls.patches,1,[])
 for p=reshape(layout.patches([layout.patches.page]==control.page),1,[])
  r=p.rectMm;c=control.rectMm;
  verifyLessThanOrEqual(tc,c(2)+c(4),20);
  verifyGreaterThan(tc,c(1),148-45);
  overlap=max(0,min(r(1)+r(3),c(1)+c(3))-max(r(1),c(1)))*max(0,min(r(2)+r(4),c(2)+c(4))-max(r(2),c(2)));
  verifyEqual(tc,overlap,0,'Print controls must not overlap profiling patches.');
 end
end
folder=fullfile(w,'session');chart=inkprof.prepareChart(fullfile(pkg,'target.ti2'),folder);
verifyTrue(tc,isfield(chart,'printControls'));verifyEqual(tc,chart.sourcePatchCount,400);
verifyError(tc,@()inkprof.internal.requirePrintControls(folder),'inkprof:PrintControlFailed');
record=struct('complete',true,'status',"review-required",'definitionSHA256',chart.printControls.sha256);
inkprof.internal.writeJson(fullfile(folder,'print-control-check.json'),record);
verifyError(tc,@()inkprof.internal.requirePrintControls(folder),'inkprof:PrintControlFailed');
record.status="passed";inkprof.internal.writeJson(fullfile(folder,'print-control-check.json'),record);
inkprof.internal.requirePrintControls(folder);
record.definitionSHA256="wrong";inkprof.internal.writeJson(fullfile(folder,'print-control-check.json'),record);
verifyError(tc,@()inkprof.internal.requirePrintControls(folder),'inkprof:PrintControlFailed');
end
function testLegacyChartNeverRequiresMissingControls(tc)
w=string(tempname);mkdir(w);clean=onCleanup(@()rmdir(w,'s'));
inkprof.internal.writeJson(fullfile(w,'chart.json'),struct('patches',[]));
inkprof.internal.requirePrintControls(w);
verifyEqual(tc,inkprof.measurePrintControls(w),"");
end
function testOverrideRequiresReasonAndRetainsEvidence(tc)
w=string(tempname);mkdir(w);clean=onCleanup(@()rmdir(w,'s'));
inkprof.internal.writeJson(fullfile(w,'chart.json'),struct('printControls',struct('sha256',"fixture")));
file=fullfile(w,'print-control-check.json');
original=struct('complete',true,'status',"review-required",'definitionSHA256',"fixture", ...
 'thresholdDeltaE00',5,'readings',struct('page',1,'label',"R",'deltaE00',8,'flagged',true));
inkprof.internal.writeJson(file,original);
original=jsondecode(fileread(file));
verifyError(tc,@()inkprof.internal.overridePrintControls(w,"   "),'inkprof:OverrideReason');
verifyError(tc,@()inkprof.internal.requirePrintControls(w),'inkprof:PrintControlFailed');
check=inkprof.internal.overridePrintControls(w,"Matte paper: print settings checked; accept this measured difference.");
verifyEqual(tc,string(check.status),"override-approved");verifyEqual(tc,check.readings,original.readings);
verifyEqual(tc,check.thresholdDeltaE00,5);inkprof.internal.requirePrintControls(w);
decisionFile=fullfile(w,check.override.decisionFile);decision=jsondecode(fileread(decisionFile));
verifyEqual(tc,decision.originalCheck,original);verifyNotEmpty(tc,decision.decidedAt);
check.readings.deltaE00=1;inkprof.internal.writeJson(file,check);
verifyError(tc,@()inkprof.internal.requirePrintControls(w),'inkprof:PrintControlFailed');
inkprof.internal.writeJson(file,original);original.complete=false;inkprof.internal.writeJson(file,original);
verifyError(tc,@()inkprof.internal.overridePrintControls(w,"Incomplete spots"),'inkprof:PrintControlFailed');
original.complete=true;original.status="reference-needed";inkprof.internal.writeJson(file,original);
verifyError(tc,@()inkprof.internal.overridePrintControls(w,"Missing reference"),'inkprof:PrintControlFailed');
end
function testStationaryControlWizardKeepsSeparateData(tc)
exerciseWizard(tc,false);
end
function testStationaryControlWizardOverride(tc)
exerciseWizard(tc,true);
end
function testRemeasureSelectedWithoutLeavingWizard(tc)
exerciseWizard(tc,false,"selected");
end
function testRestartControlsWithoutLeavingWizard(tc)
exerciseWizard(tc,false,"all");
end
function testMultiPageSoundAndInlinePageChange(tc)
exerciseWizard(tc,false,"",true);
end
function testInstrumentButtonPlaysStartCue(tc)
exerciseWizard(tc,false,"",false,true);
end
function testCloseWhileCalibrationWaits(tc)
exerciseWizard(tc,false,"",false,false,true);
end
function exerciseWizard(tc,withOverride,retryMode,multiPage,hardwareButton,closeDuringCalibration)
if nargin<3,retryMode="";end
if nargin<4,multiPage=false;end
if nargin<5,hardwareButton=false;end
if nargin<6,closeDuringCalibration=false;end
retried=false;toneCount=0;expectedTones=0;
w=string(tempname);mkdir(w);clean=onCleanup(@()rmdir(w,'s'));
pkg=fullfile(w,'target');
if multiPage
 inkprof.createTarget(pkg,PatchCount=400,GraySteps=5,DPI=100,PaperSizeMm=[148 148]);
else
 inkprof.createTarget(pkg,PatchCount=20,GraySteps=3,DPI=100);
end
folder=fullfile(w,'session');inkprof.prepareChart(fullfile(pkg,'target.ti2'),folder);
chartHash=inkprof.internal.sha256(fullfile(folder,'chart.json'));
if withOverride
 chart=jsondecode(fileread(fullfile(folder,'chart.json')));
 reference=struct('context',struct('projectId',chart.sourceSHA256,'printing',struct), ...
  'calibrationStandard',"XRGA",'thresholdDeltaE00',5,'xyz',struct('R',[70 80 60],'G',[70 80 60],'B',[70 80 60]));
 inkprof.internal.writeJson(fullfile(pkg,'print-control-reference.json'),reference);
end
bin=fullfile(w,'bin');mkdir(bin);runtime=inkprof.checkPython();
if hardwareButton,f=fopen(fullfile(bin,'hardware-button'),'w');fclose(f);expectedTones=3;end
for name=["targen","printtarg"]
 executable=fullfile(bin,name);f=fopen(executable,'w');fprintf(f,'#!/bin/sh\nprintf "Version 3.5.0 test fixture\\n"\n');fclose(f);
 java.io.File(char(executable)).setExecutable(true);
end
root=fileparts(fileparts(mfilename('fullpath')));
f=fopen(fullfile(bin,'spotread'),'w');fprintf(f,'#!%s\n%s',runtime.executable,fileread(fullfile(root,'tests','fixtures','fake_print_controls.py')));fclose(f);
java.io.File(char(fullfile(bin,'spotread'))).setExecutable(true);
started=tic;driver=timer('ExecutionMode','fixedSpacing','Period',.2,'TimerFcn',@advance);
closer=onCleanup(@()stopDriver(driver));start(driver);
file=inkprof.measurePrintControls(folder,ArgyllBin=bin,StartTone=@recordTone);stop(driver);
if closeDuringCalibration
 verifyEqual(tc,file,"");verifyEqual(tc,toneCount,0);
 verifyEqual(tc,inkprof.internal.sha256(fullfile(folder,'chart.json')),chartHash);
 attempts=dir(fullfile(folder,'print-control-spots','*','request.json'));verifyEqual(tc,numel(attempts),1);
 verifyEmpty(tc,findall(groot,'Tag','InkProfPrintControls'));return
end
verifyEqual(tc,toneCount,expectedTones);verifyGreaterThan(tc,toneCount,0);
report=jsondecode(fileread(file));
verifyTrue(tc,report.complete);
if withOverride
 verifyEqual(tc,string(report.status),"override-approved");
 verifyEqual(tc,string(report.override.reason),"Matte paper: checked settings; accept this print.");
 verifyTrue(tc,any([report.readings.flagged]));inkprof.internal.requirePrintControls(folder);
else,verifyEqual(tc,string(report.status),"reference-needed");end
verifyTrue(tc,report.excludedFromProfiling);savedChart=jsondecode(fileread(fullfile(folder,'chart.json')));verifyEqual(tc,numel(report.readings),3*numel(savedChart.passesInStrips));
if multiPage,verifyGreaterThan(tc,numel(report.readings),3);end
if retryMode~=""
 verifyTrue(tc,retried);
 attempts=dir(fullfile(folder,'print-control-spots','*','retry.json'));verifyEqual(tc,numel(attempts),1);
 retry=jsondecode(fileread(fullfile(attempts(1).folder,attempts(1).name)));
 if retryMode=="selected",verifyEqual(tc,retry.remeasuredIndices,2);else,verifyEqual(tc,numel(retry.remeasuredIndices),3);end
 verifyTrue(tc,isfile(fullfile(retry.previousSpotFolder,'reading-002.json')));
 verifyTrue(tc,isfile(fullfile(retry.previousSpotFolder,'superseded-check.json')));
end
verifyEqual(tc,inkprof.internal.sha256(fullfile(folder,'chart.json')),chartHash);
verifyFalse(tc,isfile(fullfile(folder,'chart.ti3')),'Control spots must never become a profiling TI3.');
 function recordTone()
  toneCount=toneCount+1;
 end
 function advance(~,~)
  fig=findall(groot,'Tag','InkProfPrintControls');if isempty(fig),return;end
  if toc(started)>40
   label=findall(fig,'Tag','printControlStatus');disp(string(label.Text));delete(fig);error('Control wizard timed out.');
  end
  dialog=findall(groot,'Tag','InkProfPrintControlOverride');
  if ~isempty(dialog)
   reason=findall(dialog,'Tag','printControlOverrideReason');save=findall(dialog,'Tag','printControlOverrideSave');
   if isempty(reason)||isempty(save),return;end
   reason.Value={'Matte paper: checked settings; accept this print.'};save.ButtonPushedFcn(save,[]);return;
  end
  close=findall(fig,'Tag','printControlClose');if isempty(close),return;end
  if strcmp(close.Text,'Continue with saved chart')
   if retryMode~=""&&~retried
    retried=true;
    if retryMode=="selected"
     table=findall(fig,'Tag','printControlTable');table.CellSelectionCallback(table,struct('Indices',[2 1]));
     button=findall(fig,'Tag','printControlRemeasure');
    else,button=findall(fig,'Tag','printControlRestart');end
    verifyEqual(tc,string(button.Enable),"on");button.ButtonPushedFcn(button,[]);
    verifyFalse(tc,isfile(fullfile(folder,'print-control-check.json')),'An old pass must not survive an incomplete retry.');
    verifyEqual(tc,numel(findall(groot,'Tag','InkProfPrintControls')),1);
    return;
   end
   override=findall(fig,'Tag','printControlOverride');
   if withOverride&&strcmp(override.Enable,'on'),override.ButtonPushedFcn(override,[]);else,close.ButtonPushedFcn(close,[]);end
   return;
  end
  button=findall(fig,'Tag','printControlAction');if isempty(button),return;end
  if closeDuringCalibration&&strcmp(button.Text,'Calibrate')
   close.ButtonPushedFcn(close,[]);return;
  end
  if strcmp(button.Enable,'on')
   if startsWith(string(button.Text),"Measure page ")
    if hardwareButton,return;end
    expectedTones=expectedTones+1;
   end
   button.ButtonPushedFcn(button,[]);
  end
 end
end
function stopDriver(driver)
if isvalid(driver),stop(driver);delete(driver);end
end
