% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function [steps,restored]=refinementRemeasureState(state,proposal)
% Replay the recorded branch at the time this printed refinement was saved.
history=state.history;if isstruct(history),history=num2cell(history);end
steps=state.steps;
for name=string(fieldnames(steps))',steps.(name).status="pending";end
found=false;
for k=1:numel(history)
 e=history{k};if string(e.iterationId)~=string(state.iterationId)||e.cycle~=state.cycle,continue;end
 id=string(e.step);if ~isfield(steps,id),continue;end
 switch string(e.status)
  case "superseded",steps.(id)=e.details;steps.(id).status="stale";
  case "started",steps.(id).status="running";
  case {"pending","failed"},steps.(id).status=string(e.status);
  case "completed"
   if isfield(e.details,'result'),steps.(id)=e.details.result;end
 end
 if id=="refine"&&string(e.status)=="completed"&&isfield(e.details,'result')&& ...
   isfield(e.details.result.outputs,'proposal')&&string(e.details.result.outputs.proposal)==proposal
  snapshot=steps;found=true;
 end
end
assert(found,'inkprof:WorkflowRecovery','No saved history for this refinement in the current iteration.');
steps=snapshot;
% Restore only ancestors required for this physical target; never restore
% its suspect measurement, later continuation, verification or approval.
defs=inkprof.internal.workflowSteps(state.mode);restored="refine";changed=true;
while changed
 changed=false;
 for id=reshape(restored,1,[])
  d=defs(string({defs.id})==id);
  for dep=string(d.requires)
   if ~ismember(dep,restored),restored(end+1)=dep;changed=true;end
  end
 end
end
if string(steps.recipe.status)=="completed",restored(end+1)="recipe";end
for id=restored
 assert(string(steps.(id).status)=="completed",'inkprof:WorkflowRecovery','Saved refinement requires a completed historical %s step.',id);
end
end
