% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function extension=gamutTargetExtension(project,profile,sourceFile)
% Resolve a checked, unmeasured print package for a new immutable version.
if sourceFile=="",sourceFile=inkprof.internal.latestGamutProposal(project,profile,true);end
assert(sourceFile~="",'inkprof:Extension','No completed gamut print target exists for the current profile. Untick Extend latest target and create a TIFF16 target first.');
[p,folder]=inkprof.internal.existingGamutPrint(sourceFile,project,profile);
context=jsondecode(fileread(fullfile(folder,'sources','context.json')));
job=fullfile(project,context.profileJob);
assert(inkprof.internal.sha256(fullfile(folder,'sources','training.ti3'))==string(context.trainingTI3SHA256)&& ...
 inkprof.internal.sha256(fullfile(job,'engine.ti3'))==string(context.trainingTI3SHA256)&& ...
 inkprof.internal.sha256(fullfile(folder,'sources','profile.icc'))==inkprof.internal.sha256(profile), ...
 'inkprof:Integrity','The saved target training or profile snapshot changed.');
% Any started measurement of this exact TI2 makes extension inappropriate.
charts=dir(fullfile(project,'**','chart.json'));
for k=1:numel(charts)
 chartFile=fullfile(charts(k).folder,charts(k).name);chart=jsondecode(fileread(chartFile));
 if ~isfield(chart,'sourceSHA256')||string(chart.sourceSHA256)~=string(p.print.ti2SHA256),continue;end
 checkpointFile=fullfile(charts(k).folder,'measurement-checkpoint.json');
 if isfile(checkpointFile)
  checkpoint=jsondecode(fileread(checkpointFile));
  if isfield(checkpoint,'confirmedPasses')&&~isempty(checkpoint.confirmedPasses)
   error('inkprof:ExtensionMeasured','This target has saved measurement rows. Resume its original TI2 or create a separate additional target.');
  end
 end
 if isfile(fullfile(charts(k).folder,'chart.ti3'))||isfile(fullfile(charts(k).folder,'paired','chart.ti3'))
  error('inkprof:ExtensionMeasured','This target has instrument readings. Keep its original TI2 or create a separate additional target.');
 end
 revisions=dir(fullfile(charts(k).folder,'measurement-*.json'));
 for j=1:numel(revisions)
  m=jsondecode(fileread(fullfile(revisions(j).folder,revisions(j).name)));
  if isfield(m,'data')&&isfield(m.data,'rgb')&&~isempty(m.data.rgb)
   error('inkprof:ExtensionMeasured','This target already has measurements. Keep measuring its original TI2 or create a separate additional target.');
  end
 end
end
parentHash=inkprof.internal.sha256(sourceFile);
rolesFile=fullfile(folder,'refinement-print','placement-plan.json');roles=jsondecode(fileread(rolesFile));
patches=roles.patches;keep=ismember(string({patches.role}),["fit","adaptive_holdout","adaptive_validation"]);
assert(any(keep),'inkprof:Extension','The target has no fitting or development patches to extend.');
patches=patches(keep);rgb=reshape([patches.rgbPercent],3,[])';
assert(all(isfinite(rgb),'all')&&all(rgb>=0&rgb<=100,'all'),'inkprof:Integrity','Invalid saved target RGB.');
extension=struct('sourceFile',string(sourceFile),'roleFile',string(rolesFile),'targetFile',fullfile(folder,'refinement-print','print','target.ti2'),'rgbPercent',rgb, ...
 'provenance',struct('documentType',"inkprof.gamut-target-extension", ...
 'parentProposal',inkprof.internal.relativePath(project,sourceFile), ...
 'parentProposalSHA256',parentHash,'parentIterationId',p.iterationId, ...
 'parentTI2SHA256',p.print.ti2SHA256,'parentRoleSHA256',p.print.roleSHA256, ...
 'sourcePatchIds',string({patches.sampleId}),'policy',"New print version; original retained. Fit/development patches carried forward; controls regenerated. Print and measure the new TI2."));
end
