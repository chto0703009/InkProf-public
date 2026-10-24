% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testUnicodePaths
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testNamesPathsAndJson(tc)
base=string(tempname);mkdir(base);cleanup=onCleanup(@()rmdir(base,'s'));
names=["åäö ÅÄÖ ü Ü","u"+string(char(776))+" U"+string(char(776))];
for name=names
    verifyEqual(tc,inkprof.internal.projectFolderName(name),name);
    root=fullfile(base,name);mkdir(root);folder=fullfile(root,"Mätning Ü");mkdir(folder);
    file=fullfile(folder,"åäö.json");inkprof.internal.writeJson(file,struct('name',name));
    verifyEqual(tc,inkprof.internal.relativePath(root,file),"Mätning Ü/åäö.json");
    saved=jsondecode(fileread(file));verifyEqual(tc,string(saved.name),name);
    verifyError(tc,@()inkprof.internal.relativePath(root,fullfile(base,'outside.json')),'inkprof:WorkflowPath');
end
end
function testUnicodePackageCopy(tc)
base=string(tempname);mkdir(base);cleanup=onCleanup(@()rmdir(base,'s'));
source=fullfile(base,"åäö ÅÄÖ u"+string(char(776))+" Ü");mkdir(source);
mkdir(fullfile(source,"Mätning"));file=fullfile(source,"Mätning","Ü.txt");
writelines("Original åäö ü",file);
copy=inkprof.internal.copyTargetPackage(source,base);
verifyEqual(tc,inkprof.internal.sha256(fullfile(copy,"Mätning","Ü.txt")),inkprof.internal.sha256(file));
end
