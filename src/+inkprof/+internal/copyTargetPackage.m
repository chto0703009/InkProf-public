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
root=inkprof.internal.findProject(source);project=[];state=struct('cycle',"unknown",'iterationId',"unknown");id="print";
if root~=""
 project=jsondecode(fileread(fullfile(root,'inkprof-project.json')));
 if isfile(fullfile(root,'workflow.json'))
  state=jsondecode(fileread(fullfile(root,'workflow.json')));
  for step=string(fieldnames(state.steps))'
   outputs=state.steps.(step).outputs;
   if isfield(outputs,'target')&&inkprof.internal.absolutePath(fullfile(root,outputs.target))==fullfile(source,'target.ti2'),id=step;break;end
  end
 end
 name=string(project.name);
else
 name="InkProf print copy";
end
destination=inkprof.internal.printDeliveryFolder(parent,name,state.cycle,id);
options.Activity("Copying print package");drawnow;
files=dir(fullfile(source,'**','*'));files=files(~[files.isdir]);
for k=1:numel(files)
 original=fullfile(files(k).folder,files(k).name);
 relative=inkprof.internal.relativePath(source,original);
 target=fullfile(destination,relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 [ok,msg]=copyfile(original,target);assert(ok,'inkprof:PrintCopy','%s',msg);drawnow;
end
options.Activity("Checking copied files");drawnow;
copiedFiles=struct('name',{},'sha256',{});
for k=1:numel(files)
 original=fullfile(files(k).folder,files(k).name);
 relative=inkprof.internal.relativePath(source,original);
 hash=inkprof.internal.sha256(original);
 assert(hash==inkprof.internal.sha256(fullfile(destination,relative)), ...
  'inkprof:PrintCopy','Print copy differs: %s',relative);drawnow;
 copiedFiles(end+1)=struct('name',relative,'sha256',hash);
end
if ~isempty(project)&&isfile(fullfile(source,'target.ti2'))
 instructions="Use the original target's printing instructions.";
 if isfile(fullfile(source,'PRINTING.txt')),instructions=string(fileread(fullfile(source,'PRINTING.txt')));end
 inkprof.internal.writePrintDeliveryInfo(destination,project,root,state,id,fullfile(source,'target.ti2'),copiedFiles,instructions);
end
end
