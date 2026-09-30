function [iterationFolder,result]=iterateProfile(measurementFile,options)
%ITERATEPROFILE Logged measurement -> ICC candidates -> printable verification.
% Optional BaseMeasurement and RoleFile retain prior training observations and
% exclude reserved controls. All output is a new candidate, never approval.
arguments
 measurementFile (1,1) string = ""
 options.ProjectFolder (1,1) string = ""
 options.TargetFile (1,1) string = ""
 options.BaseMeasurement (1,1) string = ""
 options.BaseInputFolder (1,1) string = ""
 options.RoleFile (1,1) string = ""
 options.ContinuationFile (1,1) string = ""
 options.VerificationReport (1,1) string = ""
 options.Name (1,1) string = "Profile iteration"
 options.MaxNewPatches (1,1) double {mustBePositive,mustBeInteger} = 100
 options.NormTarget (1,1) double {mustBeFinite,mustBeNonnegative} = 1
 options.GrayWeight (1,1) double {mustBeFinite,mustBePositive} = 2
 options.MaxPatchRegression (1,1) double {mustBeFinite,mustBeNonnegative} = 0.5
 options.MaxGrayRegression (1,1) double {mustBeFinite,mustBeNonnegative} = 0.25
 options.MinImprovement (1,1) double {mustBeFinite,mustBeNonnegative} = 0.01
 options.RepeatLimit (1,1) double {mustBeFinite,mustBePositive} = 1
 options.DPI (1,1) double {mustBePositive,mustBeInteger} = 300
 options.Paper (1,1) string = "A4-landscape"
 options.Seed (1,1) double {mustBeNonnegative,mustBeInteger} = 42
 options.ShowJobDialog (1,1) logical = false
end
iterationFolder="";result=[];
if measurementFile==""
 [n,p]=uigetfile({'*.json;*.ti3;*.mxf','Measured target (JSON, TI3, MXF)'},'Select measured target');
 if isequal(n,0),return;end;measurementFile=fullfile(p,n);
end
measurementFile=inkprof.internal.absolutePath(measurementFile);
project=options.ProjectFolder;if project=="",project=inkprof.internal.findProject(measurementFile);end
assert(project~=""&&inkprof.internal.findProject(project)~="",'inkprof:Project','Supply an existing ProjectFolder for an external measurement.');
project=inkprof.internal.findProject(project);
iterationFolder=fullfile(project,'profiles','iterations',string(java.util.UUID.randomUUID()));mkdir(iterationFolder);
result=struct('schemaVersion',1,'documentType',"inkprof.profile-iteration",'name',options.Name,'status',"running", ...
 'createdUTC',utc(),'sourceFile',measurementFile,'sourceSHA256',inkprof.internal.sha256(measurementFile), ...
 'parameters',options,'qualityApproved',false,'numericalConvergence',"Not established by engine success; retain colprof.log",'events',{{}},'candidates',{{}});
cleanup=onCleanup(@()markInterrupted(iterationFolder));
try
 if options.ContinuationFile~=""
  copyfile(options.ContinuationFile,fullfile(iterationFolder,'continuation-source.json'));
  result.continuation=struct('file',"continuation-source.json",'sha256',inkprof.internal.sha256(fullfile(iterationFolder,'continuation-source.json')));
  event("continuation","recorded","Parent refinement, matching measured target, base training and excluded controls recorded.");
 end
 if options.VerificationReport~=""
  [feedback,feedbackFile]=inkprof.analyseVerification(options.VerificationReport, ...
   GrayWeight=options.GrayWeight,RepeatLimit=options.RepeatLimit);
  result.verificationFeedback=struct('file',feedbackFile,'sha256',inkprof.internal.sha256(feedbackFile), ...
   'priorities',feedback.priorities,'usage',"Diagnostic review only; not automatically added to fitting or patch generation");
  event("verification-feedback","recorded",feedback.recommendation);
 end
 event("input","started","Import and validate identities, spectra, roles and source hashes.");
 [~,~,ext]=fileparts(measurementFile);
 if any(lower(ext)==[".mxf",".ti3"])
  [~,measurementFile]=inkprof.importMeasurement(measurementFile,TargetFile=options.TargetFile, ...
   SessionFolder=fullfile(iterationFolder,'import'),ShowPreview=false);
 end
 if options.RoleFile==""
  sourceRecord=jsondecode(fileread(measurementFile));
  if isfield(sourceRecord,'targetInfo')&&isfield(sourceRecord.targetInfo,'source')&&isfield(sourceRecord.targetInfo.source,'path')
   originalTarget=string(sourceRecord.targetInfo.source.path);
   possible=[fullfile(fileparts(originalTarget),'placement-plan.json'),fullfile(fileparts(fileparts(originalTarget)),'placement-plan.json')];
   found=possible(isfile(possible));
   assert(numel(found)<=1,'inkprof:IterationRoles','Multiple role files found; select RoleFile explicitly.');
   if ~isempty(found),options.RoleFile=found(1);end
  end
 end
 result.parameters=options;
 [fitIds,devIds,roles]=inkprof.internal.iterationRoles(measurementFile,options.RoleFile);
 result.roles=roles;
 if options.RoleFile~="",copyfile(options.RoleFile,fullfile(iterationFolder,'roles.json'));end
 [inputFolder,~]=inkprof.prepareProfileInput(measurementFile,ProjectFolder=project,Name=options.Name,FitSampleIds=fitIds,ShowDialog=false);
 assert(options.BaseMeasurement==""||options.BaseInputFolder=="",'inkprof:IterationInput','Choose BaseMeasurement or BaseInputFolder, not both.');
 if options.BaseMeasurement~=""||options.BaseInputFolder~=""
  assert(options.RoleFile~="",'inkprof:IterationRoles','Combining a new batch requires explicit roles to protect controls.');
  baseFolder=options.BaseInputFolder;
  if baseFolder=="",[baseFolder,~]=inkprof.prepareProfileInput(options.BaseMeasurement,ProjectFolder=project,Name=options.Name+" - base",ShowDialog=false);end
  inputFolder=inkprof.internal.combineProfileInputs([baseFolder;inputFolder],fullfile(iterationFolder,'training'),options.Name);
 else
  copyfile(inputFolder,fullfile(iterationFolder,'training'));inputFolder=fullfile(iterationFolder,'training');
 end
 result.inputFile=relative(fullfile(inputFolder,'profile-input.json'));result.measurementFile=measurementFile;
 result.hasDevelopmentControls=~isempty(devIds);
 m=jsondecode(fileread(measurementFile));
 if ~isempty(devIds)
  trainingValues=inkprof.cgatsData(inkprof.importCgats(fullfile(inputFolder,'profiling.ti3')),RGBScale=100);
  [found,indices]=ismember(devIds,string(m.data.ids(:)));assert(all(found));
  for j=indices(:)'
   assert(~any(max(abs(trainingValues.rgb-double(m.data.rgb(j,:))),[],2)<=1e-4), ...
    'inkprof:IterationLeakage','A development RGB is present in training; revise the role split.');
  end
 end
 result.measurementWarnings=strings(0,1);
 if isfield(m,'pairedReadings')&&isfield(m.pairedReadings,'directionComparison')
  result.pairedQuality=m.pairedReadings.directionComparison;
  if any(double(result.pairedQuality.patchDeltaE00)>options.RepeatLimit)
   result.measurementWarnings(end+1)="Historical paired-scan differences exceed RepeatLimit; review corrections and repeatability before relying on this candidate.";
  end
 end
 trainingRecord=jsondecode(fileread(fullfile(inputFolder,'profile-input.json')));
 assert(trainingRecord.patchCount>=8,'inkprof:IterationInput','At least eight total fitting patches required; supply prior training for a small supplementary batch.');
 event("input","completed",sprintf('Frozen %d fitting patches; %d development IDs. Source mappings and excluded controls preserved.',trainingRecord.patchCount,numel(devIds)));
 % Quality trial followed by smoothing trial: one factor changes per step.
 qualities=["medium","high","high"];smooth=[NaN NaN 0.1];
 if isempty(devIds),qualities="high";smooth=NaN;end
 proposals=cell(numel(qualities),1);jobs=strings(numel(qualities),1);proposalFolders=jobs;
 for k=1:numel(qualities)
  checkCancel();event("candidate-"+k,"started","Build A2B "+qualities(k)+"; B2A high. Profile fit is training error only.");
  [recipeFile,~]=inkprof.createProfileRecipe(inputFolder,Name=options.Name+" candidate "+k, ...
   A2BQuality=qualities(k),Smoothing=smooth(k),B2AQuality="high",ShowDialog=false);
  [job,status]=inkprof.runProfileJob(recipeFile,ShowDialog=options.ShowJobDialog);jobs(k)=job;
  assert(string(status.status)=="succeeded",'inkprof:IterationBuild','ICC build %s; inspect %s.',string(status.status),job);
  [fit,fitFile]=inkprof.checkProfileFit(job,ShowDialog=false);
  c=struct('job',relative(job),'profile',relative(fullfile(job,'result','profile.icc')),'sha256',status.profileSHA256, ...
   'quality',qualities(k),'smoothing',smooth(k),'fitReport',relative(fitFile),'trainingFit',fit.summary);
  if ~isempty(devIds)
   [proposal,pfolder]=inkprof.proposeRefinement(job,measurementFile,DevelopmentSampleIds=devIds, ...
    UseJacobian=true,MaxNewPatches=options.MaxNewPatches,NormTarget=options.NormTarget,GrayWeight=options.GrayWeight,RepeatLimit=options.RepeatLimit,ShowDialog=false);
   proposals{k}=proposal;proposalFolders(k)=pfolder;c.developmentReport=relative(fullfile(pfolder,'proposal.json'));c.errorNorm=proposal.errorNorm;
  end
  result.candidates{end+1}=c;
  message=sprintf('Training mean dE00 %.4f, max %.4f. Physical accuracy awaits a new print.',fit.summary.mean,fit.summary.max);
  if isfield(c,'errorNorm'),message=message+" Development weighted RMS: "+string(c.errorNorm.value);end
  event("candidate-"+k,"completed",message);
 end
 if isempty(devIds)
  selected=1;result.selection=struct('selected',1,'basis',"High-quality candidate only; no independent development observations supplied. No evidence of superiority.");
 else
  result.selection=inkprof.internal.selectIterationCandidate(proposals,options.MinImprovement,options.MaxPatchRegression,options.MaxGrayRegression);
  selected=result.selection.selected;
 end
 result.selectedJob=relative(jobs(selected));result.profileFile=relative(fullfile(jobs(selected),'result','profile.icc'));
 event("selection","completed","Selected candidate "+selected+". "+string(result.selection.basis));
 if isfield(result.selection,'decisions')
  for decision=result.selection.decisions'
   d=decision{1};event("model-comparison","recorded",sprintf('Candidate %d vs %d: accepted %d; worst patch regression %.4f; gray mean regression %.4f; %d gray controls.',d.candidate,d.comparedTo,d.accepted,d.worstPatchRegression,d.grayMeanRegression,d.grayCount));
  end
 end
 checkCancel();
 [grid,gridFile]=inkprof.checkProfileGrid(jobs(selected),ShowDialog=false);
 result.gridReport=relative(gridFile);result.roundtripDeltaE00=grid.roundtripDeltaE00;
 [c1,c1File]=inkprof.checkProfileC1(jobs(selected),ShowDialog=false);result.c1Report=relative(c1File);
 assert(c1.allNegativeControlsDetected&&isempty(c1.grossFailureAlerts),'inkprof:IterationNumerical','Numerical checks require review; no print target produced.');
 event("numerical-checks","completed","Grid, inverse and CMM diagnostics saved. Success does not establish print quality or noise stability.");checkCancel();
 if ~isempty(devIds)
  p=proposals{selected};result.refinement=struct('proposal',relative(fullfile(proposalFolders(selected),'proposal.json')), ...
   'newPatchCount',numel(p.candidates),'stopReason',p.stopReason,'errorNorm',p.errorNorm);
  if ~isempty(p.candidates)
   rawFolder=fullfile(iterationFolder,'refinement-print');
   printInfo=inkprof.internal.createRefinementPrint(p,jobs(selected),rawFolder,options.DPI,options.Paper,options.Seed);
   result.refinement.ti2=relative(printInfo.ti2);result.refinement.roleFile=relative(printInfo.roleFile);
   result.refinement.totalSourcePatches=printInfo.totalSourcePatches;result.refinement.pageCount=printInfo.pageCount;
   result.refinement.profileApplied=false;
  end
  event("refinement","completed",sprintf('%d new fitting candidates; %s. Heuristic priority, not predicted improvement.',numel(p.candidates),p.stopReason));
 else
  event("refinement","skipped","No development controls. Training residuals alone will not justify adaptive patch placement.");
 end
 checkCancel();[verification,reference]=inkprof.createVerificationTarget(jobs(selected),Name=options.Name+" verification", ...
  OutputFolder=fullfile(iterationFolder,'verification'),DPI=options.DPI,Paper=options.Paper,Seed=options.Seed);
 result.verification=struct('folder',relative(verification),'ti2',relative(fullfile(verification,'print','target.ti2')), ...
  'pageCount',reference.printPackage.pageCount,'profileApplied',true,'intent',"absolute colorimetric",'bpc',false);
 result.status="ready-for-print-review";
 result.nextStep="Review print settings, print at 100% without additional colour conversion, measure the matching TI2, then compare to verification.json. No automatic profile approval.";
 event("iteration","completed",result.nextStep);
 inkprof.internal.recordProjectStep(iterationFolder,"Automatic profile iteration: candidate ICC and printable verification; not quality-approved");
 fprintf('InkProf iteration: %s\nICC: %s\nTIFF folder: %s\nLog: %s\n',iterationFolder,fullfile(iterationFolder,result.profileFile),fullfile(verification,'print'),fullfile(iterationFolder,'progress.log'));
catch err
 result.status="failed";result.error=struct('identifier',err.identifier,'message',err.message);
 event("iteration","failed",string(err.message));rethrow(err);
end
 function path=relative(path)
  path=string(java.nio.file.Paths.get(char(iterationFolder),javaArray('java.lang.String',0)).relativize( ...
   java.nio.file.Paths.get(char(path),javaArray('java.lang.String',0))).toString());
  path=replace(path,filesep,"/");
 end
 function event(stage,state,message)
  e=struct('utc',utc(),'stage',stage,'state',state,'message',message);result.events{end+1}=e;
  f=fopen(fullfile(iterationFolder,'progress.jsonl'),'a','n','UTF-8');assert(f>=0);fprintf(f,'%s\n',jsonencode(e));fclose(f);
  f=fopen(fullfile(iterationFolder,'progress.log'),'a','n','UTF-8');assert(f>=0);fprintf(f,'%s | %s | %s | %s\n',e.utc,stage,state,message);fclose(f);
  stageFile=fullfile(iterationFolder,'iteration.pending.json');inkprof.internal.writeJson(stageFile,result);movefile(stageFile,fullfile(iterationFolder,'iteration.json'),'f');
  fprintf('InkProf iteration [%s]: %s\n',stage,message);drawnow;
 end
 function checkCancel()
  assert(~isfile(fullfile(iterationFolder,'cancel.request')),'inkprof:IterationCancelled','Iteration cancelled between stages.');
 end

end
function value=utc()
value=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
end

function markInterrupted(folder)
p=fullfile(folder,'iteration.json');if ~isfile(p),return;end
r=jsondecode(fileread(p));if string(r.status)~="running",return;end
r.status="interrupted";inkprof.internal.writeJson(p,r);
f=fopen(fullfile(folder,'progress.log'),'a');if f>=0,fprintf(f,'Interrupted; completed artifacts retained.\n');fclose(f);end
end
