% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testProjectFolderName
tests=functiontests(localfunctions);
end
function setup(tc)
p=string(tempname);mkdir(p);tc.TestData.parent=p;
root=inkprof.createProject(fullfile(p,'Original'),User="Alice");
tc.TestData.w=inkprof.ProjectWorkflow(root);
end
function teardown(tc)
rmdir(tc.TestData.parent,'s');
end
function w=externalRename(tc)
old=tc.TestData.w.Root;dest=fullfile(tc.TestData.parent,'New name');movefile(old,dest);
w=inkprof.ProjectWorkflow(dest);
end
function testAcceptAndRecord(tc)
w=externalRename(tc);s=inkprof.internal.projectFolderStatus(w.Root);verifyTrue(tc,s.changed);
r=w.reconcileFolderName("accept");
verifyEqual(tc,string(r.name),"New name");verifyEqual(tc,string(r.folderName),"New name");
verifyEqual(tc,string(r.projectId),string(w.State.projectId));
verifyEqual(tc,string(r.folderNameHistory(end).action),"accept");
verifyEqual(tc,string(r.folderNameHistory(end).previousProjectName),"Original");
verifyFalse(tc,inkprof.internal.projectFolderStatus(w.Root).changed);
verifyTrue(tc,inkprof.verifyProject(w.Root).passed);
fresh=inkprof.ProjectWorkflow(w.Root);verifyTrue(tc,contains(jsonencode(fresh.State.history),'folder-name'));
end
function testRestore(tc)
w=externalRename(tc);r=w.reconcileFolderName("restore");
verifyEqual(tc,w.Root,inkprof.internal.absolutePath(fullfile(tc.TestData.parent,'Original')));
verifyFalse(tc,isfolder(fullfile(tc.TestData.parent,'New name')));
verifyEqual(tc,string(r.name),"Original");verifyEqual(tc,string(r.folderNameHistory(end).action),"restore");
verifyTrue(tc,inkprof.verifyProject(w.Root).passed);
verifyFalse(tc,isfile(fullfile(w.Root,'.workflow.lock')));
end
function testCancelRemainsDetectable(tc)
w=externalRename(tc);r=w.reconcileFolderName("cancel");
verifyEqual(tc,string(r.name),"Original");verifyTrue(tc,inkprof.internal.projectFolderStatus(w.Root).changed);
verifyEqual(tc,string(r.folderNameHistory(end).status),"cancelled");
verifyTrue(tc,inkprof.verifyProject(w.Root).passed);
r=w.reconcileFolderName("accept");verifyEqual(tc,numel(r.folderNameHistory),2);
end
function testRestoreCollisionRecorded(tc)
w=externalRename(tc);occupied=fullfile(tc.TestData.parent,'Original');mkdir(occupied);
verifyError(tc,@()w.reconcileFolderName("restore"),'inkprof:Exists');
r=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
verifyEqual(tc,string(r.folderNameHistory(end).status),"failed");verifyTrue(tc,isfolder(occupied));
verifyTrue(tc,inkprof.verifyProject(w.Root).passed);
end
function testDifferentParentIsNotRename(tc)
w=tc.TestData.w;destination=fullfile(tc.TestData.parent,'Another computer');mkdir(destination);
movefile(w.Root,fullfile(destination,'Original'));
s=inkprof.internal.projectFolderStatus(fullfile(destination,'Original'));verifyFalse(tc,s.changed);
end
function testLegacyFallback(tc)
w=tc.TestData.w;r=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));r=rmfield(r,'folderName');
inkprof.internal.writeJson(fullfile(w.Root,'inkprof-project.json'),r);
verifyFalse(tc,inkprof.internal.projectFolderStatus(w.Root).changed);
w=externalRename(tc);verifyTrue(tc,inkprof.internal.projectFolderStatus(w.Root).changed);
end
