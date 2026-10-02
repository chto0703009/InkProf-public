function state=upgradeWorkflowState(state)
% Preserve old print confirmations as historical data, not prerequisites.
if ~isfield(state.steps,'compare')
 state.steps.compare=struct('status',"pending",'outputs',struct,'artifacts',struct([]),'message',"");
end
if isfield(state,'workflowRevision')&&state.workflowRevision>=2,return;end
map=struct('print','measurement','c2print','c2measurement','refineprint','refinemeasurement');
if isfield(map,state.currentStep),state.currentStep=map.(state.currentStep);end
if string(state.steps.export.status)=="completed"&&~isfield(state.steps.export.outputs,'finalReport')
 state.steps.export.status="stale";
 state.steps.export.message="Previous ICC preserved. Run Save ICC and measurement certificate to create the new measurement certificate.";
end
state.workflowRevision=2;
end
