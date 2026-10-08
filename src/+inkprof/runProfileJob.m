% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [jobFolder,status]=runProfileJob(recipeFile,options)
%RUNPROFILEJOB Run owned, logged, cancellable colprof job from a B2 recipe.
arguments
 recipeFile (1,1) string = ""
 options.ShowDialog (1,1) logical = true
 options.ColprofExecutable (1,1) string = ""
 options.TimeoutSeconds (1,1) double {mustBePositive,mustBeFinite} = 1800
end
jobFolder="";status=[];
if recipeFile==""
 [n,p]=uigetfile('recipe.json','Select the B2 profiling recipe');if isequal(n,0),return;end
 recipeFile=fullfile(p,n);
end
recipeFile=inkprof.internal.absolutePath(recipeFile);recipe=jsondecode(fileread(recipeFile));recipeHash=inkprof.internal.sha256(recipeFile);
assert(recipe.schemaVersion==1&&string(recipe.documentType)=="inkprof.profile-recipe",'inkprof:Recipe','Select a B2 recipe.');
if isfield(recipe.engine,'preRegularization')&&isfield(recipe.engine.preRegularization,'method')&&string(recipe.engine.preRegularization.method)=="inkprof-grid-regularization"
 error('inkprof:GridRegularizationRemoved','InkProf grid regularization (axial/Hessian) has been removed. Save a new B2 recipe. Existing ICC files and measurements are unchanged.');
end
inputFile=inkprof.internal.absolutePath(fullfile(fileparts(recipeFile),recipe.inputFile));
assert(inkprof.internal.sha256(inputFile)==string(recipe.inputSHA256),'inkprof:Integrity','B1 metadata changed.');
input=jsondecode(fileread(inputFile));base=fileparts(inputFile);
files=["measurement.json","chart.json","source.ti3","profiling.ti3"];
keys=["measurementSHA256","chartJSONSHA256","sourceTI3SHA256","profilingTI3SHA256"];
for k=1:numel(files)
 assert(inkprof.internal.sha256(fullfile(base,files(k)))==string(input.(keys(k))),'inkprof:Integrity','B1 input changed: %s.',files(k));
end
assert(string(input.profilingTI3SHA256)==string(recipe.profilingTI3SHA256),'inkprof:Integrity','Recipe TI3 hash mismatch.');
paths=inkprof.paths();exe=options.ColprofExecutable;
if exe==""
 bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'colprof');if ispc,exe=exe+".exe";end
end
exe=inkprof.internal.absolutePath(exe);assert(isfile(exe),'inkprof:Argyll','colprof executable not found.');
work=string(tempname);mkdir(work);cleanup=onCleanup(@()removeWork(work));
copyfile(recipeFile,fullfile(work,'recipe.json'));copyfile(inputFile,fullfile(work,'profile-input.json'));
copyfile(fullfile(base,'profiling.ti3'),fullfile(work,'source.ti3'));
assert(inkprof.internal.sha256(fullfile(work,'recipe.json'))==recipeHash&& ...
 inkprof.internal.sha256(fullfile(work,'profile-input.json'))==string(recipe.inputSHA256)&& ...
 inkprof.internal.sha256(fullfile(work,'source.ti3'))==string(recipe.profilingTI3SHA256),'inkprof:Integrity','Input changed while snapshotting.');
doc=inkprof.importCgats(fullfile(work,'source.ti3'));assert(numel(doc.tables)==1,'inkprof:Recipe','Expected one measured table.');
v=inkprof.cgatsData(doc,RGBScale=100);
assert(doc.tables.signature=="CTI3"&&isempty(v.cmyk)&&size(v.rgb,2)==3&&numel(v.ids)==recipe.patchCount,'inkprof:Recipe','Invalid RGB measurement table.');
mode=string(recipe.colorimetry.mode);
if mode=="spectral"
 assert(~isempty(v.spectra),'inkprof:Recipe','Spectral data is required.');
 preparation=string(recipe.colorimetry.inputPreparation);
 copyfile(fullfile(work,'source.ti3'),fullfile(work,'engine.ti3'));
elseif mode=="storedXYZ"
 assert(~isempty(v.xyz),'inkprof:Recipe','Stored XYZ is required.');
 t=doc.tables;drop=startsWith(t.fields,"SPEC_")|startsWith(t.fields,"SPECTRAL_NM")|startsWith(t.fields,"LAB_");
 t.fields=t.fields(~drop);t.data=t.data(:,~drop);
 keep=true(numel(t.metadata),1);
 for k=1:numel(t.metadata)
  key=string(t.metadata{k}(1));if startsWith(key,"SPECTRAL_")||(key=="KEYWORD"&&numel(t.metadata{k})>1&&startsWith(string(t.metadata{k}(2)),"SPECTRAL_")),keep(k)=false;end
  if key=="COLOR_REP",t.metadata{k}=["COLOR_REP","RGB_XYZ"];end
 end
 t.metadata=t.metadata(keep);doc.tables=t;inkprof.exportCgats(fullfile(work,'engine.ti3'),doc);
 out=inkprof.cgatsData(inkprof.importCgats(fullfile(work,'engine.ti3')),RGBScale=100);
 assert(isequal(v.xyz,out.xyz)&&isequal(v.rgb,out.rgb)&&isequal(v.ids,out.ids)&&isempty(out.spectra)&&isempty(out.lab),'inkprof:Integrity','XYZ preparation changed data.');
 preparation="Removed spectra, Lab and spectral metadata; stored XYZ and RGB unchanged.";
else,error('inkprof:Recipe','Unknown data mode.');end
hashes=struct;
for name=["recipe.json","profile-input.json","source.ti3","engine.ti3"]
 % JSON filename keys are written separately below to preserve dots.
 hashes.(matlab.lang.makeValidName(name))=inkprof.internal.sha256(fullfile(work,name));
end
request=struct('executable',exe,'timeoutSeconds',options.TimeoutSeconds,'inputPreparation',preparation,'files',hashes);
text=jsonencode(request,PrettyPrint=true);
for name=["recipe.json","profile-input.json","source.ti3","engine.ti3"]
 text=replace(text,'"'+string(matlab.lang.makeValidName(name))+'":','"'+name+'":');
end
fid=fopen(fullfile(work,'request.json'),'w');fprintf(fid,'%s',text);fclose(fid);
project=inkprof.internal.findProject(recipeFile);assert(project~="",'inkprof:Project','Recipe must belong to an InkProf project.');
parent=fullfile(project,'profiles','jobs');if ~isfolder(parent),mkdir(parent);end
jobFolder=fullfile(parent,string(java.util.UUID.randomUUID()));[ok,msg]=movefile(work,jobFolder);assert(ok,'inkprof:IO','%s',msg);clear cleanup
inkprof.internal.recordProjectStep(jobFolder,"Prepared isolated ICC job (B3)");
runtime=inkprof.checkPython(RequiredModules=strings(1,0));argv=java.util.ArrayList();
for a=[string(runtime.executable),fullfile(paths.Root,'profiles','profile_job.py'),jobFolder],argv.add(java.lang.String(char(a)));end
builder=java.lang.ProcessBuilder(argv);builder.directory(java.io.File(char(jobFolder)));builder.redirectErrorStream(true);
builder.redirectOutput(java.io.File(char(fullfile(jobFolder,'worker.log'))));process=builder.start();
fig=[];label=[];logBox=[];wait=[];started=tic;
stopCleanup=onCleanup(@()stopWorker(process,jobFolder));
if options.ShowDialog
 fig=uifigure('Name','InkProf - Profile job','Tag','InkProfProfileJob','Position',[170 120 900 640],'WindowStyle','alwaysontop');
 g=uigridlayout(fig,[4 1]);g.RowHeight={35,55,'1x',35};
 label=uilabel(g,'Text','Starting profile job...');uilabel(g,'Text',jobFolder,'WordWrap','on');
 logBox=uitextarea(g,'Editable','off');uibutton(g,'Text','Cancel job','Tag','CancelProfileJob','ButtonPushedFcn',@(~,~)cancelJob(jobFolder));
 fig.CloseRequestFcn=@(~,~)cancelJob(jobFolder);drawnow;focus(fig);
end
if ~isempty(fig)
 wait=uiprogressdlg(fig,'Title','Building ICC profile','Message','Argyll is working. Please wait.', ...
  'Indeterminate','on','Cancelable','on');
end
figCleanup=onCleanup(@()closeFig(fig));
while process.isAlive()
 if isfile(fullfile(jobFolder,'status.json'))
  status=jsondecode(fileread(fullfile(jobFolder,'status.json')));
  if ~isempty(label)&&isvalid(label),label.Text="Status: "+string(status.status);end
 end
 logFile=fullfile(jobFolder,'colprof.log');
 if ~isfile(logFile),logFile=fullfile(jobFolder,'colprof-pre.log');end
 log="";
 if isfile(logFile),log=string(fileread(logFile));end
 if ~isempty(wait)&&isvalid(wait)
  wait.Message=char(inkprof.internal.profileJobProgressMessage(log,toc(started)));
  if wait.CancelRequested,cancelJob(jobFolder);end
 end
 if ~isempty(logBox)&&isvalid(logBox)&&isfile(logFile)
  log=string(fileread(logFile));log=replace(log,char(13),newline);
  if strlength(log)>16000,log=extractAfter(log,strlength(log)-16000);end
  logBox.Value=splitlines(log);
 end
 drawnow;pause(.2);
end
if isfile(fullfile(jobFolder,'status.json')),status=jsondecode(fileread(fullfile(jobFolder,'status.json')));end
if isempty(status)||~any(string(status.status)==["succeeded","failed","cancelled"])
 status=struct('documentType',"inkprof.profile-job",'status',"failed",'error',"Worker exited unexpectedly; see worker.log");
 inkprof.internal.writeJson(fullfile(jobFolder,'status.json'),status);
end
closeFig(fig);clear figCleanup stopCleanup
inkprof.internal.recordProjectStep(jobFolder,"ICC job "+string(status.status));
fprintf('InkProf B3: %s\nJob: %s\n',status.status,jobFolder);
if isfield(status,'error'),fprintf('%s\n',status.error);end
if string(status.status)=="succeeded"
 fprintf('ICC candidate created; print/colour quality is not yet validated.\n');
 if options.ShowDialog&&isfield(recipe,'gradientPreview')&&recipe.gradientPreview.enabled
  try
   inkprof.internal.rgbGradientDialog(jobFolder);
  catch err
   warning('inkprof:GradientPreview','Profile built; gradient window could not open: %s',err.message);
  end
 end
end
end
function cancelJob(folder)
f=fopen(fullfile(folder,'cancel.request'),'w');if f>=0,fclose(f);end
end
function stopWorker(process,folder)
if ~process.isAlive(),return;end
cancelJob(folder);start=tic;
while process.isAlive()&&toc(start)<8,pause(.1);end
inkprof.internal.recordProjectStep(folder,"ICC job interrupted; cancellation requested");
end
function closeFig(f)
if ~isempty(f)&&isvalid(f),delete(f);end
end

function removeWork(p)
if isfolder(p),rmdir(p,'s');end
end
