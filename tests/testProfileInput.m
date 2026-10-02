function tests=testProfileInput
tests=functiontests(localfunctions);
end
function testFreezeAndReject(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
project=inkprof.createProject(fullfile(w,'project'),Printing=struct('printer',"Project printer",'paperSurface',"Matte",'ink',"Project ink"));
target=fullfile(w,'target');inkprof.createTarget(target,PatchCount=40,GraySteps=4,DPI=100);
session=fullfile(project,'measurements','synthetic');inkprof.prepareChart(fullfile(target,'target.ti2'),session);
doc=inkprof.importCgats(fullfile(target,'target.ti2'));doc.tables=doc.tables(1);doc.tables.signature="CTI3";
f=fullfile(w,'synthetic.ti3');inkprof.exportCgats(f,doc);
inkprof.importChartMeasurement(session,f);
files=dir(fullfile(session,'measurement-*.json'));source=fullfile(files(1).folder,files(1).name);
[folder,r]=inkprof.prepareProfileInput(source,ShowDialog=false);
verifyTrue(tc,isfile(fullfile(folder,'profiling.ti3')));verifyEqual(tc,r.patchCount,40);
[recipeFile,recipe]=inkprof.createProfileRecipe(folder,DataMode="storedXYZ",ShowDialog=false,Name="Test recipe");
verifyTrue(tc,isfile(recipeFile));verifyEqual(tc,string(recipe.colorimetry.mode),"storedXYZ");
verifyFalse(tc,recipe.colorimetry.fwaCompensation);
verifyEqual(tc,string(recipe.printing.printer),"Project printer");
verifyEqual(tc,string(recipe.printing.ink),"Project ink");
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
