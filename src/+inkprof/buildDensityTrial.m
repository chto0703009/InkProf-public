% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [result,folder]=buildDensityTrial(job,densityFile,options)
% Build an explicit derived-row trial, keeping measurements and selection intact.
arguments
 job (1,1) string
 densityFile (1,1) string
 options.Activity (1,1) function_handle = @(stage)[]
 options.RunBuild (1,1) logical = true
 options.ShowJobDialog (1,1) logical = true
 options.DevelopmentMeasurement (1,1) string = ""
 options.DevelopmentIds (:,1) string = strings(0,1)
end
options.Activity("Verifying source profile, measurements and density selection");
job=inkprof.internal.absolutePath(job);project=inkprof.internal.findProject(job);assert(project~="",'inkprof:Density','Select a project job.');
status=jsondecode(fileread(fullfile(job,'status.json')));recipeFile=fullfile(job,'recipe.json');recipe=jsondecode(fileread(recipeFile));
profile=fullfile(job,'result','profile.icc');densityHash=inkprof.internal.sha256(densityFile);d=jsondecode(fileread(densityFile));
assert(string(status.status)=="succeeded"&&inkprof.internal.sha256(profile)==string(status.profileSHA256)&& ...
 inkprof.internal.sha256(recipeFile)==string(status.recipeSHA256)&&inkprof.internal.sha256(fullfile(job,'engine.ti3'))==string(status.engineTI3SHA256), ...
 'inkprof:Integrity','Original job changed.');
assert(string(d.documentType)=="inkprof.measurement-density"&&string(d.profileSHA256)==string(status.profileSHA256)&& ...
 string(d.sourceTI3SHA256)==string(status.engineTI3SHA256)&&inkprof.internal.sha256(d.fitReport)==string(d.fitReportSHA256),'inkprof:Integrity','Density review belongs to another or changed input.');
fit=jsondecode(fileread(d.fitReport));
input="";entries=dir(fullfile(project,'profiles','**','profile-input.json'));
for k=1:numel(entries)
 file=fullfile(entries(k).folder,entries(k).name);if inkprof.internal.sha256(file)==string(recipe.inputSHA256),input=string(entries(k).folder);break;end
end
assert(input~="",'inkprof:Density','Original locked input not found by hash.');
r=jsondecode(fileread(fullfile(input,'profile-input.json')));
files=["measurement.json","chart.json","source.ti3","profiling.ti3"];keys=["measurementSHA256","chartJSONSHA256","sourceTI3SHA256","profilingTI3SHA256"];
for k=1:numel(files),assert(inkprof.internal.sha256(fullfile(input,files(k)))==string(r.(keys(k))),'inkprof:Integrity','Original locked input changed.');end
assert(string(r.profilingTI3SHA256)==string(recipe.profilingTI3SHA256),'inkprof:Integrity','Recipe/input mismatch.');
doc=inkprof.importCgats(fullfile(input,'profiling.ti3'));v=inkprof.cgatsData(doc,RGBScale=100);
assert(numel(fit.patches)==numel(v.ids)&&isequal(string({fit.patches.sampleId})',v.ids(:))&& ...
 isequal(string({fit.patches.sampleLoc})',v.locations(:))&&max(abs(reshape([fit.patches.rgbPercent],3,[])'-v.rgb),[],'all')<1e-4, ...
 'inkprof:Integrity','Fit rows do not match original locked measurements.');
rows=double(d.selectedRows(:));assert(numel(rows)>=8&&numel(rows)<numel(v.ids)&&numel(unique(rows))==numel(rows)&&all(rows>=1&rows<=numel(v.ids)&rows==floor(rows)), ...
 'inkprof:Density','Trial requires at least eight retained rows and fewer rows than the original.');
if options.DevelopmentMeasurement~=""||~isempty(options.DevelopmentIds)
 assert(options.DevelopmentMeasurement~=""&&~isempty(options.DevelopmentIds),'inkprof:Density','Supply both development measurement and reserved IDs.');
 dev=jsondecode(fileread(options.DevelopmentMeasurement));[found,indices]=ismember(options.DevelopmentIds,string(dev.data.ids(:)));
 assert(all(found)&&numel(unique(options.DevelopmentIds))==numel(indices),'inkprof:Density','Invalid reserved development IDs.');
 for j=indices(:)'
  assert(~any(max(abs(v.rgb-double(dev.data.rgb(j,:))),[],2)<=1e-4),'inkprof:IterationLeakage','Development RGB is already in original training.');
 end
end
options.Activity("Saving original snapshots and preparing the balanced input");
folder=fullfile(project,'profiles','density-trials',string(java.util.UUID.randomUUID()));derived=fullfile(folder,'input');mkdir(derived);
if isfolder(fullfile(input,'sources')),copyfile(fullfile(input,'sources'),fullfile(derived,'sources'));end
snapshots=fullfile(folder,'original-input');mkdir(snapshots);
if isfolder(fullfile(input,'sources')),copyfile(fullfile(input,'sources'),fullfile(snapshots,'sources'));end
for file=[files,"profile-input.json"],copyfile(fullfile(input,file),fullfile(snapshots,file));end
for file=["measurement.json","chart.json","source.ti3"],copyfile(fullfile(input,file),fullfile(derived,file));end
doc.tables.data=doc.tables.data(rows,:);inkprof.exportCgats(fullfile(derived,'profiling.ti3'),doc);
r.patchCount=numel(rows);r.sourceDataRows=r.sourceDataRows(rows);r.name=string(r.name)+" - density trial";
r.profilingTI3SHA256=inkprof.internal.sha256(fullfile(derived,'profiling.ti3'));
r.densityTrial=struct('originalInputSHA256',recipe.inputSHA256,'originalRows',rows,'originalSnapshot',"../original-input",'densityReportSHA256',densityHash, ...
 'basis',"Experimental selection of unchanged measured rows. Original snapshots retained. No averaging of measured values.");
inkprof.internal.writeJson(fullfile(derived,'profile-input.json'),r);
recipe.inputFile="../input/profile-input.json";recipe.inputSHA256=inkprof.internal.sha256(fullfile(derived,'profile-input.json'));
recipe.profilingTI3SHA256=r.profilingTI3SHA256;recipe.patchCount=r.patchCount;
recipe.densityTrial=struct('sourceJob',inkprof.internal.relativePath(project,job),'sourceProfileSHA256',status.profileSHA256, ...
 'sourceRecipeSHA256',status.recipeSHA256,'densityReportSHA256',densityHash,'parameters',d.parameters,'originalRowCount',numel(v.ids),'retainedRowCount',numel(rows));
mkdir(fullfile(folder,'recipe'));trialRecipe=fullfile(folder,'recipe','recipe.json');inkprof.internal.writeJson(trialRecipe,recipe);
copyfile(densityFile,fullfile(folder,'measurement-density.json'));copyfile(d.fitReport,fullfile(folder,'original-fit.json'));
result=struct('status',"prepared-not-built",'sourceProfileSHA256',status.profileSHA256,'recipe',trialRecipe,'parameters',d.parameters,'automaticallySelected',false,'development',struct('available',false),'originalJob',job);
saveResult();
try
 if options.RunBuild
  options.Activity("Building the separate balanced ICC candidate");
  [trialJob,built]=inkprof.runProfileJob(trialRecipe,ShowDialog=options.ShowJobDialog);result.job=trialJob;result.status=string(built.status);saveResult();
  assert(result.status=="succeeded",'inkprof:Density','Trial build failed; inspect its job log.');
  paths=inkprof.paths();bin=inkprof.internal.argyllBin("");suffix="";if ispc,suffix=".exe";end
  request=struct('fitReport',fullfile(folder,'original-fit.json'),'fitSHA256',d.fitReportSHA256,'candidate',fullfile(trialJob,'result','profile.icc'), ...
   'candidateSHA256',built.profileSHA256,'xicclu',fullfile(bin,"xicclu"+suffix),'selectedRows',rows);
  inkprof.internal.writeJson(fullfile(folder,'comparison-request.json'),request);
  result.commonFitFile=fullfile(folder,'common-fit-comparison.json');
  options.Activity("Comparing both profiles against all original measured patches");
  inkprof.runPython(fullfile(paths.Root,'analysis','density_comparison.py'),[fullfile(folder,'comparison-request.json'),result.commonFitFile],RequiredModules=["numpy","colour","PIL"]);
  result.commonFit=jsondecode(fileread(result.commonFitFile));
  options.Activity("Checking photographic gradients of the original profile");
  [baseGrad,baseFile]=inkprof.checkPhotoGradients(job,ShowDialog=false);
  options.Activity("Checking photographic gradients of the balanced candidate");
  [newGrad,newFile]=inkprof.checkPhotoGradients(trialJob,ShowDialog=false);
  result.gradients=struct('original',baseFile,'candidate',newFile,'originalMetrics',baseGrad.comparisonMetrics,'candidateMetrics',newGrad.comparisonMetrics);
  if options.DevelopmentMeasurement~=""&&~isempty(options.DevelopmentIds)
   options.Activity("Comparing reserved development patches");
   [oldDev,oldFolder]=inkprof.proposeRefinement(job,options.DevelopmentMeasurement,DevelopmentSampleIds=options.DevelopmentIds,UseJacobian=false,MaxNewPatches=1,ShowDialog=false);
   [newDev,newFolder]=inkprof.proposeRefinement(trialJob,options.DevelopmentMeasurement,DevelopmentSampleIds=options.DevelopmentIds,UseJacobian=false,MaxNewPatches=1,ShowDialog=false);
   assert(isequal(string({oldDev.evaluatedPatches.sampleId}),string({newDev.evaluatedPatches.sampleId})),'inkprof:Density','Development IDs differ.');
   oldError=[oldDev.evaluatedPatches.deltaE00];newError=[newDev.evaluatedPatches.deltaE00];
   result.development=struct('available',true,'count',numel(oldError),'originalReport',oldFolder,'candidateReport',newFolder, ...
    'originalMean',mean(oldError),'candidateMean',mean(newError),'worstRegression',max(newError-oldError),'deltaE00Change',newError-oldError);
  end
  result.status="review-required";
 end
 assert(inkprof.internal.sha256(profile)==string(status.profileSHA256)&&inkprof.internal.sha256(densityFile)==densityHash,'inkprof:Integrity','Original profile or density report changed.');
 options.Activity("Saving comparison results and provenance");
 saveResult();inkprof.internal.recordProjectStep(folder,"Measured density balancing trial; original profile and measurements retained; no workflow profile selected");
catch err
 result.status="failed";result.error=string(err.message);saveResult();rethrow(err);
end
 function saveResult(),inkprof.internal.writeJson(fullfile(folder,'density-trial.json'),result);end
end
