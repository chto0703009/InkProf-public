function [fit,development,record]=iterationRoles(measurementFile,roleFile)
% Verify a frozen role manifest against actual IDs and device RGB before use.
m=jsondecode(fileread(measurementFile));ids=string(m.data.ids(:));
fit=strings(0,1);development=strings(0,1);record=struct('basis',"All source patches used for training; no development controls supplied");
if roleFile=="",return;end
p=jsondecode(fileread(roleFile));assert(isfield(p,'patches')&&isfield(p.patches,'role'),'inkprof:IterationRoles','Role file must contain patches with sampleId, rgbPercent and role.');
sourceIds=string({p.patches.sampleId})';assert(numel(unique(sourceIds))==numel(sourceIds),'inkprof:IterationRoles','Duplicate role IDs.');
[found,index]=ismember(sourceIds,ids);assert(all(found),'inkprof:IterationRoles','Role IDs missing from measurement.');
for k=1:numel(index)
 assert(max(abs(double(p.patches(k).rgbPercent(:)')-double(m.data.rgb(index(k),:))))<=1e-4, ...
  'inkprof:IterationRoles','Role RGB disagrees with measurement for ID %s.',sourceIds(k));
end
roles=string({p.patches.role})';allowed=["fit","adaptive_holdout","adaptive_validation","control","repeat","final_holdout"];
assert(all(ismember(roles,allowed)),'inkprof:IterationRoles','Unknown role; cannot silently use it for training.');
fit=sourceIds(roles=="fit");development=sourceIds(ismember(roles,["adaptive_holdout","adaptive_validation"]));
assert(~isempty(fit),'inkprof:IterationRoles','At least one fitting ID required.');
record=struct('file',roleFile,'sha256',inkprof.internal.sha256(roleFile),'fitIds',fit, ...
 'developmentIds',development,'excludedIds',sourceIds(~ismember(roles,["fit","adaptive_holdout","adaptive_validation"])), ...
 'basis',"Explicit role manifest matched by ID and RGB. Adaptive holdout becomes development data for this run; final holdout excluded.");
end
