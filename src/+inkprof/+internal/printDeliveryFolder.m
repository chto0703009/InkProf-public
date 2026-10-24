% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function folder=printDeliveryFolder(parent,projectName,cycle,step)
%PRINTDELIVERYFOLDER Readable, collision-safe external print folder.
name=inkprof.internal.projectFolderName(projectName);
parent=inkprof.internal.absolutePath(parent);
step=inkprof.internal.projectFolderName(step);
stamp=string(datetime('now','Format','yyyyMMdd-HHmmss'));
base=name+"_iter-"+string(cycle)+"_"+step+"_"+stamp;
folder=fullfile(parent,base);index=1;
while true
 if isfolder(folder)||isfile(folder)
  index=index+1;folder=fullfile(parent,base+"_"+index);continue;
 end
 try
  % Unlike mkdir, fail if another process has already created this folder.
  java.nio.file.Files.createDirectory(java.io.File(char(folder)).toPath(), ...
      javaArray('java.nio.file.attribute.FileAttribute',0));
  break;
 catch err
  if ~isfolder(folder)&&~isfile(folder),rethrow(err);end
 end
end
fid=fopen(fullfile(folder,'PRINT_COPY_ONLY.txt'),'w','n','UTF-8');
assert(fid>=0,'inkprof:PrintCopy','Cannot identify the new print-copy folder.');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',"PRINT COPY ONLY - NOT AN INKPROF PROJECT", ...
 "Keep the original project folder. This folder may be incomplete until copying finishes.", ...
 "See PROJECT_INFO.txt after a successful copy for the original project path.");
end
