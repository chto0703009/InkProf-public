% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
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
function testImageProposalContinuation(tc)
[w,f,m]=fixture();c=onCleanup(@()rmdir(w,'s'));
r=jsondecode(fileread(fullfile(f,'proposal.json')));r.documentType="inkprof.image-refinement";
inkprof.internal.writeJson(fullfile(f,'proposal.json'),r);
p=inkprof.internal.refinementContinuationPlan(f,m);
verifyEqual(tc,p.newFitCount,8);verifyEqual(tc,p.developmentCount,2);
end
function testGamutProposalContinuation(tc)
[w,f,m]=fixture();c=onCleanup(@()rmdir(w,'s'));
r=jsondecode(fileread(fullfile(f,'proposal.json')));r.documentType="inkprof.gamut-refinement";
inkprof.internal.writeJson(fullfile(f,'proposal.json'),r);
p=inkprof.internal.refinementContinuationPlan(f,m);
verifyEqual(tc,p.newFitCount,8);verifyEqual(tc,p.developmentCount,2);verifyEqual(tc,p.controlCount,2);
end
function testC2IncludedInContinuation(tc)
[w,f,m]=fixture();c=onCleanup(@()rmdir(w,'s'));
file=fullfile(f,'sources','c2.json');profile=fullfile(f,'sources','profile.icc');
inkprof.internal.writeJson(file,struct('printerProfile',struct('sha256',inkprof.internal.sha256(profile)),'patches',struct('deviceRGB16',[65535,0,0],'role',"colour")));
p=jsondecode(fileread(fullfile(f,'proposal.json')));p.verification=struct('file',"sources/c2.json",'sha256',inkprof.internal.sha256(file));
inkprof.internal.writeJson(fullfile(f,'proposal.json'),p);
rolefile=fullfile(f,'refinement-print','placement-plan.json');roles=jsondecode(fileread(rolefile));
q=roles.patches(end);q.definitionId="13";q.sampleId="13";q.rgbPercent=[100;0;0];q.role="fit";q.placement.location="A13";
roles.patches(end+1)=q;inkprof.internal.writeJson(rolefile,roles);
r=jsondecode(fileread(m));r.data.ids(end+1)={char("13")};r.data.locations(end+1)={char("A13")};r.data.rgb(end+1,:)=[100 0 0];inkprof.internal.writeJson(m,r);
p=inkprof.internal.refinementContinuationPlan(f,m);
verifyEqual(tc,p.verificationCount,1);verifyEqual(tc,p.newFitCount,9);verifyTrue(tc,any(p.fitIds=="13"));
% Append one authenticated shadow fitting patch after the C2 subset.
shadowFile=fullfile(f,'refinement-print','shadow-patches.json');
inkprof.internal.writeJson(shadowFile,struct('actualCount',1,'rgbPercent',[2 3 4],'sourceProfileSHA256',inkprof.internal.sha256(profile)));
proposal=jsondecode(fileread(fullfile(f,'proposal.json')));
proposal.print.shadow=struct('file',"refinement-print/shadow-patches.json",'sha256',inkprof.internal.sha256(shadowFile),'count',1);
inkprof.internal.writeJson(fullfile(f,'proposal.json'),proposal);
q.definitionId="14";q.sampleId="14";q.rgbPercent=[2;3;4];q.placement.location="A14";
roles.patches(end+1)=q;inkprof.internal.writeJson(rolefile,roles);
r.data.ids(end+1)={char("14")};r.data.locations(end+1)={char("A14")};r.data.rgb(end+1,:)=[2 3 4];inkprof.internal.writeJson(m,r);
p=inkprof.internal.refinementContinuationPlan(f,m);
verifyEqual(tc,p.newFitCount,10);verifyTrue(tc,any(p.fitIds=="14"));
roles.patches(end).role="final_holdout";inkprof.internal.writeJson(rolefile,roles);
verifyError(tc,@()inkprof.internal.refinementContinuationPlan(f,m),'inkprof:Continuation');
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
