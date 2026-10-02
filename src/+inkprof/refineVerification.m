function [proposal,folder]=refineVerification(reportFile,options)
%REFINEVERIFICATION Propose device RGB probes using C3 residuals and Jacobians.
% MATLAB Base performs SVD, regularization, bounded sampling and ranking.
% Python verifies C3 sources and calls Argyll for absolute ICC derivatives.
arguments
 reportFile (1,1) string = ""
 options.Name (1,1) string = "C3 Jacobian refinement"
 options.MaxNewPatches (1,1) double {mustBePositive,mustBeInteger} = 100
 options.NormTarget (1,1) double {mustBeFinite,mustBeNonnegative} = 1
 options.ErrorThreshold (1,1) double {mustBeFinite,mustBeNonnegative} = 1
 options.RadiusPercent (1,1) double {mustBeFinite,mustBePositive} = 5
 options.MinSpacingPercent (1,1) double {mustBeFinite,mustBePositive} = 1
 options.GrayWeight (1,1) double {mustBeFinite,mustBePositive} = 2
 options.RepeatLimit (1,1) double {mustBeFinite,mustBePositive} = 1
 options.DerivativeStepPercent (1,1) double {mustBeFinite,mustBePositive} = .5
 options.RegularizationFraction (1,1) double {mustBeFinite,mustBePositive} = .1
 options.MaxJacobianChange (1,1) double {mustBeFinite,mustBePositive} = .5
 options.CreatePrint (1,1) logical = false
 options.DPI (1,1) double {mustBePositive,mustBeInteger} = 300
 options.PlanPaper (1,1) logical = false
 options.Paper (1,1) string = "A4-landscape"
 options.Seed (1,1) double {mustBeInteger,mustBeNonnegative} = 42
 options.ShowDialog (1,1) logical = true
end
proposal=[];folder="";
if reportFile==""
 [f,p]=uigetfile('*.json','Select C3 verification-check.json');if isequal(f,0),return;end
 reportFile=fullfile(p,f);
end
assert(options.MaxNewPatches<=10000&&options.MinSpacingPercent<=options.RadiusPercent&&options.DerivativeStepPercent<=10, ...
 'inkprof:Refinement','Budget <=10000, spacing <= radius and derivative step <=10 required.');
reportFile=inkprof.internal.absolutePath(reportFile);paths=inkprof.paths();
project=inkprof.internal.findProject(reportFile);assert(project~="",'inkprof:Project','C3 report must belong to an InkProf project.');
work=string(tempname);mkdir(work);cleanup=onCleanup(@()rmdir(work,'s'));
bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'xicclu');if ispc,exe=exe+".exe";end
fprintf('InkProf: validating C3 sources and calculating local ICC Jacobians...\n');
inkprof.runPython(fullfile(paths.Root,'analysis','verification_refinement_context.py'), ...
 [reportFile,exe,fullfile(work,'context.json'),"--step",string(options.DerivativeStepPercent)], ...
 RequiredModules=["numpy","scipy","colour","PIL"],TimeoutSeconds=180);
context=jsondecode(fileread(fullfile(work,'context.json')));
job=fullfile(project,string(context.profileJob));trainingFile=fullfile(job,'engine.ti3');
assert(inkprof.internal.sha256(trainingFile)==string(context.trainingTI3SHA256),'inkprof:Hash','Training source changed.');
assert(inkprof.internal.sha256(fullfile(job,'result','profile.icc'))==inkprof.internal.sha256(context.profileFile),'inkprof:Hash','Profile job differs from C3 profile.');
v=inkprof.cgatsData(inkprof.importCgats(trainingFile),RGBScale=100);
proposal=inkprof.internal.verificationCandidates(context.observations,v.rgb,options);
proposal.schemaVersion=1;proposal.documentType="inkprof.verification-refinement";
proposal.name=options.Name;proposal.iterationId=string(java.util.UUID.randomUUID());
proposal.createdUTC=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
proposal.parameters=options;proposal.observations=context.observations;
proposal.measurementRole="adaptive_validation";proposal.qualityApproved=false;
proposal.status="proposal-review-required";proposal.profileApplied=false;
proposal.sourceReport=context.sourceReport;
proposal.method="Regularized residual direction plus three right singular vectors; sample both signs at half/full bounded radius; exclude measured/training RGB and enforce 16-bit spacing.";
proposal.limitations=["Sampling probes, not predicted correction or error reduction.", ...
 "Review print comparability before printing or merging. No physical gamut or ISO certification.", ...
 "Steering C2 is development data; retain fresh independent final validation.", ...
 "Jacobian is derived from the imperfect model. Step-sensitive observations are excluded."];
parent=fullfile(fileparts(reportFile),'refinement');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,proposal.iterationId);mkdir(folder);mkdir(fullfile(folder,'sources'));
copyfile(fullfile(work,'context.json'),fullfile(folder,'sources','context.json'));
copyfile(reportFile,fullfile(folder,'sources','verification-check.json'));
copyfile(context.referenceFile,fullfile(folder,'sources','verification.json'));
copyfile(context.measurementFile,fullfile(folder,'sources','measurement.json'));
copyfile(context.profileFile,fullfile(folder,'sources','profile.icc'));
copyfile(trainingFile,fullfile(folder,'sources','training.ti3'));
proposal.snapshots=struct('report',"sources/verification-check.json",'context',"sources/context.json", ...
 'reference',"sources/verification.json",'measurement',"sources/measurement.json",'profile',"sources/profile.icc",'training',"sources/training.ti3");
if ~isempty(proposal.candidates)
 c=proposal.candidates;rgb=reshape([c.rgbPercent],3,[])';ids=string({c.patchId})';
 table=struct('signature',"CTI1",'fields',["SAMPLE_ID","RGB_R","RGB_G","RGB_B"], ...
  'data',[ids,compose('%.17g',rgb)],'metadata',{{["DESCRIPTOR",options.Name];["ORIGINATOR","InkProf"];["COLOR_REP","iRGB"]}});
 inkprof.exportCgats(fullfile(folder,'target.ti1'),struct('documentType',"inkprof.cgats",'tables',table));
end
inkprof.internal.writeJson(fullfile(folder,'proposal.json'),proposal);
f=fopen(fullfile(folder,'progress.log'),'w');assert(f>=0);cl=onCleanup(@()fclose(f));
fprintf(f,'%s | source hashes and patch identities verified\n',proposal.createdUTC);
fprintf(f,'MATLAB Base | SVD and regularized sampling | radius %.3f RGB percentage points | max %d new patches\n',options.RadiusPercent,options.MaxNewPatches);
fprintf(f,'Norm %.6g | target %.6g | excluded repeat groups %d | new candidates %d | %s\n',proposal.errorNorm.value,options.NormTarget,proposal.errorNorm.excludedCount,numel(proposal.candidates),proposal.stopReason);
for k=1:numel(proposal.diagnostics)
 d=proposal.diagnostics{k};fprintf(f,'Observation %d | %s | derivative change %.4f\n',k,d.status,d.stepRelativeChange);
end
clear cl
if options.CreatePrint&&~isempty(proposal.candidates)
 fprintf('InkProf: rendering device-RGB refinement target with repeat controls...\n');
 proposal.print=inkprof.internal.createRefinementPrint(proposal,job,fullfile(folder,'refinement-print'),options.DPI,options.Paper,options.Seed,options.PlanPaper);
 inkprof.internal.writeJson(fullfile(folder,'proposal.json'),proposal);
end
inkprof.internal.recordProjectStep(folder,"C3 residual/Jacobian refinement proposal; no profile approval or measurement merging");
fprintf('InkProf: %d new patches (max %d). %s\nProposal: %s\n',numel(proposal.candidates),options.MaxNewPatches,proposal.stopReason,folder);
if ~options.ShowDialog,return;end
inkprof.showRefinementProposal(folder);
end
