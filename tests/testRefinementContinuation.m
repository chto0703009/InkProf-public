function tests=testRefinementContinuation
tests=functiontests(localfunctions);
end
function testPlanAndPrepareOnly(tc)
[w,f,m]=fixture();c=onCleanup(@()rmdir(w,'s'));
p=inkprof.internal.refinementContinuationPlan(f,m);
verifyEqual(tc,p.expectedTrainingCount,16);verifyEqual(tc,p.newFitCount,8);
verifyEqual(tc,p.developmentCount,2);verifyEqual(tc,p.controlCount,2);
[folder,r]=inkprof.continueRefinement(f,m,PrepareOnly=true);
verifyEqual(tc,r.status,"validated");verifyTrue(tc,isfile(fullfile(folder,'continuation.json')));
verifyFalse(tc,isfield(r,'profileFile'));
end
function testRejectMismatch(tc)
for kind=["position","rgb","condition","incomplete","roles"]
 [w,f,m]=fixture();c=onCleanup(@()rmdir(w,'s'));r=jsondecode(fileread(m));
 switch kind
  case 'position',r.data.locations{1}='wrong';
  case 'rgb',r.data.rgb(1,1)=99;
  case 'condition',r.measurementCondition.interpreted="M1";
  case 'incomplete',r.complete=false;
  case 'roles'
   role=fullfile(f,'refinement-print','placement-plan.json');q=jsondecode(fileread(role));q.patches(5).role="fit";inkprof.internal.writeJson(role,q);
 end
 inkprof.internal.writeJson(m,r);
 try,inkprof.internal.refinementContinuationPlan(f,m);caught=false;catch,caught=true;end
 verifyTrue(tc,caught,kind);clear c
end
end
function [w,f,m]=fixture()
w=string(tempname);mkdir(w);inkprof.internal.writeJson(fullfile(w,'inkprof-project.json'),struct('test',true));
b=fullfile(w,'profiles','training');mkdir(b);job=fullfile(w,'profiles','jobs','parent');mkdir(job);mkdir(fullfile(job,'result'));
t=struct('signature',"CTI3",'fields',["SAMPLE_ID","SAMPLE_LOC","RGB_R","RGB_G","RGB_B","XYZ_X","XYZ_Y","XYZ_Z"], ...
 'data',[string((1:8)'),"A"+string((1:8)'),string(repmat((1:8)',1,6))],'metadata',{{["COLOR_REP","RGB_XYZ"]}});
inkprof.exportCgats(fullfile(b,'profiling.ti3'),struct('documentType',"inkprof.cgats",'tables',t));
copyfile(fullfile(b,'profiling.ti3'),fullfile(b,'source.ti3'));
inkprof.internal.writeJson(fullfile(b,'measurement.json'),struct('test',true));inkprof.internal.writeJson(fullfile(b,'chart.json'),struct('test',true));
r=struct('patchCount',8,'measurementCondition',struct('interpreted',"M0"));
for pair={"measurement.json","measurementSHA256";"chart.json","chartJSONSHA256";"source.ti3","sourceTI3SHA256";"profiling.ti3","profilingTI3SHA256"}'
 r.(pair{2})=inkprof.internal.sha256(fullfile(b,pair{1}));
end
inkprof.internal.writeJson(fullfile(b,'profile-input.json'),r);
recipe=struct('inputSHA256',inkprof.internal.sha256(fullfile(b,'profile-input.json')),'profilingTI3SHA256',r.profilingTI3SHA256);
inkprof.internal.writeJson(fullfile(job,'recipe.json'),recipe);
inkprof.internal.writeJson(fullfile(job,'result','profile.icc'),struct('syntheticTestOnly',true));
copyfile(fullfile(b,'profiling.ti3'),fullfile(job,'engine.ti3'));
s=struct('status',"succeeded",'recipeSHA256',inkprof.internal.sha256(fullfile(job,'recipe.json')),'profileSHA256',inkprof.internal.sha256(fullfile(job,'result','profile.icc')));
inkprof.internal.writeJson(fullfile(job,'status.json'),s);
f=fullfile(w,'proposal');mkdir(f);mkdir(fullfile(f,'sources'));mkdir(fullfile(f,'refinement-print'));mkdir(fullfile(f,'refinement-print','print'));
copyfile(fullfile(job,'result','profile.icc'),fullfile(f,'sources','profile.icc'));copyfile(fullfile(job,'engine.ti3'),fullfile(f,'sources','training.ti3'));
inkprof.internal.writeJson(fullfile(f,'sources','context.json'),struct('profileJob',"profiles/jobs/parent"));
candidates=struct('rgbPercent',{});patches=struct('definitionId',{},'sampleId',{},'rgbPercent',{},'role',{},'placement',{});
for k=1:12
 rgb=repmat(k+20,1,3);role="fit";
 if k<=10,candidates(k).rgbPercent=rgb;if mod(k,5)==0,role="adaptive_holdout";end
 else,rgb=[1 1 1];role="control";end
 patches(k)=struct('definitionId',string(k),'sampleId',string(k),'rgbPercent',rgb,'role',role,'placement',struct('location',"A"+k));
end
inkprof.internal.writeJson(fullfile(f,'proposal.json'),struct('documentType',"inkprof.verification-refinement",'iterationId',"test",'candidates',candidates,'print',struct()));
inkprof.internal.writeJson(fullfile(f,'refinement-print','placement-plan.json'),struct('patches',patches,'rolesFrozenBeforeMeasurement',true,'profileApplied',false,'sourceProfileSHA256',s.profileSHA256));
inkprof.internal.writeJson(fullfile(f,'refinement-print','print','target.ti2'),struct('syntheticTestOnly',true));
m=fullfile(w,'new-measurement.json');inkprof.internal.writeJson(fullfile(w,'new-measurement.ti3'),struct('syntheticTestOnly',true));
inkprof.internal.writeJson(m,struct('complete',true,'measurementCondition',struct('interpreted',"M0"), ...
 'sourceTI3SHA256',inkprof.internal.sha256(fullfile(w,'new-measurement.ti3')), ...
 'data',struct('ids',string((1:12)'),'locations',"A"+string((1:12)'),'rgb',reshape([patches.rgbPercent],3,[])')));
end
