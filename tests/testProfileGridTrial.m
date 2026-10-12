% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testProfileGridTrial
tests=functiontests(localfunctions);
end
function testClonePreservesMeasurementRecipeAndOriginal(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
root=string(tempname);mkdir(root);cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
project=inkprof.createProject(fullfile(root,'project'));
b1=fullfile(project,'profiles','inputs','fixture');mkdir(b1);
inkprof.internal.writeJson(fullfile(b1,'profile-input.json'),struct('fixture',1));
job=fullfile(project,'profiles','jobs','source');mkdir(fullfile(job,'result'));
fid=fopen(fullfile(job,'result','profile.icc'),'w');fprintf(fid,'test source ICC');fclose(fid);
recipe=struct('schemaVersion',1,'documentType',"inkprof.profile-recipe",'inputSHA256',inkprof.internal.sha256(fullfile(b1,'profile-input.json')), ...
 'inputFile',"../../profile-input.json",'description',"Original",'engine',struct('quality',"medium",'b2aQuality',"high",'smoothing',0.5, ...
 'plannedArguments',["-qm","-al","-r","0.5","-bh","-s","20","-D","Original"], ...
 'preRegularization',struct('enabled',true,'plannedArguments',["-qm","-al","-bn","-r","0.5"])));
inkprof.internal.writeJson(fullfile(job,'recipe.json'),recipe);
status=struct('status',"succeeded",'recipeSHA256',inkprof.internal.sha256(fullfile(job,'recipe.json')),'profileSHA256',inkprof.internal.sha256(fullfile(job,'result','profile.icc')));
inkprof.internal.writeJson(fullfile(job,'status.json'),status);
[r,folder]=inkprof.rebuildProfileGrid(b1,job,RunBuild=false);
new=jsondecode(fileread(r.recipe));verifyEqual(tc,string(new.engine.quality),"medium");verifyEqual(tc,string(new.engine.b2aQuality),"ultra");
verifyTrue(tc,any(string(new.engine.plannedArguments)=="-bu"));verifyEqual(tc,new.engine.smoothing,.5);
verifyEqual(tc,string(new.engine.preRegularization.plannedArguments),string(recipe.engine.preRegularization.plannedArguments(:)));
verifyEqual(tc,inkprof.internal.sha256(fullfile(job,'recipe.json')),status.recipeSHA256);
verifyEqual(tc,new.inputSHA256,char(recipe.inputSHA256));verifyTrue(tc,isfile(fullfile(folder,'grid-trial.json')));
[r,~]=inkprof.rebuildProfileGrid(b1,job,Tables="both",RunBuild=false);
new=jsondecode(fileread(r.recipe));verifyEqual(tc,string(new.engine.quality),"ultra");
verifyTrue(tc,any(string(new.engine.plannedArguments)=="-qu"));
verifyTrue(tc,any(string(new.engine.preRegularization.plannedArguments)=="-qu"));
verifyError(tc,@()inkprof.rebuildProfileGrid(b1,job,Quality="high",RunBuild=false),'inkprof:GridTrial');
inkprof.internal.writeJson(fullfile(b1,'profile-input.json'),struct('fixture',2));
verifyError(tc,@()inkprof.rebuildProfileGrid(b1,job,RunBuild=false),'inkprof:Integrity');
end
