% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [iterationFolder,result]=continueRefinement(proposalFolder,measurementFile,options)
%CONTINUEREFINEMENT Link measured C3 refinement to parent training and new ICC/C2.
arguments
 proposalFolder (1,1) string = ""
 measurementFile (1,1) string = ""
 options.Name (1,1) string = "Continued profile iteration"
 options.PrepareOnly (1,1) logical = false
 options.MaxNewPatches (1,1) double {mustBePositive,mustBeInteger} = 100
 options.NormTarget (1,1) double {mustBeFinite,mustBeNonnegative} = 1
 options.GrayWeight (1,1) double {mustBeFinite,mustBePositive} = 2
 options.RepeatLimit (1,1) double {mustBeFinite,mustBePositive} = 1
 options.MaxPatchRegression (1,1) double {mustBeFinite,mustBeNonnegative} = .5
 options.MaxGrayRegression (1,1) double {mustBeFinite,mustBeNonnegative} = .25
 options.MinImprovement (1,1) double {mustBeFinite,mustBeNonnegative} = .01
 options.DPI (1,1) double {mustBePositive,mustBeInteger} = 300
 options.Paper (1,1) string = "A4-landscape"
 options.Seed (1,1) double {mustBeNonnegative,mustBeInteger} = 42
 options.ShowJobDialog (1,1) logical = false
end
iterationFolder="";result=[];
if proposalFolder==""
 paths=inkprof.paths();p=uigetdir(paths.Projects,'Select rendered refinement proposal folder');if isequal(p,0),return;end;proposalFolder=string(p);
end
plan=inkprof.internal.refinementContinuationPlan(proposalFolder);
if measurementFile==""
 [f,p]=uigetfile({'*.json;*.ti3;*.mxf','Saved refinement measurement'},'Select measurement of this refinement target');
 if isequal(f,0),return;end;measurementFile=fullfile(p,f);
end
measurementFile=inkprof.internal.absolutePath(measurementFile);
runFolder=fullfile(plan.proposalFolder,'continuations',string(java.util.UUID.randomUUID()));mkdir(runFolder);
result=struct('status',"validating",'plan',plan,'options',options,'qualityApproved',false);
saveState();
try
 [~,~,ext]=fileparts(measurementFile);
 if any(lower(ext)==[".ti3",".mxf"])
  [~,measurementFile]=inkprof.importMeasurement(measurementFile,TargetFile=plan.targetFile, ...
   SessionFolder=fullfile(runFolder,'import'),ShowPreview=false);
 end
 plan=inkprof.internal.refinementContinuationPlan(plan.proposalFolder,measurementFile);
 result.plan=plan;result.status="validated";saveState();
 fprintf('InkProf: %d previous + %d new fitting patches = %d. %d development and %d controls excluded from fitting.\n', ...
 plan.basePatchCount,plan.newFitCount,plan.expectedTrainingCount,plan.developmentCount,plan.controlCount);
 if options.PrepareOnly
  iterationFolder=runFolder;fprintf('Prepared only; no ICC generated. %s\n',runFolder);return;
 end
 result.status="profiling";saveState();
 [iterationFolder,iteration]=inkprof.iterateProfile(measurementFile, ...
  ProjectFolder=plan.projectFolder,BaseInputFolder=plan.baseInputFolder,RoleFile=plan.roleFile, ...
  ContinuationFile=fullfile(runFolder,'continuation.json'),Name=options.Name, ...
  MaxNewPatches=options.MaxNewPatches,NormTarget=options.NormTarget,GrayWeight=options.GrayWeight,RepeatLimit=options.RepeatLimit, ...
  MaxPatchRegression=options.MaxPatchRegression,MaxGrayRegression=options.MaxGrayRegression,MinImprovement=options.MinImprovement, ...
  DPI=options.DPI,Paper=options.Paper,Seed=options.Seed,ShowJobDialog=options.ShowJobDialog);
 result.status="ready-for-print-review";result.iterationFolder=iterationFolder;
 result.profileFile=fullfile(iterationFolder,iteration.profileFile);
 result.verificationFolder=fullfile(iterationFolder,iteration.verification.folder);saveState();
 inkprof.internal.recordProjectStep(runFolder,"Continuation: measured refinement linked to prior training and new ICC/C2; not quality approved");
catch err
 result.status="failed";result.error=struct('identifier',err.identifier,'message',err.message);saveState();rethrow(err);
end
 function saveState()
  inkprof.internal.writeJson(fullfile(runFolder,'continuation.json'),result);
  f=fopen(fullfile(runFolder,'progress.log'),'a');assert(f>=0);c=onCleanup(@()fclose(f));
  fprintf(f,'%s | %s\n',char(datetime('now','Format',"yyyy-MM-dd HH:mm:ss")),result.status);
 end
end
