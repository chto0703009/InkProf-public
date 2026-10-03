function tests=testCombinedRefinement
tests=functiontests(localfunctions);
end
function testCombinedPrintKeepsC2PixelsAndRoles(tc)
p=string(tempname);inkprof.createProject(p);c=onCleanup(@()rmdir(p,'s'));
j=fullfile(p,'profiles','jobs','test');mkdir(fullfile(j,'result'));
inkprof.internal.writeJson(fullfile(j,'result','profile.icc'),struct('fixture',true));
t=struct('signature',"CTI3",'fields',["SAMPLE_ID","RGB_R","RGB_G","RGB_B","XYZ_X","XYZ_Y","XYZ_Z"], ...
 'data',["1","0","0","0","0","0","0";"2","100","100","100","96","100","82"],'metadata',{{["COLOR_REP","RGB_XYZ"]}});
inkprof.exportCgats(fullfile(j,'engine.ti3'),struct('documentType',"inkprof.cgats",'tables',t));
source=fullfile(p,'verification','old');mkdir(fullfile(source,'definition'));copyfile(fullfile(j,'result','profile.icc'),fullfile(source,'definition','printer.icc'));
inkprof.internal.writeJson(fullfile(source,'definition','verification.ti1'),struct('fixture',true));
a=struct('id',"1",'role',"colour",'repeatOf',[],'deviceRGB16',[12345 23456 34567],'deviceRGB',[12345 23456 34567]/65535, ...
 'referenceLabD50Absolute',[50 20 -20],'predictedLabD50Absolute',[50 20 -20],'gamutAssessment',"model-reachable",'placement',struct);
b=a;b.id="2";b.role="repeat";b.repeatOf="1";
r=struct('documentType',"inkprof.verification-target",'intent',"absolute colorimetric",'bpc',false,'patches',[a,b], ...
 'printerProfile',struct('file',"definition/printer.icc",'sha256',inkprof.internal.sha256(fullfile(j,'result','profile.icc'))), ...
 'definitions',struct('file',"definition/verification.ti1",'sha256',inkprof.internal.sha256(fullfile(source,'definition','verification.ti1'))), ...
 'trainingTI3SHA256',inkprof.internal.sha256(fullfile(j,'engine.ti3')));
file=fullfile(source,'verification.json');inkprof.internal.writeJson(file,r);
f=fullfile(p,'refinements','new');mkdir(fullfile(f,'sources'));
proposal=struct('iterationId',"test",'candidates',struct('rgbPercent',[10 20 30]));
proposal.verification=inkprof.internal.snapshotVerification(file,j,fullfile(f,'sources','c2'));
info=inkprof.internal.createRefinementPrint(proposal,j,fullfile(f,'refinement-print'),100,"A4-landscape",42,false);
verifyEqual(tc,info.c2TrainingCount,1);verifyEqual(tc,info.newPatchCount,1);verifyEqual(tc,info.verificationPatchCount,2);verifyEqual(tc,info.totalSourcePatches,7);
roles=jsondecode(fileread(info.roleFile));verifyEqual(tc,sum(string({roles.patches.role})=="fit"),2);
combined=jsondecode(fileread(info.verificationReference));verifyEqual(tc,combined.patches(1).deviceRGB16,a.deviceRGB16');
verifyEqual(tc,combined.patches(2).repeatOf,'1');verifyEqual(tc,numel(combined.combinedTarget.otherPatches),5);
verifyEqual(tc,numel(unique(string({roles.patches.sampleId}))),7);
% Rebuild through the workflow; C2 links to the same TIFF and remains unmeasured.
copyfile(fullfile(j,'engine.ti3'),fullfile(f,'sources','training.ti3'));
proposal.documentType="inkprof.image-refinement";proposal.sourceProfileSHA256=r.printerProfile.sha256;
proposal.print=info;
inkprof.internal.writeJson(fullfile(f,'proposal.json'),proposal);
inkprof.internal.writeJson(fullfile(f,'proposed-candidates.json'),proposal.candidates);
inkprof.internal.writeJson(fullfile(f,'sources','context.json'),struct('profileJob',"profiles/jobs/test"));
w=inkprof.ProjectWorkflow(p);state=w.State;
for key=string(fieldnames(state.steps))',state.steps.(key).status="completed";end
state.steps.profile.outputs=struct('job',"profiles/jobs/test/status.json",'profile',"profiles/jobs/test/result/profile.icc",'verification',"verification/old/verification.json");
state.steps.c2.outputs=struct('reference',"verification/old/verification.json");
state.steps.c2measurement.status="pending";
inkprof.internal.writeJson(fullfile(p,'workflow.json'),state);w.reload();
verifyEqual(tc,inkprof.internal.pendingVerification(w),file);
state.steps.c2measurement.status="completed";inkprof.internal.writeJson(fullfile(p,'workflow.json'),state);w.reload();
verifyEqual(tc,inkprof.internal.pendingVerification(w),"");
state.steps.c2measurement.status="pending";inkprof.internal.writeJson(fullfile(p,'workflow.json'),state);w.reload();
w.run('refine',struct('Method',"image",'Confirmed',true,'Notes',"Combined fixture",'ExistingProposal',fullfile(f,'proposal.json'),'IncludeC2',true,'C2Reference',file,'PlanPaper',false));
verifyTrue(tc,w.valid('refine'));verifyTrue(tc,w.valid('c2'));verifyFalse(tc,w.valid('c2measurement'));
verifyEqual(tc,w.State.steps.c2.outputs.target,w.State.steps.refine.outputs.target);
verifyEqual(tc,w.State.steps.c2.outputs.reference,w.State.steps.refine.outputs.c2reference);

end
