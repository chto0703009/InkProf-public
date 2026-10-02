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
ids=string((1:size(rgb,1))');table=struct('signature',"CTI1",'fields',["SAMPLE_ID","RGB_R","RGB_G","RGB_B"], ...
 'data',[ids,compose('%.17g',rgb)],'metadata',{{["DESCRIPTOR","InkProf adaptive refinement with development and repeat controls"];["ORIGINATOR","InkProf"];["COLOR_REP","iRGB"]}});
doc=struct('documentType',"inkprof.cgats",'tables',table);definition=fullfile(folder,'target.ti1');inkprof.exportCgats(definition,doc);
target=inkprof.importTarget(definition);
generation=struct('method',"Adaptive refinement - device RGB - no profile", ...
 'settings',struct('proposalIterationId',proposal.iterationId,'newRGB',n,'fitCount',sum(roles=="fit"), ...
 'developmentCount',sum(roles=="adaptive_holdout"),'controlOccurrences',sum(roles=="control"),'roleFile',"../placement-plan.json"));
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
 'patches',{patches},'finalValidation',false,'profileApplied',false,'newUniqueRGB',n, ...
 'fitCount',sum(roles=="fit"),'adaptiveHoldoutCount',sum(roles=="adaptive_holdout"),'controlOccurrences',sum(roles=="control"), ...
 'proposalIterationId',proposal.iterationId,'sourceProfileSHA256',inkprof.internal.sha256(fullfile(job,'result','profile.icc')));
inkprof.internal.writeJson(fullfile(folder,'placement-plan.json'),plan);
info=struct('folder',folder,'ti2',fullfile(folder,'print','target.ti2'),'roleFile',fullfile(folder,'placement-plan.json'), ...
 'newPatchCount',n,'totalSourcePatches',numel(ids),'pageCount',manifest.pageCount,'profileApplied',false);
info.roleSHA256=inkprof.internal.sha256(info.roleFile);info.ti2SHA256=inkprof.internal.sha256(info.ti2);
f=fopen(fullfile(folder,'PRINTING.txt'),'w');c=onCleanup(@()fclose(f));
fprintf(f,'REFINEMENT: device RGB16, no ICC applied. Print at 100%% with all colour conversion disabled.\nUse the same printer, paper and print settings. Measure print/target.ti2.\nKeep placement-plan.json with the measurement: fit, adaptive development and repeated controls must not be mixed.\nExisting-RGB controls are additional to the new-point budget. Contrast bars and padding are not source patches.\n');
end
