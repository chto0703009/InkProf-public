% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function plan=refinementContinuationPlan(folder,measurementFile)
% Resolve and validate the exact parent training and frozen target roles.
arguments
 folder (1,1) string
 measurementFile (1,1) string = ""
end
folder=inkprof.internal.absolutePath(folder);project=inkprof.internal.findProject(folder);
assert(project~="",'inkprof:Continuation','Proposal must belong to a project.');
proposalFile=fullfile(folder,'proposal.json');p=jsondecode(fileread(proposalFile));
assert(any(string(p.documentType)==["inkprof.verification-refinement","inkprof.image-refinement","inkprof.gamut-refinement"])&&isfield(p,'print'),'inkprof:Continuation','A rendered error-driven, image-guided or gamut-area refinement proposal is required.');
context=jsondecode(fileread(fullfile(folder,'sources','context.json')));
job=fullfile(project,context.profileJob);recipeFile=fullfile(job,'recipe.json');
status=jsondecode(fileread(fullfile(job,'status.json')));recipe=jsondecode(fileread(recipeFile));
assert(string(status.status)=="succeeded"&&inkprof.internal.sha256(recipeFile)==string(status.recipeSHA256),'inkprof:Continuation','Parent job changed.');
assert(inkprof.internal.sha256(fullfile(job,'result','profile.icc'))==inkprof.internal.sha256(fullfile(folder,'sources','profile.icc')) ...
 &&inkprof.internal.sha256(fullfile(job,'engine.ti3'))==inkprof.internal.sha256(fullfile(folder,'sources','training.ti3')), ...
 'inkprof:Continuation','Proposal and parent job no longer agree.');
% Resolve by immutable input hash, not the copied recipe's relative path.
entries=dir(fullfile(project,'profiles','**','profile-input.json'));base="";
for k=1:numel(entries)
 file=fullfile(entries(k).folder,entries(k).name);
 if all(isfile(fullfile(entries(k).folder,["measurement.json","chart.json","source.ti3","profiling.ti3"])))&&inkprof.internal.sha256(file)==string(recipe.inputSHA256)
  candidate=string(entries(k).folder);
  if base==""||strlength(candidate)<strlength(base),base=candidate;end
 end
end
assert(base~="",'inkprof:Continuation','Original locked training package not found by hash.');
b=jsondecode(fileread(fullfile(base,'profile-input.json')));
for pair={"measurement.json","measurementSHA256";"chart.json","chartJSONSHA256";"source.ti3","sourceTI3SHA256";"profiling.ti3","profilingTI3SHA256"}'
 assert(inkprof.internal.sha256(fullfile(base,pair{1}))==string(b.(pair{2})),'inkprof:Continuation','Parent training package changed.');
end
assert(string(b.profilingTI3SHA256)==string(recipe.profilingTI3SHA256),'inkprof:Continuation','Parent recipe/input mismatch.');
roleFile=fullfile(folder,'refinement-print','placement-plan.json');targetFile=fullfile(folder,'refinement-print','print','target.ti2');
roles=jsondecode(fileread(roleFile));
assert(roles.rolesFrozenBeforeMeasurement&&~roles.profileApplied&&string(roles.sourceProfileSHA256)==string(status.profileSHA256),'inkprof:Continuation','Unexpected role-plan provenance.');
if isfield(p.print,'roleSHA256')
 assert(inkprof.internal.sha256(roleFile)==string(p.print.roleSHA256)&&inkprof.internal.sha256(targetFile)==string(p.print.ti2SHA256),'inkprof:Continuation','Frozen layout changed.');
end
c2=[];
if isfield(p,'verification')
 c2file=fullfile(folder,p.verification.file);
 assert(inkprof.internal.sha256(c2file)==string(p.verification.sha256),'inkprof:Continuation','C2 reference changed.');
 c2=jsondecode(fileread(c2file));
 assert(string(c2.printerProfile.sha256)==string(status.profileSHA256),'inkprof:Continuation','C2 profile mismatch.');
end
shadow=[];shadowCount=0;
if isfield(p.print,'shadow')
 ref=p.print.shadow;file=fullfile(folder,ref.file);
 assert(inkprof.internal.sha256(file)==string(ref.sha256),'inkprof:Integrity','Shadow patch data changed.');
 shadow=jsondecode(fileread(file));shadowCount=shadow.actualCount;
 assert(shadowCount==ref.count&&numel(shadow.rgbPercent)==3*shadowCount&&string(shadow.sourceProfileSHA256)==string(status.profileSHA256),'inkprof:Continuation','Invalid shadow patch identity.');
 if shadowCount>0,shadow.rgbPercent=reshape(shadow.rgbPercent,shadowCount,3);end
end
n=numel(p.candidates);patches=roles.patches;definitionIds=str2double(string({patches.definitionId}));
assert(numel(unique(definitionIds))==numel(patches)&&isequal(sort(definitionIds),1:numel(patches)),'inkprof:Continuation','Invalid definition identity mapping.');
v=inkprof.cgatsData(inkprof.importCgats(fullfile(base,'profiling.ti3')),RGBScale=100);
for k=1:numel(patches)
 q=patches(k);id=definitionIds(k);rgb=double(q.rgbPercent(:)');
 if id<=n
  expected="fit";if n>=10&&mod(id,5)==0,expected="adaptive_holdout";end
  assert(string(q.role)==expected&&max(abs(rgb-double(p.candidates(id).rgbPercent(:)')))<=1e-4,'inkprof:Continuation','New patch role/RGB changed.');
 elseif shadowCount>0&&id>numel(patches)-shadowCount
  si=id-(numel(patches)-shadowCount);
  assert(string(q.role)=="fit"&&max(abs(rgb-double(shadow.rgbPercent(si,:))))<=1e-4,'inkprof:Continuation','Shadow patch role/RGB changed.');
 elseif ~isempty(c2)&&id>numel(patches)-shadowCount-numel(c2.patches)
  ci=id-(numel(patches)-shadowCount-numel(c2.patches));
  expected="fit";if any(string(c2.patches(ci).role)==["repeat","paperwhite"]),expected="control";end
  assert(string(q.role)==expected&&max(abs(rgb-double(c2.patches(ci).deviceRGB16(:)')/65535*100))<=1e-4,'inkprof:Continuation','C2 verification role/RGB changed.');
 else
  assert(string(q.role)=="control"&&any(max(abs(v.rgb-rgb),[],2)<=.002),'inkprof:Continuation','Unexpected control RGB or role.');
 end
end
assert(sum(definitionIds<=n)==n,'inkprof:Continuation','Missing candidate patch.');
r=string({patches.role});
plan=struct('schemaVersion',1,'documentType',"inkprof.refinement-continuation",'status',"awaiting-measurement", ...
 'projectFolder',project,'proposalFolder',folder,'proposalSHA256',inkprof.internal.sha256(proposalFile), ...
 'parentIterationId',p.iterationId,'parentJob',job,'baseInputFolder',base,'baseInputSHA256',recipe.inputSHA256, ...
 'roleFile',roleFile,'roleSHA256',inkprof.internal.sha256(roleFile),'targetFile',targetFile,'targetSHA256',inkprof.internal.sha256(targetFile), ...
 'basePatchCount',b.patchCount,'newFitCount',sum(r=="fit"),'developmentCount',sum(r=="adaptive_holdout"), ...
 'controlCount',sum(r=="control"),'verificationCount',numelC2(c2),'expectedTrainingCount',b.patchCount+sum(r=="fit"), ...
 'printComparability',"Must use the same printer, paper and unmanaged print settings; drift not inferred from identity checks.");
if measurementFile=="",return;end
measurementFile=inkprof.internal.absolutePath(measurementFile);m=jsondecode(fileread(measurementFile));
assert(m.complete&&numel(m.data.ids)==numel(patches),'inkprof:Continuation','Complete matching measurement required.');
[mp,stem]=fileparts(measurementFile);
assert(inkprof.internal.sha256(fullfile(mp,stem+".ti3"))==string(m.sourceTI3SHA256),'inkprof:Continuation','Measurement TI3 changed.');
assert(string(m.measurementCondition.interpreted)~="unknown"&&string(m.measurementCondition.interpreted)==string(b.measurementCondition.interpreted),'inkprof:Continuation','Measurement condition differs from parent training.');
[fit,dev,record]=inkprof.internal.iterationRoles(measurementFile,roleFile);
ids=string(m.data.ids(:));assert(numel(unique(ids))==numel(ids),'inkprof:Continuation','Duplicate measurement IDs.');
for k=1:numel(patches)
 index=find(ids==string(patches(k).sampleId));
 assert(isscalar(index)&&string(m.data.locations(index))==string(patches(k).placement.location),'inkprof:Continuation','Measured patch location disagrees with printed target.');
end
plan.status="ready-for-profile-iteration";plan.measurementFile=measurementFile;
plan.measurementSHA256=inkprof.internal.sha256(measurementFile);plan.fitIds=fit;plan.developmentIds=dev;plan.roles=record;
end

function n=numelC2(c2)
n=0;if ~isempty(c2),n=numel(c2.patches);end
end
