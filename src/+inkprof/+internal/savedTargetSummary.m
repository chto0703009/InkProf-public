% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function lines=savedTargetSummary(w,id)
% Human-readable saved target facts, derived from the persisted package.
lines=strings(0,1);outputs=w.State.steps.(id).outputs;
if isfield(outputs,'target')
 target=w.resolve(outputs.target);
elseif isfield(outputs,'verification')
 target=fullfile(fileparts(w.resolve(outputs.verification)),'print','target.ti2');
else
 return
end
file=fullfile(fileparts(target),'target.json');if ~isfile(file),return;end
r=jsondecode(fileread(file));if ~isfield(r,'ids'),return;end
pages=[dir(fullfile(fileparts(target),'*.tif'));dir(fullfile(fileparts(target),'*.tiff'))];
if isempty(pages),return;end
lines="Target saved: "+numel(r.ids)+" patches in "+numel(pages)+" TIFF16 file(s).";
if isfield(outputs,'reference')
 reference=jsondecode(fileread(w.resolve(outputs.reference)));
 if isfield(reference,'name'),lines=["Verification target: "+string(reference.name);lines];end
end
if isfield(outputs,'proposal')
 proposal=jsondecode(fileread(w.resolve(outputs.proposal)));
 if isfield(proposal,'verification'),lines(end+1,1)="Included C2 verification patches: "+proposal.verification.patchCount+" (colours also train the next ICC; repeats remain controls).";end
 if isfield(proposal,'candidates'),lines(end+1,1)="New refinement patches: "+numel(proposal.candidates)+" (printed total includes controls and any C2 patches).";end
end
lines=[lines;"Print folder: "+string(fileparts(target));"Select the completed TIFF16 step and use Copy TIFF16 for printing to choose another folder."];
end
