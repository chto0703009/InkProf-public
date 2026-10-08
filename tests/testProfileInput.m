% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testProfileInput
tests=functiontests(localfunctions);
end
function testFreezeAndReject(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
project=inkprof.createProject(fullfile(w,'project'),Printing=struct('printer',"Project printer",'paperSurface',"Matte",'ink',"Project ink",'dryingHours',"24",'profileName',"Project ICC",'profileDescription',"Project description",'profileDataMode',"storedXYZ",'profileB2AQuality',"medium"));
target=fullfile(w,'target');inkprof.createTarget(target,PatchCount=40,GraySteps=4,DPI=100);
session=fullfile(project,'measurements','synthetic');inkprof.prepareChart(fullfile(target,'target.ti2'),session);
doc=inkprof.importCgats(fullfile(target,'target.ti2'));doc.tables=doc.tables(1);doc.tables.signature="CTI3";
f=fullfile(w,'synthetic.ti3');inkprof.exportCgats(f,doc);
inkprof.importChartMeasurement(session,f);
files=dir(fullfile(session,'measurement-*.json'));source=fullfile(files(1).folder,files(1).name);
[folder,r]=inkprof.prepareProfileInput(source,ShowDialog=false);
verifyTrue(tc,isfile(fullfile(folder,'profiling.ti3')));verifyEqual(tc,r.patchCount,40);
[~,inherited]=inkprof.createProfileRecipe(folder,ShowDialog=false);
verifyEqual(tc,inherited.name,"Project ICC");verifyEqual(tc,inherited.description,"Project description");
verifyEqual(tc,inherited.colorimetry.mode,"storedXYZ");verifyEqual(tc,inherited.engine.b2aQuality,"medium");
verifyFalse(tc,inherited.gradientPreview.enabled);
[~,preview]=inkprof.createProfileRecipe(folder,ShowDialog=false,PreRegularization="argyll-colprof", ...
 PreRegularizationAvgDev=0.4,GradientPreview=true,Smoothing=0.22);
verifyTrue(tc,preview.gradientPreview.enabled);verifyEqual(tc,preview.engine.smoothing,0.22);
verifyEqual(tc,preview.engine.preRegularization.method,"argyll-colprof-a2b-resample");
verifyEqual(tc,preview.engine.preRegularization.avgdev,0.4);
args=string(preview.engine.plannedArguments);verifyTrue(tc,any(args=="-s"));verifyEqual(tc,preview.engine.gamutMapping.compressionPercent,20);idx=find(args=="-r");verifyEqual(tc,str2double(args(idx+1)),0.22);
% The InkProf grid regularization (axial/Hessian) has been removed.
verifyError(tc,@()inkprof.createProfileRecipe(folder,ShowDialog=false,PreRegularization="inkprof-axial"),?MException);
[~,raw]=inkprof.createProfileRecipe(folder,ShowDialog=false,GradientPreview=true);
verifyFalse(tc,raw.gradientPreview.enabled);
[recipeFile,recipe]=inkprof.createProfileRecipe(folder,DataMode="storedXYZ",ShowDialog=false,Name="Test recipe");
verifyTrue(tc,isfile(recipeFile));verifyEqual(tc,string(recipe.colorimetry.mode),"storedXYZ");
verifyFalse(tc,recipe.colorimetry.fwaCompensation);
verifyEqual(tc,string(recipe.printing.printer),"Project printer");
verifyEqual(tc,string(recipe.printing.ink),"Project ink");
verifyEqual(tc,string(recipe.printing.dryingHours),"24");
verifyTrue(tc,any(string(recipe.engine.plannedArguments)=="-Z"));
verifyError(tc,@()inkprof.createProfileRecipe(folder,DataMode="spectral",ShowDialog=false),'inkprof:RecipeData');
readback=jsondecode(fileread(recipeFile));verifyEqual(tc,string(readback.name),"Test recipe");
% Simulate transfer: the original root disappears; frozen B1/B2 must still run.
oldProject=project;project=fullfile(w,'moved-project');movefile(oldProject,project);
folder=replace(folder,oldProject,project);recipeFile=replace(recipeFile,oldProject,project);source=replace(source,oldProject,project);
check=inkprof.verifyProject(project);verifyTrue(tc,check.passed,strjoin(check.issues,newline));
if isunix
 fake=fullfile(w,'fake-colprof');fid=fopen(fake,'w');fprintf(fid,'#!/bin/sh\nif [ "$1" = "-?" ]; then echo "Fake colprof test"; exit 1; fi\nexit 7\n');fclose(fid);java.io.File(char(fake)).setExecutable(true);
 [job,status]=inkprof.runProfileJob(recipeFile,ShowDialog=false,ColprofExecutable=fake);
 verifyEqual(tc,string(status.status),"failed");verifyEqual(tc,status.exitCode,7);
 data=inkprof.cgatsData(inkprof.importCgats(fullfile(job,'engine.ti3')),RGBScale=100);
 verifyEmpty(tc,data.spectra);verifyEmpty(tc,data.lab);verifyEqual(tc,size(data.xyz,1),40);
 verifyFalse(tc,isfolder(fullfile(job,'result')));
 fid=fopen(fake,'w');fprintf(fid,'#!/bin/sh\nif [ "$1" = "-?" ]; then echo "Fake colprof test"; exit 1; fi\nexec sleep 30\n');fclose(fid);
 t=timer('ExecutionMode','fixedSpacing','Period',.5,'TimerFcn',@cancelProfileWindow);
 timerCleanup=onCleanup(@()deleteTimer(t));start(t);
 [cancelledJob,cancelled]=inkprof.runProfileJob(recipeFile,ShowDialog=true,ColprofExecutable=fake);
 deleteTimer(t);verifyEqual(tc,string(cancelled.status),"cancelled");
 verifyFalse(tc,isfolder(fullfile(cancelledJob,'result')));
 verifyEmpty(tc,findall(groot,'Tag','InkProfProfileJob'));
end

verifyEqual(tc,inkprof.internal.sha256(fullfile(folder,'measurement.json')),inkprof.internal.sha256(source));
saved=jsondecode(fileread(source));saved.complete=false;inkprof.internal.writeJson(source,saved);
verifyError(tc,@()inkprof.prepareProfileInput(source,ShowDialog=false),'inkprof:ProfileIncomplete');
saved.complete=true;saved.data.rgb(1,1)=saved.data.rgb(1,1)+1;inkprof.internal.writeJson(source,saved);
verifyError(tc,@()inkprof.prepareProfileInput(source,ShowDialog=false),'inkprof:Integrity');
verifyEqual(tc,inkprof.internal.sha256(fullfile(folder,'profiling.ti3')),string(r.profilingTI3SHA256));
end

function cancelProfileWindow(t,~)
b=findall(groot,'Tag','CancelProfileJob');if isempty(b),return;end
stop(t);cb=b.ButtonPushedFcn;cb(b,[]);
end
function deleteTimer(t)
if isvalid(t),stop(t);delete(t);end
end

function testPositionedMXFWithoutXYZReference(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
project=inkprof.createProject(fullfile(w,'project'));
[~,source,session]=inkprof.importMeasurement(fullfile(root,'tests','fixtures','rgb-reflectance.mxf'), ...
 SessionFolder=fullfile(project,'measurements','import'),ShowPreview=false);
[folder,r]=inkprof.prepareProfileInput(source,ShowDialog=false);
verifyFalse(tc,r.rowDirectionCheck.available);
verifyTrue(tc,r.layoutEvidence.available);
verifyFalse(tc,r.layoutEvidence.physicalScanDirectionVerified);
verifyTrue(tc,isfile(fullfile(folder,'original.mxf')));
f=fopen(fullfile(session,'original.mxf'),'a');fprintf(f,' ');fclose(f);
verifyError(tc,@()inkprof.prepareProfileInput(source,ShowDialog=false),'inkprof:Integrity');
end

function testFWARecipeFromExistingMeasurement(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
project=inkprof.createProject(fullfile(w,'project'));
target=fullfile(w,'target');inkprof.createTarget(target,PatchCount=40,GraySteps=4,DPI=100);
session=fullfile(project,'measurements','synthetic');inkprof.prepareChart(fullfile(target,'target.ti2'),session);
doc=inkprof.importCgats(fullfile(target,'target.ti2'));doc.tables=doc.tables(1);doc.tables.signature="CTI3";
t=doc.tables;t.metadata{end+1}=["TARGET_INSTRUMENT","X-Rite i1 Pro 2"];
t.metadata{end+1}=["INKPROF_MEASUREMENT_CONDITION","M0"];
t.metadata{end+1}=["SPECTRAL_BANDS","36"];t.metadata{end+1}=["SPECTRAL_START_NM","380"];t.metadata{end+1}=["SPECTRAL_END_NM","730"];
for wave=380:10:730,t.fields(end+1)="SPEC_"+wave;t.data(:,end+1)={"50"};end
 doc.tables=t;f=fullfile(w,'synthetic.ti3');inkprof.exportCgats(f,doc);
inkprof.importChartMeasurement(session,f);files=dir(fullfile(session,'measurement-*.json'));source=fullfile(files(1).folder,files(1).name);
[folder,~]=inkprof.prepareProfileInput(source,ShowDialog=false);
[oldFile,old]=inkprof.createProfileRecipe(folder,ShowDialog=false);digest=inkprof.internal.sha256(source);
[newFile,new]=inkprof.createProfileRecipe(folder,Printing=struct('fwaCompensation',true),ShowDialog=false);
manifest=jsondecode(fileread(fullfile(project,'inkprof-project.json')));verifyTrue(tc,manifest.printing.fwaCompensation);
verifyFalse(tc,old.colorimetry.fwaCompensation);verifyTrue(tc,new.colorimetry.fwaCompensation);
verifyNotEqual(tc,oldFile,newFile);verifyTrue(tc,isfile(oldFile));
verifyEqual(tc,string(new.colorimetry.fwaIlluminant),"D50");verifyFalse(tc,any(new.engine.plannedArguments=="-f"));
verifyEqual(tc,string(new.colorimetry.fwaPreparation),"white-reference-spec2cie-v1");
verifyGreaterThan(tc,new.colorimetry.paperWhiteReference.count,0);
[~,withPre]=inkprof.createProfileRecipe(folder,Printing=struct('fwaCompensation',true),PreRegularization="argyll-colprof",ShowDialog=false);
verifyFalse(tc,any(withPre.engine.preRegularization.plannedArguments=="-f"));
verifyFalse(tc,any(withPre.engine.preRegularization.plannedArguments=="-i"));
verifyEqual(tc,inkprof.internal.sha256(source),digest);
verifyError(tc,@()inkprof.createProfileRecipe(folder,DataMode="storedXYZ",ShowDialog=false),'inkprof:FWA');
% Save the later choice through the actual B2 UI while run() owns the lock.
workflow=inkprof.ProjectWorkflow(project);state=workflow.State;
for key=string(fieldnames(state.steps))',state.steps.(key).status="completed";end
state.steps.input.outputs.input=workflow.relative(fullfile(folder,'profile-input.json'));
inkprof.internal.writeJson(fullfile(project,'workflow.json'),state);workflow.reload();
t=timer('ExecutionMode','fixedSpacing','Period',.5,'TimerFcn',@saveRecipeWithoutFWA);
timerCleanup=onCleanup(@()deleteTimer(t));start(t);workflow.run("recipe");deleteTimer(t);
manifest=jsondecode(fileread(fullfile(project,'inkprof-project.json')));verifyFalse(tc,manifest.printing.fwaCompensation);
verifyTrue(tc,workflow.valid('input'));verifyTrue(tc,workflow.valid('recipe'));verifyFalse(tc,workflow.valid('profile'));
saved=jsondecode(fileread(workflow.output('recipe','recipe')));verifyFalse(tc,saved.colorimetry.fwaCompensation);
verifyFalse(tc,isfile(fullfile(project,'.workflow.lock')));

end

function saveRecipeWithoutFWA(t,~)
b=findall(groot,'Tag','SaveProfileRecipe');c=findall(groot,'Tag','RecipeFWA');
if isempty(b)||isempty(c),return;end
stop(t);c.Value=false;cb=b.ButtonPushedFcn;cb(b,[]);
end
