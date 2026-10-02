function [out,files]=executeWorkflowStep(w,id,o)
% Operations always receive explicit project-local inputs and destinations.
out=struct;files=strings(0,1);
project=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
switch id
 case "definition"
  dest=w.newFolder('targets');mkdir(dest);
  source=get(o,'Source',"");
  if source==""
   file=fullfile(dest,'definition.ti1');fig=inkprof.designTarget(OutputFile=file);waitfor(fig);
   if ~isfile(file),cancel();end
  else
   inkprof.importTarget(source,RGBScale=get(o,'RGBScale',NaN));
   [~,stem,ext]=fileparts(source);file=fullfile(dest,stem+ext);copyfile(source,file);
   sidecar=fullfile(fileparts(source),stem+".json");
   if isfile(sidecar),copyfile(sidecar,fullfile(dest,stem+".json"));end
  end
  out.definition=file;files=allFiles(dest);
 case "render"
  dest=get(o,'Source',"");
  if dest==""
   dest=w.newFolder('targets');
   fig=inkprof.renderTarget(w.output('definition','definition'),OutputFolder=dest);waitfor(fig);
  else
   if isfile(dest),dest=fileparts(dest);end
   if ~startsWith(inkprof.internal.absolutePath(dest),w.Root+filesep)
    copy=w.newFolder('targets');copyfile(dest,copy);dest=copy;
   end
   targetRecord=jsondecode(fileread(fullfile(dest,'target.json')));
   assert(string(targetRecord.sourceSHA256)==inkprof.internal.sha256(w.output('definition','definition')), ...
    'inkprof:WorkflowMeasurement','The print target does not belong to the selected RGB definition.');
  end
  if ~isfile(fullfile(dest,'manifest.json')),cancel();end
  inkprof.verifyPackage(dest);out=inkprof.internal.workflowTiffOutputs(fullfile(dest,'target.ti2'));files=packageFiles(dest);
 case {"measurement","c2measurement","refinemeasurement"}
  parent=struct('measurement','render','c2measurement','c2','refinemeasurement','refine');
  target=w.output(parent.(id),'target');source=get(o,'Source',"");
  if source==""
   dest=w.newFolder('measurements');inkprof.prepareChart(target,dest);
   dialog=inkprof.measureChart(target,SessionFolder=dest,ScanMode="paired",Condition="M0");
   waitfor(dialog.Figure);
   source=selectMeasurement(dest);
  else
   [~,~,ext]=fileparts(source);
   if lower(ext)==".json"
    % A revision is a package: preserve chart, TI3, raw readings and source.
    if ~startsWith(inkprof.internal.absolutePath(source),w.Root+filesep)
     dest=w.newFolder('measurements');copyfile(fileparts(source),dest);
     [~,stem,ext]=fileparts(source);source=fullfile(dest,stem+ext);
    end
   else
    [~,source]=inkprof.importMeasurement(source,TargetFile=target,SessionFolder=w.newFolder('measurements'),ShowPreview=true);
   end
  end
  if source=="",cancel();end
  files=validateMeasurement(source,target);out.measurement=source;
 case "review"
  source=w.output('measurement','measurement');
  assert(get(o,'Confirmed',false),'inkprof:Cancelled','Measurement review has not been confirmed.');
  note=get(o,'Notes',"");assert(strlength(strtrim(note))>0,'inkprof:Workflow','Enter your assessment of measurements and remeasurements.');
  file=fullfile(w.newFolder('reports'),'measurement-review.json');mkdir(fileparts(file));
  inkprof.internal.writeJson(file,struct('documentType',"inkprof.measurement-review",'measurement',w.relative(source), ...
   'measurementSHA256',inkprof.internal.sha256(source),'notes',note,'utc',utc()));
  out.review=file;files=[file;source];
 case "input"
  [folder,~]=inkprof.prepareProfileInput(w.output('measurement','measurement'),ProjectFolder=w.Root,Name=string(project.name));
  if folder=="",cancel();end
  out.input=fullfile(folder,'profile-input.json');files=allFiles(folder);
 case "recipe"
  [file,~]=inkprof.createProfileRecipe(fileparts(w.output('input','input')),Printing=project.printing,ProjectPrinting=true,SyncProjectFWA=false);
  if file=="",cancel();end
  out.recipe=file;files=file;
 case "profile"
  if isfield(w.State,'activeContinuation')
   link=w.State.activeContinuation;
   [out,files]=continueProfile(w,fileparts(w.resolve(link.proposal)),w.resolve(link.measurement),o,w.State.cycle);
   return
  end
  if get(o,'Mode',"automatic")=="manual"
   [folder,status]=inkprof.runProfileJob(w.output('recipe','recipe'));
   assert(~isempty(status)&&string(status.status)=="succeeded",'inkprof:Workflow','The profiling job did not complete.');
   out.job=fullfile(folder,'status.json');out.profile=fullfile(folder,'result','profile.icc');
   files=[allFiles(folder);w.output('recipe','recipe')];
  else
   role=get(o,'RoleFile',"");
   if role~=""
    d=w.newFolder('sources');mkdir(d);copyfile(role,fullfile(d,'roles.json'));role=fullfile(d,'roles.json');
   end
   [folder,r]=inkprof.iterateProfile(w.output('measurement','measurement'),ProjectFolder=w.Root, ...
    Name="Iteration "+w.State.cycle,RoleFile=role,MaxNewPatches=get(o,'MaxNewPatches',100), ...
    NormTarget=get(o,'NormTarget',1),GrayWeight=get(o,'GrayWeight',2));
   out.job=fullfile(folder,r.selectedJob,'status.json');out.profile=fullfile(folder,r.profileFile);
   out.iteration=fullfile(folder,'iteration.json');out.verification=fullfile(folder,r.verification.folder,'verification.json');
   files=profileFiles(out);
  end
 case "checks"
  job=fileparts(w.output('profile','job'));
  [~,a]=inkprof.checkProfileFit(job);[~,b]=inkprof.checkProfileGrid(job);[c1,c]=inkprof.checkProfileC1(job);
  assert(c1.allNegativeControlsDetected&&isempty(c1.grossFailureAlerts),'inkprof:WorkflowNumerical','C1 reports serious problems. Review the reports before C2.');
  out.fit=a;out.grid=b;out.c1=c;files=[a;b;c];
 case "c2"
  s=w.State.steps.profile.outputs;
  if isfield(s,'verification')
   reference=w.resolve(s.verification);folder=fileparts(reference);
  else
   [folder,~]=inkprof.createVerificationTarget(fileparts(w.output('profile','job')),OutputFolder=w.newFolder('targets'),Name="C2 iteration "+w.State.cycle);
   reference=fullfile(folder,'verification.json');
  end
  out=inkprof.internal.workflowTiffOutputs(fullfile(folder,'print','target.ti2'));out.reference=reference;files=[reference;packageFiles(fullfile(folder,'print'))];
 case "c3"
  project=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
  [~,file]=inkprof.checkVerificationTarget(w.output('c2','reference'),w.output('c2measurement','measurement'),PrintSettings=project.printing);
  out.report=file;files=allFiles(fileparts(file));
 case "feedback"
  [~,file]=inkprof.analyseVerification(w.output('c3','report'));
  out.feedback=file;files=file;
 case "approve"
  assert(get(o,'Confirmed',false),'inkprof:Cancelled','Final approval is missing.');
  note=get(o,'Notes',"");assert(strlength(strtrim(note))>0,'inkprof:Workflow','Enter the intended use and accepted limitations.');
  file=fullfile(w.newFolder('reports'),'approval.json');mkdir(fileparts(file));
  inkprof.internal.writeJson(file,struct('documentType',"inkprof.user-approval",'cycle',w.State.cycle,'utc',utc(), ...
   'profileSHA256',inkprof.internal.sha256(w.output('profile','profile')),'report',w.relative(w.output('c3','report')), ...
   'reportSHA256',inkprof.internal.sha256(w.output('c3','report')),'notes',note,'isoCertification',false));
  out.approval=file;files=file;
 case "export"
  folder=w.newFolder('exports');mkdir(folder);
  [file,~]=inkprof.saveICC(w.output('profile','profile'),fullfile(folder,'profile.icc'));
  for pair={'approve','approval';'c3','report';'feedback','feedback'}'
   src=w.output(pair{1},pair{2});[~,stem,ext]=fileparts(src);copyfile(src,fullfile(folder,stem+ext));
  end
  copyfile(fullfile(w.Root,'workflow.json'),fullfile(folder,'workflow-snapshot.json'));
  copyfile(fullfile(w.Root,'inkprof-project.json'),fullfile(folder,'project-snapshot.json'));
  report=inkprof.internal.writeWorkflowFinalReport(w,file,folder,User=get(o,'ReportUser',get(project,'user',string(java.lang.System.getProperty('user.name')))));
  out.profile=file;out.finalReport=report.html;out.reportJSON=report.json;out.reportText=report.text;out.reportPDF=report.pdf;
  if isfield(o,'ICCDestination')||isfield(o,'ReportDestination')
   assert(isfield(o,'ICCDestination')&&isfield(o,'ReportDestination'),'inkprof:Delivery','Choose save locations for both the ICC profile and report.');
   receipt=inkprof.internal.saveWorkflowDelivery(folder,string(o.ICCDestination),string(o.ReportDestination),Overwrite=get(o,'Overwrite',false));
   out.delivery=fullfile(folder,'delivery.json');inkprof.internal.writeJson(out.delivery,receipt);
  end
  files=allFiles(folder);
 case "refine"
  assert(get(o,'Confirmed',false),'inkprof:Cancelled','Review measurement errors before adding patches.');
  [~,folder]=inkprof.refineVerification(w.output('c3','report'),Name="Iteration "+(w.State.cycle+1), ...
   MaxNewPatches=get(o,'MaxNewPatches',100),NormTarget=get(o,'NormTarget',1),GrayWeight=get(o,'GrayWeight',2),CreatePrint=true);
  inkprof.internal.writeJson(fullfile(folder,'workflow-review.json'),struct('notes',get(o,'Notes',""),'utc',utc()));
  out=inkprof.internal.workflowTiffOutputs(fullfile(folder,'refinement-print','print','target.ti2'));out.proposal=fullfile(folder,'proposal.json');
  files=allFiles(folder);assert(isfile(out.target),'inkprof:Workflow','No new printable patches were proposed. Review the feedback.');
 case "continue"
  [out,files]=continueProfile(w,fileparts(w.output('refine','proposal')),w.output('refinemeasurement','measurement'),o,w.State.cycle+1);
 otherwise
  error('inkprof:Workflow','Unknown operation.');
end
end
function v=get(s,k,fallback)
if isfield(s,k),v=s.(k);else,v=fallback;end
end
function cancel(),error('inkprof:Cancelled','Cancelled. No step has been marked complete.');end
function value=utc(),value=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));end
function paths=allFiles(folder)
f=dir(fullfile(folder,'**','*'));f=f(~[f.isdir]);paths=string(fullfile({f.folder},{f.name}))';
end
function files=profileFiles(out)
% Freeze existing outputs only; later checks create new files in these folders.
files=[allFiles(fileparts(out.iteration));allFiles(fileparts(out.job))];files=unique(files);
end
function file=selectMeasurement(folder)
% Native file dialogs filter by extension, not filename-prefix patterns.
[n,p]=uigetfile({'*.json','Measurement revision JSON (*.json)'}, ...
 'Select a saved, accepted measurement revision (measurement-*.json)',char(folder));
file="";if ~isequal(n,0),file=string(fullfile(p,n));end
end
function files=validateMeasurement(file,target)
m=jsondecode(fileread(file));
assert(isfield(m,'documentType')&&string(m.documentType)=="inkprof.chart-measurement"&&m.complete,'inkprof:WorkflowMeasurement','Select a complete measurement-*.json file.');
[parent,stem]=fileparts(file);chartFile=fullfile(parent,'chart.json');ti3=fullfile(parent,stem+".ti3");
assert(isfile(chartFile)&&isfile(ti3),'inkprof:WorkflowMeasurement','The measurement revision chart.json and TI3 are missing.');
assert(inkprof.internal.sha256(chartFile)==string(m.chartJSONSHA256)&&inkprof.internal.sha256(ti3)==string(m.sourceTI3SHA256),'inkprof:Integrity','Measurement input checksums do not match.');
chart=jsondecode(fileread(chartFile));
assert(string(chart.sourceSHA256)==inkprof.internal.sha256(target),'inkprof:WorkflowMeasurement','The measurement does not belong to the selected print target.');
files=[string(file);chartFile;ti3];
end

function files=packageFiles(folder)
r=jsondecode(fileread(fullfile(folder,'manifest.json')));
files=[string(fullfile(folder,'manifest.json'));fullfile(folder,string({r.files.name})')];
end
function [out,files]=continueProfile(w,proposal,source,o,cycle)
[folder,r]=inkprof.continueRefinement(proposal,source,Name="Iteration "+cycle, ...
 MaxNewPatches=get(o,'MaxNewPatches',100),NormTarget=get(o,'NormTarget',1),GrayWeight=get(o,'GrayWeight',2));
iteration=jsondecode(fileread(fullfile(folder,'iteration.json')));
out=struct('job',fullfile(folder,iteration.selectedJob,'status.json'),'profile',r.profileFile, ...
 'iteration',fullfile(folder,'iteration.json'),'verification',fullfile(r.verificationFolder,'verification.json'));
files=[profileFiles(out);source;fullfile(proposal,'proposal.json')];
end
