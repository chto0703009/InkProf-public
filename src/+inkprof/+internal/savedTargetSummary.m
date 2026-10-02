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
if isfield(outputs,'proposal')
 proposal=jsondecode(fileread(w.resolve(outputs.proposal)));
 if isfield(proposal,'candidates'),lines(end+1)="New refinement patches: "+numel(proposal.candidates)+" (printed total includes control/repeat patches).";end
end
lines=[lines;"Print folder: "+string(fileparts(target));"Select the completed TIFF16 step and use Copy TIFF16 for printing to choose another folder."];
end
