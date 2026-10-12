% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [result,folder]=rebuildProfileGrid(inputFolder,sourceJob,options)
%REBUILDPROFILEGRID Build a separate higher-resolution trial from the same B1.
arguments
 inputFolder (1,1) string
 sourceJob (1,1) string
 options.Quality (1,1) string {mustBeMember(options.Quality,["high","ultra"])} = "ultra"
 options.Tables (1,1) string {mustBeMember(options.Tables,["B2A","both"])} = "B2A"
 options.RunBuild (1,1) logical = true
 options.ShowDialog (1,1) logical = true
 options.RunChecks (1,1) logical = true
 options.ColprofExecutable (1,1) string = ""
end
inputFolder=inkprof.internal.absolutePath(inputFolder);sourceJob=inkprof.internal.absolutePath(sourceJob);
project=inkprof.internal.findProject(inputFolder);
assert(project~=""&&project==inkprof.internal.findProject(sourceJob),'inkprof:GridTrial','Use input and job from the same project.');
recipePath=fullfile(sourceJob,'recipe.json');recipe=jsondecode(fileread(recipePath));
status=jsondecode(fileread(fullfile(sourceJob,'status.json')));profile=fullfile(sourceJob,'result','profile.icc');
assert(string(status.status)=="succeeded"&&string(status.profileSHA256)==inkprof.internal.sha256(profile),'inkprof:Integrity','Source ICC changed or job did not succeed.');
assert(string(status.recipeSHA256)==inkprof.internal.sha256(recipePath),'inkprof:Integrity','Source recipe changed.');
assert(string(recipe.inputSHA256)==inkprof.internal.sha256(fullfile(inputFolder,'profile-input.json')),'inkprof:Integrity','Select the exact B1 input used by the source profile.');
levels=["medium","high","ultra"];
assert(isfield(recipe.engine,'b2aQuality'),'inkprof:GridTrial','Source recipe must specify B2A quality.');
oldB=string(recipe.engine.b2aQuality);oldA=string(recipe.engine.quality);
assert(find(levels==options.Quality)>find(levels==oldB),'inkprof:GridTrial','Choose a B2A resolution higher than the source.');
args=string(recipe.engine.plannedArguments(:))';
assert(nnz(args=="-b"+extractBefore(oldB,2))==1,'inkprof:GridTrial','Unsupported B2A arguments.');
args(args=="-b"+extractBefore(oldB,2))="-b"+extractBefore(options.Quality,2);
recipe.engine.b2aQuality=options.Quality;
if options.Tables=="both"
 assert(find(levels==options.Quality)>find(levels==oldA),'inkprof:GridTrial','Choose an A2B resolution higher than the source.');
 args(args=="-q"+extractBefore(oldA,2))="-q"+extractBefore(options.Quality,2);
 recipe.engine.quality=options.Quality;
 if isfield(recipe.engine,'preRegularization')&&recipe.engine.preRegularization.enabled
  preArgs=string(recipe.engine.preRegularization.plannedArguments(:))';
  preArgs(preArgs=="-q"+extractBefore(oldA,2))="-q"+extractBefore(options.Quality,2);
  recipe.engine.preRegularization.plannedArguments=preArgs;
 end
end
recipe.engine.plannedArguments=args;
recipe.inputFile="../../profile-input.json";
recipe.createdUTC=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
recipe.gridTrial=struct('sourceProfileSHA256',status.profileSHA256,'sourceRecipeSHA256',status.recipeSHA256, ...
 'tables',options.Tables,'quality',options.Quality,'originalA2BQuality',oldA,'originalB2AQuality',oldB, ...
 'basis',"Same locked measurements and recipe; only requested Argyll table quality changes. Both-table trials also change pre-fit resolution when enabled.");
folder=fullfile(inputFolder,'recipes',string(java.util.UUID.randomUUID()));mkdir(folder);
recipeFile=fullfile(folder,'recipe.json');inkprof.internal.writeJson(recipeFile,recipe);
result=struct('status',"recipe-saved-not-built",'recipe',recipeFile,'sourceJob',sourceJob,'job',"",'gridTrial',recipe.gridTrial);
if options.RunBuild
 [job,built]=inkprof.runProfileJob(recipeFile,ShowDialog=options.ShowDialog,ColprofExecutable=options.ColprofExecutable);
 result.job=job;result.status=string(built.status);
 if result.status=="succeeded"
  assert(inkprof.internal.sha256(profile)==string(status.profileSHA256),'inkprof:Integrity','Source ICC changed during the trial.');
  paths=inkprof.paths();gridFile=fullfile(folder,'grid-comparison.json');
  inkprof.runPython(fullfile(paths.Root,'profiles','icc_grid_compare.py'),[profile,fullfile(job,'result','profile.icc'),gridFile]);
  result.grids=jsondecode(fileread(gridFile));
  result.gridIncreased=any([result.grids.comparison.increased]);
  curveFile=fullfile(folder,'grid-curves.json');
  inkprof.runPython(fullfile(paths.Root,'analysis','grid_trial_curves.py'),[profile,fullfile(job,'result','profile.icc'),curveFile],RequiredModules=["numpy","scipy","PIL"]);
  result.curveFile=curveFile;
  if options.RunChecks
   [~,result.fitReport]=inkprof.checkProfileFit(job,ShowDialog=false);
   [~,result.gridReport]=inkprof.checkProfileGrid(job,ShowDialog=false);
   [~,result.photoReport]=inkprof.checkPhotoGradients(job,ShowDialog=false);
  end
 end
end
inkprof.internal.writeJson(fullfile(folder,'grid-trial.json'),result);
inkprof.internal.recordProjectStep(folder,"Higher ICC grid trial; separate candidate, same B1 measurements; no profile selected");
end
