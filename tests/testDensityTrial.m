% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testDensityTrial
tests=functiontests(localfunctions);
end
function setupOnce(~),addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));end
function testPreparedTrialPreservesValuesAndOriginal(tc)
[p,job,report,input]=fixture();c=onCleanup(@()rmdir(p,'s')); %#ok<NASGU>
old=inkprof.internal.sha256(fullfile(input,'profiling.ti3'));profile=inkprof.internal.sha256(fullfile(job,'result','profile.icc'));
[result,folder]=inkprof.buildDensityTrial(job,report,RunBuild=false);
verifyEqual(tc,result.status,"prepared-not-built");verifyFalse(tc,result.automaticallySelected);
a=inkprof.importCgats(fullfile(input,'profiling.ti3'));b=inkprof.importCgats(fullfile(folder,'input','profiling.ti3'));
verifyEqual(tc,b.tables.data,a.tables.data(1:8,:));
verifyEqual(tc,inkprof.internal.sha256(fullfile(input,'profiling.ti3')),old);
verifyEqual(tc,inkprof.internal.sha256(fullfile(job,'result','profile.icc')),profile);
verifyEqual(tc,inkprof.internal.sha256(fullfile(folder,'original-input','profiling.ti3')),old);
r=jsondecode(fileread(fullfile(folder,'input','profile-input.json')));verifyEqual(tc,r.patchCount,8);verifyEqual(tc,r.sourceDataRows,(1:8)');
end
function testComparisonWindowShowsCommonFitAndGradients(tc)
p=struct('sampleId',"1",'originalDeltaE00',1,'trialDeltaE00',1.2,'changeDeltaE00',.2);
a=struct('count',12,'originalMean',1,'trialMean',1.2,'worstRegression',.2);
g=struct('key',"neutral",'curvatureP95',.1,'lightnessReversals',0);
r=struct('commonFit',struct('all',a,'patches',p),'development',struct('available',false), ...
 'gradients',struct('originalMetrics',g,'candidateMetrics',g));
inkprof.internal.showDensityTrial(r,"temporary test only");
f=findall(groot,'Name','InkProf - Balanced density candidate comparison');c=onCleanup(@()delete(f)); %#ok<NASGU>
verifyEqual(tc,numel(f),1);verifyEqual(tc,numel(findall(f,'Type','uitable')),2);
end
function testChangedDensitySourceRejected(tc)
[p,job,report,~]=fixture();c=onCleanup(@()rmdir(p,'s')); %#ok<NASGU>
r=jsondecode(fileread(report));r.sourceTI3SHA256="changed";inkprof.internal.writeJson(report,r);
verifyError(tc,@()inkprof.buildDensityTrial(job,report,RunBuild=false),'inkprof:Integrity');
end
function [p,job,report,input]=fixture()
p=string(tempname);inkprof.createProject(p);input=fullfile(p,'profiles','inputs','fixture');mkdir(input);
fields=["SAMPLE_ID","SAMPLE_LOC","RGB_R","RGB_G","RGB_B","XYZ_X","XYZ_Y","XYZ_Z"];
ids=string((1:12)');rgb=[(10:21)',(30:41)',(50:61)'];data=[ids,"A"+ids,string(rgb),string(repmat([20 30 40],12,1))];
doc=struct('documentType',"inkprof.cgats",'tables',struct('signature',"CTI3",'fields',fields,'data',data,'metadata',{{["COLOR_REP","RGB_XYZ"]}}));
inkprof.exportCgats(fullfile(input,'profiling.ti3'),doc);copyfile(fullfile(input,'profiling.ti3'),fullfile(input,'source.ti3'));
inkprof.internal.writeJson(fullfile(input,'measurement.json'),struct('fixture',true));inkprof.internal.writeJson(fullfile(input,'chart.json'),struct('fixture',true));
r=struct('name',"Fixture",'patchCount',12,'sourceDataRows',(1:12)', ...
 'measurementSHA256',inkprof.internal.sha256(fullfile(input,'measurement.json')),'chartJSONSHA256',inkprof.internal.sha256(fullfile(input,'chart.json')), ...
 'sourceTI3SHA256',inkprof.internal.sha256(fullfile(input,'source.ti3')),'profilingTI3SHA256',inkprof.internal.sha256(fullfile(input,'profiling.ti3')));
inkprof.internal.writeJson(fullfile(input,'profile-input.json'),r);
job=fullfile(p,'profiles','jobs','fixture');mkdir(fullfile(job,'result'));copyfile(fullfile(input,'profiling.ti3'),fullfile(job,'engine.ti3'));
inkprof.internal.writeJson(fullfile(job,'result','profile.icc'),struct('fixture',true));
recipe=struct('inputSHA256',inkprof.internal.sha256(fullfile(input,'profile-input.json')),'profilingTI3SHA256',r.profilingTI3SHA256,'patchCount',12);
inkprof.internal.writeJson(fullfile(job,'recipe.json'),recipe);
sha=inkprof.internal.sha256(fullfile(job,'result','profile.icc'));status=struct('status',"succeeded",'profileSHA256',sha,'recipeSHA256',inkprof.internal.sha256(fullfile(job,'recipe.json')),'engineTI3SHA256',inkprof.internal.sha256(fullfile(job,'engine.ti3')));
inkprof.internal.writeJson(fullfile(job,'status.json'),status);
patches=repmat(struct('sampleId',"",'sampleLoc',"",'rgbPercent',[0 0 0]),12,1);
for k=1:12,patches(k).sampleId=ids(k);patches(k).sampleLoc="A"+ids(k);patches(k).rgbPercent=rgb(k,:);end
fitFile=fullfile(job,'fit.json');inkprof.internal.writeJson(fitFile,struct('patches',patches));
report=fullfile(job,'density.json');inkprof.internal.writeJson(report,struct('documentType',"inkprof.measurement-density",'profileSHA256',sha, ...
 'sourceTI3SHA256',status.engineTI3SHA256,'fitReport',fitFile,'fitReportSHA256',inkprof.internal.sha256(fitFile),'selectedRows',(1:8)', ...
 'parameters',struct('labRadiusDeltaE76',1,'targetPerGroup',4)));
end
