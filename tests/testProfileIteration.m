function tests=testProfileIteration
tests=functiontests(localfunctions);
end
function testRoleIdentityAndExclusions(tc)
w=string(tempname);mkdir(w);c=onCleanup(@()rmdir(w,'s'));
m=struct('data',struct('ids',string((1:11)'),'rgb',repmat((1:11)',1,3)));
patches=struct('sampleId',{},'rgbPercent',{},'role',{});for k=1:11,patches(k)=struct('sampleId',string(k),'rgbPercent',[k k k],'role',"fit");end
patches(9).role="adaptive_holdout";patches(10).role="control";patches(11).role="final_holdout";
mf=fullfile(w,'measurement.json');rf=fullfile(w,'roles.json');
inkprof.internal.writeJson(mf,m);inkprof.internal.writeJson(rf,struct('patches',patches));
[fit,dev,r]=inkprof.internal.iterationRoles(mf,rf);
verifyEqual(tc,fit,string((1:8)'));verifyEqual(tc,dev,"9");verifyEqual(tc,string(r.excludedIds),["10";"11"]);
one=patches;for k=2:8,one(k).role="control";end
inkprof.internal.writeJson(rf,struct('patches',one));[fit,~,~]=inkprof.internal.iterationRoles(mf,rf);verifyEqual(tc,fit,"1");
patches(3).rgbPercent=[90 90 90];inkprof.internal.writeJson(rf,struct('patches',patches));
verifyError(tc,@()inkprof.internal.iterationRoles(mf,rf),'inkprof:IterationRoles');
end
function testRegressionGuard(tc)
a=proposal([2 2 2],2);b=proposal([3 0.5 0.5],1.5);
r=inkprof.internal.selectIterationCandidate({a,b},.01,.5,.25);
verifyEqual(tc,r.selected,1);verifyEqual(tc,r.decisions{2}.worstPatchRegression,1);
c=proposal([1.8 1.5 1.5],1.6);r=inkprof.internal.selectIterationCandidate({a,c},.01,.5,.25);verifyEqual(tc,r.selected,2);
end
function testGrayGuard(tc)
a=proposal([1 3 3],2.5);b=proposal([1.4 1 1],1.2);
r=inkprof.internal.selectIterationCandidate({a,b},.01,.5,.25);verifyEqual(tc,r.selected,1);
end
function testIdentityMismatch(tc)
a=proposal([2 2 2],2);b=a;b.evaluatedPatches(2).sampleId="other";
verifyError(tc,@()inkprof.internal.selectIterationCandidate({a,b},.01,.5,.25),'inkprof:IterationIdentity');
end
function p=proposal(errors,norm)
patches=struct('sampleId',{},'rgbPercent',{},'deltaE00',{});rgb=[50 50 50;20 50 80;80 50 20];
for k=1:3,patches(k)=struct('sampleId',string(k),'rgbPercent',rgb(k,:),'deltaE00',errors(k));end
p=jsondecode(jsonencode(struct('evaluatedPatches',patches,'errorNorm',struct('value',norm))));
end

function testCompositeMappingAndTamper(tc)
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
a=fullfile(w,'a');b=fullfile(w,'b');mockInput(a);mockInput(b);
out=inkprof.internal.combineProfileInputs([a;b],fullfile(w,'combined'),"Combined");
r=jsondecode(fileread(fullfile(out,'profile-input.json')));verifyEqual(tc,r.patchCount,16);
v=inkprof.cgatsData(inkprof.importCgats(fullfile(out,'profiling.ti3')),RGBScale=100);
verifyEqual(tc,numel(unique(v.ids)),16);verifyEqual(tc,v.rgb(1:8,:),v.rgb(9:16,:));
m=jsondecode(fileread(fullfile(out,'measurement.json')));
verifyEqual(tc,string(m.documentType),"inkprof.profile-training-set");verifyEqual(tc,m.mapping(9).sourceInput,2);
verifyEqual(tc,string(m.mapping(9).sourceId),"1");
f=fopen(fullfile(a,'profiling.ti3'),'a');fprintf(f,' ');fclose(f);
verifyError(tc,@()inkprof.internal.combineProfileInputs([a;b],fullfile(w,'bad'),"Bad"),'inkprof:Integrity');
end
function mockInput(folder)
mkdir(folder);t=struct('signature',"CTI3",'fields',["SAMPLE_ID","SAMPLE_LOC","RGB_R","RGB_G","RGB_B","XYZ_X","XYZ_Y","XYZ_Z"], ...
 'data',[string((1:8)'),"A"+string((1:8)'),string(repmat((1:8)',1,6))],'metadata',{{["COLOR_REP","RGB_XYZ"]}});
inkprof.exportCgats(fullfile(folder,'profiling.ti3'),struct('documentType',"inkprof.cgats",'tables',t));
copyfile(fullfile(folder,'profiling.ti3'),fullfile(folder,'source.ti3'));
inkprof.internal.writeJson(fullfile(folder,'measurement.json'),struct('test',true));
inkprof.internal.writeJson(fullfile(folder,'chart.json'),struct('test',true));
r=struct('schemaVersion',1,'documentType',"inkprof.profile-input",'status',"locked-input-not-profiled", ...
 'patchCount',8,'sourceDataRows',(1:8)','measurementCondition',struct('interpreted',"M0"));
for entry={"measurement.json","measurementSHA256";"chart.json","chartJSONSHA256";"source.ti3","sourceTI3SHA256";"profiling.ti3","profilingTI3SHA256"}'
 r.(entry{2})=inkprof.internal.sha256(fullfile(folder,entry{1}));
end
inkprof.internal.writeJson(fullfile(folder,'profile-input.json'),r);
end

function testNextPrintRoles(tc)
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));job=fullfile(w,'job');mockInput(job);
copyfile(fullfile(job,'profiling.ti3'),fullfile(job,'engine.ti3'));mkdir(fullfile(job,'result'));
f=fopen(fullfile(job,'result','profile.icc'),'w');fprintf(f,'hash-only fixture');fclose(f);
cs=cell(20,1);for k=1:20,cs{k}=struct('rgbPercent',[10+k 20+k 30+k]);end
p=jsondecode(jsonencode(struct('candidates',{cs},'iterationId',"test")));
info=inkprof.internal.createRefinementPrint(p,job,fullfile(w,'print'),100,"A4-landscape",42);
plan=jsondecode(fileread(info.roleFile));verifyEqual(tc,plan.fitCount,16);verifyEqual(tc,plan.adaptiveHoldoutCount,4);
verifyEqual(tc,plan.controlOccurrences,16);verifyEqual(tc,info.totalSourcePatches,36);
verifyTrue(tc,isfile(info.ti2));verifyFalse(tc,info.profileApplied);
roles=string({plan.patches.role});verifyEqual(tc,sum(roles=="control"),16);
verifyEqual(tc,numel(unique(string({plan.patches.sampleId}))),36);
end
