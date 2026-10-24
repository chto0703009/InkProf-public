% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testPrintDeliveryIdentity
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testReadableNameAndPreservedPreviousCopy(tc)
parent=string(tempname);mkdir(parent);clean=onCleanup(@()rmdir(parent,'s'));
name="My paper Åäö";first=inkprof.internal.printDeliveryFolder(parent,name,2,"c2");
writelines('Keep this delivery',fullfile(first,'keep.txt'));
second=inkprof.internal.printDeliveryFolder(parent,name,2,"c2");
verifyNotEqual(tc,first,second);[~,stem]=fileparts(first);verifyTrue(tc,startsWith(string(stem),name+"_iter-2_c2_"));
verifyEqual(tc,strtrim(string(fileread(fullfile(first,'keep.txt')))),"Keep this delivery");
end
function testExactProjectAndSeparateOriginCycle(tc)
root=string(tempname);mkdir(root);clean=onCleanup(@()rmdir(root,'s'));destination=fullfile(root,'copy');mkdir(destination);
target=fullfile(root,'target.ti2');writelines('Fixture',target);
inkprof.internal.writeJson(fullfile(root,'manifest.json'),struct('createdUTC','2026-10-16T11:16:55Z','pageCount',1));
project=struct('name','Exact project Åäö','projectId','project-id','printing',struct('paper','Photo paper','dryingHours',24));
e=struct('step','c2','status','completed','cycle',1,'iterationId','first-iteration','details',struct('result',struct('outputs',struct('target','target.ti2'))));
state=struct('cycle',3,'iterationId','third-iteration','history',{{e}});
files=struct('name','target.tif','sha256','test-hash');
r=inkprof.internal.writePrintDeliveryInfo(destination,project,root,state,"c2",target,files,"Print at 100%.");
verifyEqual(tc,r.iteration,3);verifyEqual(tc,r.targetIteration,"1");verifyEqual(tc,r.targetIterationId,"first-iteration");
text=string(fileread(fullfile(destination,'PROJECT_INFO.txt')));
verifyTrue(tc,contains(text,'Project name (exact): Exact project Åäö'));
verifyTrue(tc,contains(text,'Target package created (UTC): 2026-10-16T11:16:55Z'));
verifyTrue(tc,contains(text,'target.tif | test-hash'));verifyTrue(tc,contains(text,'dryingHours'));
verifyTrue(tc,contains(text,'Target package created (local):'));
end
function testWholePackageCopyIncludesProjectIdentity(tc)
parent=string(tempname);mkdir(parent);clean=onCleanup(@()rmdir(parent,'s'));
root=fullfile(parent,'Project paper');inkprof.createProject(root);
source=fullfile(root,'targets','package');mkdir(source);
target=fullfile(source,'target.ti2');writelines('Synthetic unchanged target',target);
before=inkprof.internal.sha256(target);
inkprof.internal.writeJson(fullfile(source,'manifest.json'),struct('createdUTC','2026-10-16T11:16:55Z','pageCount',1));
destination=inkprof.internal.copyTargetPackage(source,parent);
verifyTrue(tc,isfile(fullfile(destination,'PROJECT_INFO.txt')));
project=jsondecode(fileread(fullfile(root,'inkprof-project.json')));
[~,name]=fileparts(destination);verifyTrue(tc,startsWith(string(name),string(project.name)+"_iter-unknown_print_"));
verifyEqual(tc,inkprof.internal.sha256(fullfile(destination,'target.ti2')),before);
verifyEqual(tc,inkprof.internal.sha256(target),before);
end
function testCopyFailurePreservesOriginalProject(tc)
parent=string(tempname);mkdir(parent);clean=onCleanup(@()rmdir(parent,'s'));
root=fullfile(parent,'Original ü');inkprof.createProject(root);
source=fullfile(root,'targets','package');mkdir(source);
target=fullfile(source,'target.ti2');writelines('Original immutable content',target);
measurement=fullfile(root,'measurements','raw.ti3');writelines('Original measurement bytes',measurement);
inkprof.updateProject(root,Step="test-data");
before=inkprof.internal.sha256(measurement);manifestHash=inkprof.internal.sha256(fullfile(root,'inkprof-project.json'));
verifyError(tc,@()inkprof.internal.copyTargetPackage(source,parent,Activity=@failCopy),'inkprof:TestCopyFailure');
verifyEqual(tc,inkprof.internal.sha256(measurement),before);
verifyEqual(tc,inkprof.internal.sha256(fullfile(root,'inkprof-project.json')),manifestHash);
verifyTrue(tc,isfile(target));verifyTrue(tc,inkprof.verifyProject(root).passed);
verifyError(tc,@()inkprof.internal.copyTargetPackage(root,parent),'inkprof:PrintCopy');
verifyError(tc,@()inkprof.internal.copyTargetPackage(source,root),'inkprof:PrintCopy');
end
function failCopy(~)
error('inkprof:TestCopyFailure','Simulated failure: preserve original.');
end
