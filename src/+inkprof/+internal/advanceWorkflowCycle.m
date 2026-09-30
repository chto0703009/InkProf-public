function state=advanceWorkflowCycle(state,outputs,artifacts)
% Preserve ancestry while installing the next candidate; all checks start over.
state.activeContinuation=struct('proposal',state.steps.refine.outputs.proposal, ...
    'measurement',state.steps.refinemeasurement.outputs.measurement);
defs=inkprof.internal.workflowSteps();affected="profile";
for d=defs'
    if any(ismember(string(d.requires),affected)),affected(end+1)=string(d.id);end %#ok<AGROW>
end
for id=affected,state.steps.(id).status="stale";end
state.parentIterationId=state.iterationId;
state.iterationId=string(java.util.UUID.randomUUID());
state.cycle=state.cycle+1;
state.steps.profile=struct('status',"completed",'outputs',outputs,'artifacts',artifacts,'message',"Ny kandidat; nytt C1/C2/C3 krävs");
state.currentStep="checks";
end
