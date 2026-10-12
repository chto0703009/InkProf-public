% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function destination=copyTargetPackage(source,parent,options)
arguments
 source (1,1) string
 parent (1,1) string
 options.Activity (1,1) function_handle = @(stage)[]
end
% Copy a complete target without overwriting existing deliveries; verify bytes.
source=inkprof.internal.absolutePath(source);parent=inkprof.internal.absolutePath(parent);
assert(isfolder(source)&&isfolder(parent),'inkprof:PrintCopy','Source and destination folders must exist.');
assert(parent~=source&&~startsWith(parent,source+filesep),'inkprof:PrintCopy','Choose a destination outside the source print package.');
[~,name]=fileparts(source);destination=fullfile(parent,name+"-"+string(java.util.UUID.randomUUID()));
options.Activity("Copying print package");drawnow;
mkdir(destination);
files=dir(fullfile(source,'**','*'));files=files(~[files.isdir]);
for k=1:numel(files)
 original=fullfile(files(k).folder,files(k).name);
 relative=extractAfter(string(original),strlength(source)+1);
 target=fullfile(destination,relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 [ok,msg]=copyfile(original,target);assert(ok,'inkprof:PrintCopy','%s',msg);drawnow;
end
options.Activity("Checking copied files");drawnow;
for k=1:numel(files)
 original=fullfile(files(k).folder,files(k).name);
 relative=extractAfter(string(original),strlength(source)+1);
 assert(inkprof.internal.sha256(original)==inkprof.internal.sha256(fullfile(destination,relative)), ...
  'inkprof:PrintCopy','Print copy differs: %s',relative);drawnow;
end
end
