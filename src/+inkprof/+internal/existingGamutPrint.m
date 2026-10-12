% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [proposal,folder]=existingGamutPrint(file,project,profile)
% Validate the already printed package; never regenerate patch placement.
file=inkprof.internal.absolutePath(file);project=inkprof.internal.absolutePath(project);folder=fileparts(file);
assert(startsWith(file,project+filesep),'inkprof:Integrity','Select a proposal inside the current project.');
proposal=jsondecode(fileread(file));
assert(string(proposal.documentType)=="inkprof.gamut-refinement"&&isfield(proposal,'print'),'inkprof:Refinement','Saved proposal has no completed print package.');
assert(string(proposal.sourceProfileSHA256)==inkprof.internal.sha256(profile),'inkprof:Integrity','Proposal belongs to another ICC.');
% Derive paths from the portable project folder, not saved absolute paths.
printFolder=fullfile(folder,'refinement-print');ti2=fullfile(printFolder,'print','target.ti2');role=fullfile(printFolder,'placement-plan.json');
assert(inkprof.internal.sha256(ti2)==string(proposal.print.ti2SHA256)&& ...
 inkprof.internal.sha256(role)==string(proposal.print.roleSHA256),'inkprof:Integrity','Printed target or patch roles changed.');
inkprof.verifyPackage(fileparts(ti2));
end
