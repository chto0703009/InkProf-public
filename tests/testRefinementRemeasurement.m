% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function tests=testRefinementRemeasurement
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testRestoreOriginalBranchWithoutReprinting(tc)
[w,root,cleanup]=fixture(); %#ok<ASGLU>
target=w.resolve(w.State.steps.refine.outputs.target);hash=inkprof.internal.sha256(fullfile(fileparts(target),'target.tif'));
w.restoreRefinementForRemeasurement();
verifyTrue(tc,w.ready('refinemeasurement'));verifyTrue(tc,w.valid('refine'));
verifyEqual(tc,string(w.State.currentStep),"refinemeasurement");
verifyEqual(tc,string(w.State.steps.profile.outputs.profile),"old-profile.icc");
verifyEqual(tc,string(w.State.steps.refinemeasurement.status),"pending");
verifyEmpty(tc,fieldnames(w.State.steps.refinemeasurement.outputs));
verifyEqual(tc,inkprof.internal.sha256(fullfile(fileparts(target),'target.tif')),hash);
verifyTrue(tc,isfile(fullfile(root,'new-profile.icc')));
verifyNotEmpty(tc,dir(fullfile(root,'workflow-recovery','*.json')));
verifyTrue(tc,inkprof.verifyProject(root).passed);
end
function testChangedHistoricalFileCannotBeRestored(tc)
[w,root,cleanup]=fixture(); %#ok<ASGLU>
before=inkprof.internal.sha256(fullfile(root,'workflow.json'));
f=fopen(fullfile(root,'old-profile.icc'),'a');fprintf(f,'changed');fclose(f);
verifyError(tc,@()w.restoreRefinementForRemeasurement(),'inkprof:WorkflowRecovery');
verifyEqual(tc,inkprof.internal.sha256(fullfile(root,'workflow.json')),before);
end
function [w,root,cleanup]=fixture()
root=string(tempname);inkprof.createProject(root,Name="Remeasure fixture");cleanup=onCleanup(@()rmdir(root,'s'));
w=inkprof.ProjectWorkflow(root);state=w.State;
pkg=fullfile(root,'refinement');inkprof.createTarget(pkg,PatchCount=20,GraySteps=3,DPI=100);
for name=["old-profile.icc","new-profile.icc"]
 f=fopen(fullfile(root,name),'w');fprintf(f,'fixture %s',name);fclose(f);
end
proposal=struct('sourceProfileSHA256',inkprof.internal.sha256(fullfile(root,'old-profile.icc')));
inkprof.internal.writeJson(fullfile(root,'proposal.json'),proposal);
ids=["definition","render","measurement","review","input","recipe","profile","checks","refine"];
events={};
for id=ids
 result=struct('status',"completed",'outputs',struct('file',"old-profile.icc"), ...
  'artifacts',struct('path',"old-profile.icc",'sha256',inkprof.internal.sha256(fullfile(root,'old-profile.icc'))),'message',"Complete");
 if id=="profile",result.outputs=struct('profile',"old-profile.icc");end
 if id=="refine"
  result.outputs=struct('proposal',"proposal.json",'target',"refinement/target.ti2");result.method="gamut";
  result.artifacts(end+1)=struct('path',"proposal.json",'sha256',inkprof.internal.sha256(fullfile(root,'proposal.json')));
 end
 state.steps.(id)=result;
 events{end+1}=struct('step',id,'status',"completed",'cycle',state.cycle,'iterationId',state.iterationId, ...
  'details',struct('result',result),'utc',"2026-10-09T18:00:00Z");
end
state.history=events;
for id=ids,state.steps.(id).status="stale";end
state.steps.measurement.status="completed";
state.steps.profile.status="completed";state.steps.profile.outputs.profile="new-profile.icc";
inkprof.internal.writeJson(fullfile(root,'workflow.json'),state);inkprof.updateProject(root,Step="test-state");w.reload();
end
