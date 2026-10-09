% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [out,files]=executeWorkflowStep(w,id,o)
% Operations always receive explicit project-local inputs and destinations.
out=struct;files=strings(0,1);
project=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
if w.mode()=="verification"&&id=="profile"

 source=string(get(o,'Source',""));assert(isfile(source),'inkprof:Input','Select an existing ICC file.');
 dest=w.newFolder('profiles');mkdir(dest);
 conversion=struct('converted',false,'method',"Original ICC; native LittleCMS verification");
 calculation=inkprof.internal.calculationProgress("Importing existing ICC","Validating the selected ICC and saving the project copy."); %#ok<NASGU>
 [profile,receipt]=inkprof.saveICC(source,fullfile(dest,'profile.icc'));
 paths=inkprof.paths();
 inkprof.runPython(fullfile(paths.Root,'analysis','validate_external_profile.py'),profile,RequiredModules=["numpy","colour"]);
 [~,name,ext]=fileparts(source);
 metadata=struct('documentType',"inkprof.imported-profile",'profileSHA256',receipt.sha256, ...
  'originalName',name+ext,'trainingData',"unavailable",'modified',conversion.converted,'conversion',conversion);
 file=fullfile(dest,'source.json');inkprof.internal.writeJson(file,metadata);
 out=struct('profile',profile,'job',file);files=allFiles(dest);return
end
switch id
 case "numericalExport"
  calculation=inkprof.internal.calculationProgress("Saving ICC and certificate","Creating the PDF, HTML, figures and delivery copies."); %#ok<NASGU>
  assert(get(o,'Confirmed',false)&&strlength(strtrim(string(get(o,'Notes',""))))>0, ...
   'inkprof:Cancelled','Record your decision and confirm the absence of separate print verification.');
  folder=w.newFolder('exports');mkdir(folder);
  [file,~]=inkprof.saveICC(w.output('profile','profile'),fullfile(folder,'profile.icc'));
  report=inkprof.internal.writeNumericalReport(w,file,folder,string(o.Notes));
  out=struct('profile',file,'finalReport',report.html,'reportJSON',report.json,'reportText',report.text,'reportPDF',report.pdf);
  inkprof.internal.prepareICCVariants(w,folder);
  if isfield(o,'ICCDestination')||isfield(o,'ReportDestination')
   assert(isfield(o,'ICCDestination')&&isfield(o,'ReportDestination'),'inkprof:Delivery','Choose both delivery destinations.');
   receipt=inkprof.internal.saveWorkflowDelivery(folder,string(o.ICCDestination),string(o.ReportDestination),Overwrite=get(o,'Overwrite',false));
   out.delivery=fullfile(folder,'delivery.json');inkprof.internal.writeJson(out.delivery,receipt);
  end
  files=allFiles(folder);
 case "compare"
  calculation=inkprof.internal.calculationProgress("Comparing ICC profiles","Sampling both profiles on common colour grids and creating comparison reports.");
  previous=inkprof.internal.comparisonParent(w.State);
  assert(~isempty(previous),'inkprof:Workflow','A previous iteration is required.');
  old=w.resolve(previous.outputs.profile);
  registered=reshape(previous.artifacts,1,[]);
  match=find(string({registered.path})==string(previous.outputs.profile),1);
  assert(~isempty(match)&&inkprof.internal.sha256(old)==string(registered(match).sha256),'inkprof:Integrity','Previous profile is missing or changed.');
  dest=w.newFolder('comparisons');paths=inkprof.paths();bin=inkprof.internal.argyllBin("");
  inkprof.runPython(fullfile(paths.Root,'analysis','compare_profiles.py'), ...
   [old,w.output('profile','profile'),fullfile(bin,'xicclu'),dest,"--iteration",string(w.State.cycle)], ...
   RequiredModules=["numpy","colour","reportlab"],TimeoutSeconds=240);
  out.comparison=fullfile(dest,'comparison.json');out.report=fullfile(dest,'comparison.html');out.pdf=fullfile(dest,'comparison.pdf');files=allFiles(dest);
  clear calculation;web(char(out.report),'-browser');
 case "definition"
  dest=w.newFolder('targets');mkdir(dest);
  source=string(get(o,'Source',""));
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
   calculation=inkprof.internal.calculationProgress("Preparing measurement","Checking the target and preparing the measurement session.");
   dest=w.newFolder('measurements');inkprof.prepareChart(target,dest);clear calculation;
   dialog=inkprof.measureChart(target,SessionFolder=dest,ScanMode="paired",Condition="M0");
   waitfor(dialog.Figure);
   source=inkprof.selectMeasurementRevision(dest,target);
  else
   [~,~,ext]=fileparts(source);
   if lower(ext)==".json"
    % A revision is a package: preserve chart, TI3, raw readings and source.
    if ~startsWith(inkprof.internal.absolutePath(source),w.Root+filesep)
     calculation=inkprof.internal.calculationProgress("Importing measurement revision","Copying the measurement and its supporting files into the project.");
     dest=w.newFolder('measurements');copyfile(fileparts(source),dest);clear calculation;
     [~,stem,ext]=fileparts(source);source=fullfile(dest,stem+ext);
    end
   else
    calculation=inkprof.internal.calculationProgress("Importing measurements","Converting measurement data and validating patch identities.");
    [imported,source]=inkprof.importMeasurement(source,TargetFile=target,SessionFolder=w.newFolder('measurements'),ShowPreview=false);
    clear calculation;inkprof.previewMeasurement(fileparts(source),imported);
   end
  end
  if source=="",cancel();end
  calculation=inkprof.internal.calculationProgress("Validating saved measurement","Checking file integrity and matching the measured patches to the printed target.");
  files=validateMeasurement(source,target);out.measurement=source;clear calculation;
  if any(id==["c2measurement","refinemeasurement"])&&isfield(w.State.steps.refine.outputs,'c2reference')&& ...
    string(w.State.steps.refine.outputs.target)==string(w.State.steps.c2.outputs.target)
   reference=w.output('refine','c2reference');
   calculation=inkprof.internal.calculationProgress("Analysing combined measurement","Checking C2 colours separately and registering the image/C2 training measurements.");
   [~,out.c3report]=inkprof.checkVerificationTarget(reference,source,ShowDialog=false,PrintSettings=project.printing);
   clear calculation;files=[files;allFiles(fileparts(out.c3report))];
  end
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
   selectedRecipe=jsondecode(fileread(w.output('recipe','recipe')));compression=20;
   if isfield(selectedRecipe.engine,'gamutMapping')&&isstruct(selectedRecipe.engine.gamutMapping)
    compression=selectedRecipe.engine.gamutMapping.compressionPercent;
   end
   whiteReference=struct;if isfield(selectedRecipe.colorimetry,'paperWhiteReference'),whiteReference=selectedRecipe.colorimetry.paperWhiteReference;end
   [folder,r]=inkprof.iterateProfile(w.output('measurement','measurement'),PaperWhiteReference=whiteReference,ProjectFolder=w.Root,PerceptualCompression=compression, ...
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
  referenceSet=get(o,'ReferenceSet',"");
  if referenceSet~=""
   % Fixed reference set (Lab or device RGB): same TIFF16/TI2 print package, patch names kept in verification.json.
   calculation=inkprof.internal.calculationProgress("Creating profile test target","Applying the ICC once to the reference colours and preparing TIFF16 files."); %#ok<NASGU>
   if w.mode()=="verification",jobFolder=fileparts(w.output('profile','profile'));else,jobFolder=fileparts(w.output('profile','job'));end
   [folder,~]=inkprof.createVerificationTarget(jobFolder,ExternalProfile=w.mode()=="verification", ...
    OutputFolder=w.newFolder('targets'),Name="Profile test "+string(referenceName(referenceSet)),ReferenceSet=referenceSet, ...
    Repeats=get(o,'Repeats',12),PlanPaper=get(o,'PlanPaper',true),DPI=get(o,'DPI',300));
   reference=fullfile(folder,'verification.json');
   out=inkprof.internal.workflowTiffOutputs(fullfile(folder,'print','target.ti2'));out.reference=reference;files=allFiles(folder);return
  end
  if w.mode()=="verification"
   calculation=inkprof.internal.calculationProgress("Creating verification target","Selecting colours, applying the imported ICC once and preparing TIFF16 files."); %#ok<NASGU>
   count=get(o,'PatchCount',575);validateattributes(count,{'double'},{'scalar','integer','>=',64,'<=',2000});
   project.verificationPatchCount=count;inkprof.internal.writeJson(fullfile(w.Root,'inkprof-project.json'),project);
   inkprof.updateProject(w.Root,Step="verification-patch-count");
   gray=round(count*.14);challenge=round(count*.096);repeats=round(count*.07);colours=count-gray-challenge-repeats;
   [folder,~]=inkprof.createVerificationTarget(fileparts(w.output('profile','profile')),ExternalProfile=true, ...
    OutputFolder=w.newFolder('targets'),Name="Existing ICC verification",ColourPatches=colours,GrayPatches=gray, ...
    ChallengePatches=challenge,Repeats=repeats,PlanPaper=get(o,'PlanPaper',true),DPI=get(o,'DPI',300));
   reference=fullfile(folder,'verification.json');
   out=inkprof.internal.workflowTiffOutputs(fullfile(folder,'print','target.ti2'));out.reference=reference;files=allFiles(folder);return
  end
  s=w.State.steps.profile.outputs;
  if isfield(s,'verification')
   reference=w.resolve(s.verification);
   folder=inkprof.internal.relayoutVerification(reference,w.newFolder('targets'));reference=fullfile(folder,'verification.json');
  else
   [folder,~]=inkprof.createVerificationTarget(fileparts(w.output('profile','job')),OutputFolder=w.newFolder('targets'),Name="C2 iteration "+w.State.cycle,PlanPaper=true);
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
  inkprof.internal.prepareICCVariants(w,folder);
  if isfield(o,'ICCDestination')||isfield(o,'ReportDestination')
   assert(isfield(o,'ICCDestination')&&isfield(o,'ReportDestination'),'inkprof:Delivery','Choose save locations for both the ICC profile and report.');
   receipt=inkprof.internal.saveWorkflowDelivery(folder,string(o.ICCDestination),string(o.ReportDestination),Overwrite=get(o,'Overwrite',false));
   out.delivery=fullfile(folder,'delivery.json');inkprof.internal.writeJson(out.delivery,receipt);
  end
  if w.mode()=="verification"&&isfield(o,'BundleDestination')
   destination=fullfile(string(o.BundleDestination),"InkProf-verification-"+string(java.util.UUID.randomUUID()));
   assert(~isfolder(destination),'inkprof:Exists','Report destination exists.');copyfile(folder,destination);
  end
  files=allFiles(folder);
 case "refine"
  assert(get(o,'Confirmed',false),'inkprof:Cancelled','Record why you are adding patches.');
  method=string(get(o,'Method',"errors"));
  if method=="image"
   reference="";
   if get(o,'IncludeC2',false),reference=string(get(o,'C2Reference',""));assert(reference~="",'inkprof:Verification','Select the unprinted C2 reference.');end
   if isfield(o,'ExistingProposal')
    saved=jsondecode(fileread(o.ExistingProposal));assert(string(saved.sourceProfileSHA256)==inkprof.internal.sha256(w.output('profile','profile')),'inkprof:Integrity','Saved image selection belongs to another profile.');
    [proposal,folder]=inkprof.rebuildImageRefinement(string(o.ExistingProposal),VerificationFile=reference,PlanPaper=get(o,'PlanPaper',true));
   else
   [proposal,folder]=inkprof.refineFromImage(w.output('profile','job'),FitReport=w.output('checks','fit'),VerificationFile=reference, ...
    Image=string(get(o,'Image',"")),SourceProfile=string(get(o,'SourceProfile',"embedded")), ...
    ROI=get(o,'ROI',[]),MaxNewPatches=get(o,'MaxNewPatches',100), ...
    MinSpacingPercent=get(o,'MinSpacingPercent',1),NeighborRadiusPercent=get(o,'NeighborRadiusPercent',0), ...
    Name="Iteration "+(w.State.cycle+1)+" - image colours",ShowDialog=get(o,'ShowDialog',true), ...
    PlanPaper=get(o,'PlanPaper',true),CreatePrint=true);
   end
   assert(~isempty(proposal)&&folder~="",'inkprof:Cancelled','Image refinement cancelled.');
  else
   assert(method=="errors",'inkprof:Workflow','Unknown refinement method.');
   [ok,why]=w.valid('feedback');assert(ok,'inkprof:WorkflowBlocked','Error-driven refinement requires current C3 feedback: %s',why);
   [~,folder]=inkprof.refineVerification(w.output('c3','report'),Name="Iteration "+(w.State.cycle+1), ...
    RefinementMode=string(get(o,'RefinementMode',"argyll")),MaxNewPatches=get(o,'MaxNewPatches',100),NormTarget=get(o,'NormTarget',1),GrayWeight=get(o,'GrayWeight',2),CreatePrint=true,PlanPaper=true);
  end
  inkprof.internal.writeJson(fullfile(folder,'workflow-review.json'),struct('notes',get(o,'Notes',""),'method',method,'includedC2',get(o,'IncludeC2',false),'utc',utc()));
  out=inkprof.internal.workflowTiffOutputs(fullfile(folder,'refinement-print','print','target.ti2'));out.proposal=fullfile(folder,'proposal.json');
  combined=fullfile(folder,'refinement-print','verification.json');if isfile(combined),out.c2reference=combined;end
  files=allFiles(folder);assert(isfile(out.target),'inkprof:Workflow','No new printable patches were proposed. Review the feedback.');
 case "continue"
  [out,files]=continueProfile(w,fileparts(w.output('refine','proposal')),w.output('refinemeasurement','measurement'),o,w.State.cycle+1);
 otherwise
  error('inkprof:Workflow','Unknown operation.');
end
end
function n=referenceName(file)
[~,n]=fileparts(file);
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
calculation=inkprof.internal.calculationProgress("Building next ICC iteration","Checking measurements, fitting ICC candidates and running numerical checks. This may take several minutes."); %#ok<NASGU>
[folder,r]=inkprof.continueRefinement(proposal,source,Name="Iteration "+cycle, ...
 MaxNewPatches=get(o,'MaxNewPatches',100),NormTarget=get(o,'NormTarget',1),GrayWeight=get(o,'GrayWeight',2));
iteration=jsondecode(fileread(fullfile(folder,'iteration.json')));
out=struct('job',fullfile(folder,iteration.selectedJob,'status.json'),'profile',r.profileFile, ...
 'iteration',fullfile(folder,'iteration.json'),'verification',fullfile(r.verificationFolder,'verification.json'));
files=[profileFiles(out);source;fullfile(proposal,'proposal.json')];
end
