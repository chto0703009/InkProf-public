% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [proposal,folder]=refineFromGamut(jobFile,anchors,options)
%REFINEFROMGAMUT Propose measured RGB neighbourhoods around selected gamut points.
arguments
 jobFile (1,1) string
 anchors (:,1) struct
 options.RadiusPercent (1,1) double {mustBeFinite,mustBePositive,mustBeLessThanOrEqual(options.RadiusPercent,20)} = 3
 options.MinSpacingPercent (1,1) double {mustBeFinite,mustBePositive,mustBeLessThanOrEqual(options.MinSpacingPercent,20)} = 1
 options.MaxNewPatches (1,1) double {mustBeInteger,mustBePositive,mustBeLessThanOrEqual(options.MaxNewPatches,1000)} = 100
 options.ShowDialog (1,1) logical = true
 options.CreatePrint (1,1) logical = true
 options.PlanPaper (1,1) logical = true
end
proposal=[];folder="";jobFile=inkprof.internal.absolutePath(jobFile);job=fileparts(jobFile);
project=inkprof.internal.findProject(job);assert(project~="",'inkprof:Gamut','Select a profile job in an InkProf project.');
status=jsondecode(fileread(jobFile));profile=fullfile(job,'result','profile.icc');training=fullfile(job,'engine.ti3');
assert(string(status.status)=="succeeded"&&inkprof.internal.sha256(profile)==string(status.profileSHA256),'inkprof:Integrity','Parent ICC changed.');
assert(~isempty(anchors)&&all(string({anchors.profileSHA256})==string(status.profileSHA256)),'inkprof:Integrity','Select points from the current ICC.');
v=inkprof.cgatsData(inkprof.importCgats(training),RGBScale=100);trainingHash=inkprof.internal.sha256(training);
work=string(tempname);mkdir(work);cleanup=onCleanup(@()rmdir(work,'s')); %#ok<NASGU>
paths=inkprof.paths();bin=inkprof.internal.argyllBin("");suffix="";if ispc,suffix=".exe";end
request=struct('profile',profile,'profileSHA256',status.profileSHA256,'xicclu',fullfile(bin,"xicclu"+suffix), ...
 'anchors',anchors,'anchorRGBPercent',reshape([anchors.rgbPercent],3,[])','existingRGBPercent',v.rgb, ...
 'radiusPercent',options.RadiusPercent,'minSpacingPercent',options.MinSpacingPercent,'maxPatches',options.MaxNewPatches);
inkprof.internal.writeJson(fullfile(work,'request.json'),request);
calculation=inkprof.internal.calculationProgress("Gamut patches","Calculating neighbouring device RGB patches...");
stage=fullfile(work,'proposal');
inkprof.runPython(fullfile(paths.Root,'analysis','gamut_refinement.py'),[fullfile(work,'request.json'),stage],RequiredModules=["numpy","colour"],TimeoutSeconds=220);
proposal=jsondecode(fileread(fullfile(stage,'proposal.json')));clear calculation;
selected=1:numel(proposal.candidates);
if options.ShowDialog,selected=inkprof.internal.reviewGamutCandidates(proposal);if isempty(selected),proposal=[];return;end,end
proposal.name="Gamut-area refinement";proposal.iterationId=string(java.util.UUID.randomUUID());
proposal.createdUTC=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
proposal.selection=struct('proposedCount',numel(proposal.candidates),'selectedPatchIds',string({proposal.candidates(selected).patchId}), ...
 'reviewed',options.ShowDialog,'selectedCount',numel(selected));
inkprof.internal.writeJson(fullfile(stage,'proposed-candidates.json'),proposal.candidates);
proposal.candidates=proposal.candidates(selected);proposal.status="selected-for-print";
context=struct('profileJob',replace(extractAfter(job,strlength(project)+1),filesep,'/'),'trainingTI3SHA256',trainingHash);
mkdir(fullfile(stage,'sources'));inkprof.internal.writeJson(fullfile(stage,'sources','context.json'),context);
copyfile(profile,fullfile(stage,'sources','profile.icc'));copyfile(training,fullfile(stage,'sources','training.ti3'));
assert(inkprof.internal.sha256(fullfile(stage,'sources','profile.icc'))==string(proposal.sourceProfileSHA256) ...
 &&inkprof.internal.sha256(profile)==string(proposal.sourceProfileSHA256) ...
 &&inkprof.internal.sha256(fullfile(stage,'sources','training.ti3'))==trainingHash ...
 &&inkprof.internal.sha256(training)==trainingHash,'inkprof:Integrity','Source profile or measurements changed.');
proposal.snapshots=struct('context',"sources/context.json",'profile',"sources/profile.icc",'training',"sources/training.ti3");
folder=fullfile(project,'refinements',proposal.iterationId);if ~isfolder(fileparts(folder)),mkdir(fileparts(folder));end
inkprof.internal.writeJson(fullfile(stage,'proposal.json'),proposal);movefile(stage,folder);
if options.CreatePrint
 proposal.print=inkprof.internal.createRefinementPrint(proposal,job,fullfile(folder,'refinement-print'),300,"A4-landscape",42,options.PlanPaper);
 inkprof.internal.writeJson(fullfile(folder,'proposal.json'),proposal);
end
inkprof.internal.recordProjectStep(folder,"Gamut-area refinement: "+numel(proposal.candidates)+" selected patches; device RGB, no ICC applied");
end
