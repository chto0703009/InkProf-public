function state=upgradeWorkflowState(state)
% Preserve old print confirmations as historical data, not prerequisites.
if isfield(state,'workflowRevision')&&state.workflowRevision>=2,return;end
map=struct('print','measurement','c2print','c2measurement','refineprint','refinemeasurement');
if isfield(map,state.currentStep),state.currentStep=map.(state.currentStep);end
if string(state.steps.export.status)=="completed"&&~isfield(state.steps.export.outputs,'finalReport')
 state.steps.export.status="stale";
 state.steps.export.message="Tidigare ICC bevarad. Kör Spara ICC och slutrapport för att skapa den nya slutrapporten.";
end
state.workflowRevision=2;
end
