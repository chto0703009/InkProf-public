% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testGamutTargetExtension
tests=functiontests(localfunctions);
end
function setupOnce(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testRetainsFitAndDevelopmentAndPreservesParent(tc)
[p,f,icc]=fixture();c=onCleanup(@()rmdir(p,'s')); %#ok<NASGU>
file=fullfile(f,'proposal.json');before=inkprof.internal.sha256(file);
e=inkprof.internal.gamutTargetExtension(p,icc,"");
verifyEqual(tc,e.rgbPercent,[20 30 40;60 70 80]);
verifyEqual(tc,string(e.provenance.parentProposalSHA256),before);
verifyEqual(tc,inkprof.internal.sha256(file),before);
verifyTrue(tc,inkprof.verifyPackage(fullfile(f,'refinement-print','print')).passed);
end
function testSkipsNewerProposalWithoutPrint(tc)
[p,f,icc]=fixture();c=onCleanup(@()rmdir(p,'s')); %#ok<NASGU>
file=fullfile(f,'proposal.json');q=jsondecode(fileread(file));q=rmfield(q,'print');
q.iterationId="newer-unprinted";later=fullfile(p,'refinements','later');mkdir(later);
% File times on some volumes have one-second resolution.
pause(1.1);inkprof.internal.writeJson(fullfile(later,'proposal.json'),q);
verifyEqual(tc,inkprof.internal.latestGamutProposal(p,icc),fullfile(later,'proposal.json'));
e=inkprof.internal.gamutTargetExtension(p,icc,"");
verifyEqual(tc,e.sourceFile,file);verifyEqual(tc,string(e.provenance.parentIterationId),"fixture-parent");
verifyError(tc,@()inkprof.internal.gamutTargetExtension(p,icc,fullfile(later,'proposal.json')),'inkprof:Refinement');
end
function testRejectsStartedMeasurement(tc)
[p,f,icc]=fixture();c=onCleanup(@()rmdir(p,'s')); %#ok<NASGU>
q=jsondecode(fileread(fullfile(f,'proposal.json')));m=fullfile(p,'measurements','partial');mkdir(m);
inkprof.internal.writeJson(fullfile(m,'chart.json'),struct('sourceSHA256',q.print.ti2SHA256));
inkprof.internal.writeJson(fullfile(m,'measurement-1.json'),struct('complete',false,'data',struct('rgb',[20 30 40])));
verifyError(tc,@()inkprof.internal.gamutTargetExtension(p,icc,""),'inkprof:ExtensionMeasured');
end
function testRejectsCheckpointWithoutCompleteRevision(tc)
[p,f,icc]=fixture();c=onCleanup(@()rmdir(p,'s')); %#ok<NASGU>
q=jsondecode(fileread(fullfile(f,'proposal.json')));m=fullfile(p,'measurements','paused');mkdir(m);
inkprof.internal.writeJson(fullfile(m,'chart.json'),struct('sourceSHA256',q.print.ti2SHA256));
inkprof.internal.writeJson(fullfile(m,'measurement-checkpoint.json'),struct('confirmedPasses',1));
verifyError(tc,@()inkprof.internal.gamutTargetExtension(p,icc,""),'inkprof:ExtensionMeasured');
end
function testRejectsChangedTargetAndTraining(tc)
[p,f,icc]=fixture();c=onCleanup(@()rmdir(p,'s')); %#ok<NASGU>
training=fullfile(f,'sources','training.ti3');fid=fopen(training,'a');fprintf(fid,'changed');fclose(fid);
verifyError(tc,@()inkprof.internal.gamutTargetExtension(p,icc,""),'inkprof:Integrity');
end
function [p,f,icc]=fixture()
p=string(tempname);inkprof.createProject(p);
job=fullfile(p,'profiles','jobs','fixture');mkdir(fullfile(job,'result'));
icc=fullfile(job,'result','profile.icc');inkprof.internal.writeJson(icc,struct('fixture',true));
training=fullfile(job,'engine.ti3');inkprof.internal.writeJson(training,struct('fixture','training'));
f=fullfile(p,'refinements','parent');mkdir(fullfile(f,'sources'));
copyfile(icc,fullfile(f,'sources','profile.icc'));copyfile(training,fullfile(f,'sources','training.ti3'));
inkprof.internal.writeJson(fullfile(f,'sources','context.json'),struct('profileJob',"profiles/jobs/fixture",'trainingTI3SHA256',inkprof.internal.sha256(training)));
print=fullfile(f,'refinement-print','print');
% Render a real package; the extension must validate TIFF pixels as well as hashes.
source=fullfile(f,'fixture.ti1');fid=fopen(source,'w');fprintf(fid,'CTI1\nCOLOR_REP "iRGB"\nNUMBER_OF_FIELDS 4\nBEGIN_DATA_FORMAT\nSAMPLE_ID RGB_R RGB_G RGB_B\nEND_DATA_FORMAT\nNUMBER_OF_SETS 3\nBEGIN_DATA\n1 20 30 40\n2 60 70 80\n3 0 0 0\nEND_DATA\n');fclose(fid);
inkprof.createTarget(print,Source=source,DPI=100,Paper="A4-landscape");
patches=struct('sampleId',{'1','2','3'},'rgbPercent',{[20 30 40],[60 70 80],[0 0 0]},'role',{'fit','adaptive_holdout','control'});
role=fullfile(f,'refinement-print','placement-plan.json');inkprof.internal.writeJson(role,struct('patches',patches));
q=struct('documentType',"inkprof.gamut-refinement",'sourceProfileSHA256',inkprof.internal.sha256(icc), ...
 'iterationId',"fixture-parent",'candidates',struct('rgbPercent',[20 30 40]), ...
 'print',struct('ti2SHA256',inkprof.internal.sha256(fullfile(print,'target.ti2')),'roleSHA256',inkprof.internal.sha256(role)));
inkprof.internal.writeJson(fullfile(f,'proposal.json'),q);
end
