% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function destination=moveProjectFolder(source,destination)
% Explicit sibling rename only: no replacement, deletion or Trash operation.
source=inkprof.internal.absolutePath(source);
destination=inkprof.internal.absolutePath(destination);
assert(fileparts(source)==fileparts(destination),'inkprof:ProjectMove','A project rename must stay in the same parent folder.');
assert(~any(ismember(split(replace(source,"\","/"),"/"),[".Trash",".Trashes"]))&& ...
 ~any(ismember(split(replace(destination,"\","/"),"/"),[".Trash",".Trashes"])), ...
 'inkprof:ProjectMove','Restore the project from Trash before opening or renaming it.');
assert(isfile(fullfile(source,'inkprof-project.json')),'inkprof:ProjectMove','Original project is missing.');
assert(~isfolder(destination)&&~isfile(destination),'inkprof:Exists','Rename destination already exists. Nothing was overwritten.');
names=["inkprof-project.json","workflow.json"];hashes=strings(size(names));
for k=1:numel(names)
 if isfile(fullfile(source,names(k))),hashes(k)=inkprof.internal.sha256(fullfile(source,names(k)));end
end
java.nio.file.Files.move(java.io.File(char(source)).toPath(),java.io.File(char(destination)).toPath(),javaArray('java.nio.file.CopyOption',0));
try
 for k=1:numel(names)
  if hashes(k)~=""
   assert(isfile(fullfile(destination,names(k)))&&inkprof.internal.sha256(fullfile(destination,names(k)))==hashes(k), ...
    'inkprof:Integrity','Project identity changed during rename.');
  end
 end
catch err
 % Roll back by rename only. Never delete either location during recovery.
 if ~isfolder(source)&&~isfile(source)&&isfolder(destination)
  java.nio.file.Files.move(java.io.File(char(destination)).toPath(),java.io.File(char(source)).toPath(),javaArray('java.nio.file.CopyOption',0));
 end
 rethrow(err)
end
end
