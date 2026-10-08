% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function tests=testRegularizationReport
tests=functiontests(localfunctions);
end
function testSavedMethodAndResult(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
f=string(tempname);mkdir(f);clean=onCleanup(@()rmdir(f,'s'));
pre=struct('method','argyll-colprof-a2b-resample','avgdev',.5);
r=struct('patchCount',2000,'engine',struct('preRegularization',pre,'plannedArguments',{{'-v','-r','0.5'}}));
inkprof.internal.writeJson(fullfile(f,'recipe.json'),r);
job=fullfile(f,'status.json');inkprof.internal.writeJson(job,struct('preRegularization',struct('avgdev',.5,'summary',struct('mean',1,'median',.8,'p95',2,'max',3))));
w=struct('output',@(varargin)job);s=inkprof.internal.regularizationReportSummary(w);
verifyEqual(tc,s.parameters.avgdev,.5);verifyTrue(tc,contains(s.summaryText,'avgdev: 0.5'));
status=jsondecode(fileread(job));status.renderingIntents=struct('compressionPercent',20);inkprof.internal.writeJson(job,status);
s=inkprof.internal.regularizationReportSummary(w);verifyTrue(tc,contains(s.summaryText,'Delivered ICC rendering intents'));
verifyEqual(tc,s.renderingIntents.compressionPercent,20);
verifyTrue(tc,contains(s.summaryText,'Model change versus raw measurements'));
verifyTrue(tc,contains(s.summaryText,'Final ICC colprof -r (%): 0.5'));
r.engine=rmfield(r.engine,'preRegularization');inkprof.internal.writeJson(fullfile(f,'recipe.json'),r);
inkprof.internal.writeJson(job,struct('status','completed'));s=inkprof.internal.regularizationReportSummary(w);
verifyTrue(tc,contains(s.summaryText,'Off (no preprocessing)'));
delete(fullfile(f,'recipe.json'));s=inkprof.internal.regularizationReportSummary(w);
verifyTrue(tc,contains(s.summaryText,'unavailable'));
end
function testMatchingGradientEvidence(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
f=string(tempname);mkdir(f);clean=onCleanup(@()rmdir(f,'s'));
mkdir(fullfile(f,'result'));profile=fullfile(f,'result','profile.icc');
fid=fopen(profile,'w');fwrite(fid,'test ICC bytes');fclose(fid);
job=fullfile(f,'status.json');inkprof.internal.writeJson(job,struct('status','succeeded'));
folder=fullfile(f,'checks','gradient');mkdir(folder);
m=struct('interiorTriples',100,'interiorCurvatureP95',12.3,'lightnessReversals',2);
r=struct('profileSHA256',inkprof.internal.sha256(profile),'method','sRGB and Adobe RGB, intent and BPC, float / 16 / 8 bit', ...
 'cmm',struct('name','LittleCMS','version',2170),'samples',1025, ...
 'paths',struct('precision','float','metrics',m),'caveat','Numerical diagnostic, not physical print validation.');
inkprof.internal.writeJson(fullfile(folder,'photo-gradients.json'),r);
w=struct('output',@(varargin)job);s=inkprof.internal.regularizationReportSummary(w);
verifyTrue(tc,isfield(s,'photographicGradients'));
verifyTrue(tc,contains(s.summaryText,'total L* reversals on those paths: 2'));
r.profileSHA256='another-profile';inkprof.internal.writeJson(fullfile(folder,'photo-gradients.json'),r);
s=inkprof.internal.regularizationReportSummary(w);
verifyFalse(tc,isfield(s,'photographicGradients'));
verifyTrue(tc,contains(s.summaryText,'no readable saved report matching this ICC'));
end
