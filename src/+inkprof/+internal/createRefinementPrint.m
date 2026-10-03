function info=createRefinementPrint(proposal,job,folder,dpi,paper,seed,planPaper)
if nargin<7,planPaper=false;end
% Freeze roles before measurement and add old-RGB duplicates for drift review.
mkdir(folder);v=inkprof.cgatsData(inkprof.importCgats(fullfile(job,'engine.ti3')),RGBScale=100);
n=numel(proposal.candidates);rgb=reshape([proposal.candidates.rgbPercent],3,[])';roles=repmat("fit",n,1);
% Adaptive development, not an independent final holdout. Retain >=8 fit rows.
if n>=10,roles(5:5:n)="adaptive_holdout";end
training=unique(round(v.rgb/100*65535)/65535*100,'rows','stable');
chosen=[];gray=find(max(training,[],2)-min(training,[],2)<=2);
if ~isempty(gray),chosen=gray(unique(round(linspace(1,numel(gray),min(4,numel(gray))))))';end
if isempty(chosen),chosen=1;end
while numel(chosen)<min(10,size(training,1))
 distance=inf(size(training,1),1);
 for k=chosen,distance=min(distance,sum((training-training(k,:)).^2,2));end
 distance(chosen)=-Inf;[~,j]=max(distance);chosen(end+1)=j; %#ok<AGROW>
end
control=training(repelem(chosen,2),:);rgb=[rgb;control];roles=[roles;repmat("control",size(control,1),1)];
c2=[];c2start=size(rgb,1);c2count=0;
if isfield(proposal,'verification')
 file=fullfile(fileparts(folder),proposal.verification.file);
 assert(inkprof.internal.sha256(file)==string(proposal.verification.sha256),'inkprof:Integrity','Saved C2 reference changed.');
 c2=jsondecode(fileread(file));c2count=numel(c2.patches);
 assert(string(c2.printerProfile.sha256)==inkprof.internal.sha256(fullfile(job,'result','profile.icc')),'inkprof:Verification','C2 profile mismatch.');
 rgb=[rgb;reshape([c2.patches.deviceRGB16],3,[])'/65535*100];c2roles=repmat("fit",c2count,1);c2roles(ismember(string({c2.patches.role})',["repeat","paperwhite"]))="control";
 roles=[roles;c2roles];
end
shadow=inkprof.internal.shadowSettings(struct);project=inkprof.internal.findProject(job);
if project~="",record=jsondecode(fileread(fullfile(project,'inkprof-project.json')));if isfield(record,'printing'),shadow=inkprof.internal.shadowSettings(record.printing);end;end
shadowCount=0;shadowFile=fullfile(folder,'shadow-patches.json');
if shadow.enabled&&shadow.extraPatches>0
 [shadowProgress,~]=inkprof.internal.calculationProgress("Dark patch sampling","Argyll is selecting additional dark fitting patches..."); %#ok<ASGLU>
 excluded=fullfile(folder,'shadow-exclusions.json');inkprof.internal.writeJson(excluded,[v.rgb;rgb]);
 config=inkprof.paths();bin=inkprof.internal.argyllBin("");suffix="";if ispc,suffix=".exe";end
 inkprof.runPython(fullfile(config.Root,'analysis','shadow_patches.py'), ...
  [fullfile(job,'result','profile.icc'),excluded,string(folder),fullfile(bin,"targen"+suffix),fullfile(bin,"xicclu"+suffix),string(shadow.extraPatches),string(shadow.patchEmphasis)], ...
  RequiredModules=["numpy","colour"],TimeoutSeconds=420,WorkingDirectory=config.Root);
 extra=jsondecode(fileread(shadowFile));shadowCount=extra.actualCount;
 if shadowCount>0,rgb=[rgb;reshape(extra.rgbPercent,shadowCount,3)];roles=[roles;repmat("fit",shadowCount,1)];end
 clear shadowProgress
end
ids=string((1:size(rgb,1))');table=struct('signature',"CTI1",'fields',["SAMPLE_ID","RGB_R","RGB_G","RGB_B"], ...
 'data',[ids,compose('%.17g',rgb)],'metadata',{{["DESCRIPTOR","InkProf adaptive refinement with development and repeat controls"];["ORIGINATOR","InkProf"];["COLOR_REP","iRGB"]}});
doc=struct('documentType',"inkprof.cgats",'tables',table);definition=fullfile(folder,'target.ti1');inkprof.exportCgats(definition,doc);
target=inkprof.importTarget(definition);
generation=struct('method',"Adaptive refinement - device RGB - no profile", ...
 'settings',struct('proposalIterationId',proposal.iterationId,'newRGB',n,'fitCount',sum(roles=="fit"), ...
 'developmentCount',sum(roles=="adaptive_holdout"),'controlOccurrences',sum(roles=="control"),'shadowPatchCount',shadowCount,'verificationCount',c2count,'roleFile',"../placement-plan.json"));
metadata=inkprof.internal.targetInfo(target.rgbPercent/100,definition,generation);
manifest=inkprof.createTarget(fullfile(folder,'print'),Source=definition,TargetInfo=metadata,PlanPaper=planPaper,Paper=paper,DPI=dpi,SpacerMode="bw",Randomize=true,Seed=seed);
layout=jsondecode(fileread(fullfile(folder,'print','layout.json')));patches=cell(numel(ids),1);
for k=1:numel(ids)
 matches=find(~[layout.patches.isPadding]&string({layout.patches.originalId})==ids(k));assert(numel(matches)==1,'inkprof:Identity','Refinement placement mismatch.');
 p=layout.patches(matches);patches{k}=struct('sampleId',string(p.sampleId),'rgbPercent',double(p.rgb16(:)')/65535*100, ...
  'role',roles(k),'placement',struct('page',p.page,'coordinate',p.coordinate,'location',p.location), ...
  'definitionId',ids(k));
end
plan=struct('schemaVersion',1,'documentType',"inkprof.iteration-target-roles",'rolesFrozenBeforeMeasurement',true, ...
 'patches',{patches},'finalValidation',false,'profileApplied',false,'newUniqueRGB',n+shadowCount,'shadowPatchCount',shadowCount, ...
 'fitCount',sum(roles=="fit"),'adaptiveHoldoutCount',sum(roles=="adaptive_holdout"),'controlOccurrences',sum(roles=="control"), ...
 'verificationCount',c2count,'proposalIterationId',proposal.iterationId,'sourceProfileSHA256',inkprof.internal.sha256(fullfile(job,'result','profile.icc')));
inkprof.internal.writeJson(fullfile(folder,'placement-plan.json'),plan);
info=struct('folder',folder,'ti2',fullfile(folder,'print','target.ti2'),'roleFile',fullfile(folder,'placement-plan.json'), ...
 'newPatchCount',n+shadowCount,'shadowPatchCount',shadowCount,'totalSourcePatches',numel(ids),'pageCount',manifest.pageCount,'profileApplied',false);
if c2count>0
 % Keep C2 IDs/repeat relationships; replace only printed placement.
 original=fileparts(fullfile(fileparts(folder),proposal.verification.file));
 copyfile(fullfile(original,'definition'),fullfile(folder,'definition'));
 for k=1:c2count
  p=patches{c2start+k};q=layout.patches(string({layout.patches.sampleId})==p.sampleId);
  c2.patches(k).placement=struct('page',q.page,'coordinate',q.coordinate,'sampleId',q.sampleId,'location',q.location,'tiff',"print/"+string(q.tiff));
 end
 other=[patches(1:c2start);patches(c2start+c2count+1:end)];
 c2.combinedTarget=struct('role',"C2 verification subset in combined refinement target",'otherPatches',{other},'verificationCount',c2count,'excludedFromTraining',false,'nextIterationTraining',"C2 colour/gray/challenge patches are fitting data; repeat and paper-white patches remain controls. These are not independent validation data for the next ICC.");
 c2.printPackage=struct('folder',"print",'manifestSHA256',inkprof.internal.sha256(fullfile(folder,'print','manifest.json')), ...
  'ti2',"print/target.ti2",'ti2SHA256',inkprof.internal.sha256(fullfile(folder,'print','target.ti2')),'pageCount',manifest.pageCount,'dpi',dpi);
 inkprof.internal.writeJson(fullfile(folder,'verification.json'),c2);
 info.verificationReference=fullfile(folder,'verification.json');
end
if shadowCount>0
 info.shadow=struct('file',"refinement-print/shadow-patches.json",'sha256',inkprof.internal.sha256(shadowFile),'count',shadowCount);
end
info.verificationPatchCount=c2count;info.c2TrainingCount=0;
if c2count>0,info.c2TrainingCount=sum(c2roles=="fit");end
info.roleSHA256=inkprof.internal.sha256(info.roleFile);info.ti2SHA256=inkprof.internal.sha256(info.ti2);
f=fopen(fullfile(folder,'PRINTING.txt'),'w');c=onCleanup(@()fclose(f));
fprintf(f,'REFINEMENT: device RGB16, no ICC applied. Print at 100%% with all colour conversion disabled.\nUse the same printer, paper and print settings. Measure print/target.ti2.\nKeep placement-plan.json with the measurement: fit, adaptive development and repeated controls must not be mixed.\nC2 patches, when included, are already converted to device RGB: do NOT apply the ICC again. C2 colour patches are used in the next profile training; repeats and paper white remain controls. C2 cannot independently validate that next ICC.\nExisting-RGB controls and C2 patches are additional to the new-point budget. Contrast bars and padding are not source patches.\n');
end
