% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [proposal,folder]=rebuildImageRefinement(sourceFile,options)
% Reuse a saved image or gamut selection, adding outstanding C2 to a new print package.
arguments
 sourceFile (1,1) string
 options.VerificationFile (1,1) string = ""
 options.PlanPaper (1,1) logical = true
 options.DPI (1,1) double = 300
 options.Paper (1,1) string = "A4-landscape"
end
sourceFile=inkprof.internal.absolutePath(sourceFile);source=fileparts(sourceFile);project=inkprof.internal.findProject(source);
proposal=jsondecode(fileread(sourceFile));assert(any(string(proposal.documentType)==["inkprof.image-refinement","inkprof.gamut-refinement"]),'inkprof:Image','Select a saved image or gamut proposal.');
context=jsondecode(fileread(fullfile(source,'sources','context.json')));job=fullfile(project,context.profileJob);
assert(inkprof.internal.sha256(fullfile(job,'result','profile.icc'))==string(proposal.sourceProfileSHA256),'inkprof:Integrity','Image proposal profile changed.');
assert(inkprof.internal.sha256(fullfile(source,'sources','training.ti3'))==inkprof.internal.sha256(fullfile(job,'engine.ti3')),'inkprof:Integrity','Saved training data changed.');
proposal.rebuiltFrom=struct('proposalSHA256',inkprof.internal.sha256(sourceFile),'iterationId',proposal.iterationId);
proposal.iterationId=string(java.util.UUID.randomUUID());
proposal.createdUTC=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
for name=["print","verification"],if isfield(proposal,name),proposal=rmfield(proposal,name);end,end
folder=fullfile(project,'refinements',proposal.iterationId);mkdir(folder);
copyfile(fullfile(source,'sources'),fullfile(folder,'sources'));
old=fullfile(folder,'sources','c2');if isfolder(old),rmdir(old,'s');end
copyfile(fullfile(source,'proposed-candidates.json'),fullfile(folder,'proposed-candidates.json'));
if options.VerificationFile~=""
 proposal.verification=inkprof.internal.snapshotVerification(options.VerificationFile,job,fullfile(folder,'sources','c2'));
end
inkprof.internal.writeJson(fullfile(folder,'proposal.json'),proposal);
proposal.print=inkprof.internal.createRefinementPrint(proposal,job,fullfile(folder,'refinement-print'),options.DPI,options.Paper,42,options.PlanPaper);
inkprof.internal.writeJson(fullfile(folder,'proposal.json'),proposal);
inkprof.internal.recordProjectStep(folder,"Saved patch selection rebuilt with pending C2; new immutable print package");
end
