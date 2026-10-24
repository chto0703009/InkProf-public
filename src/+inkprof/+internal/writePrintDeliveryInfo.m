% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function record=writePrintDeliveryInfo(destination,project,root,state,id,target,files,instructions)
%WRITEPRINTDELIVERYINFO Keep exact project identity beside the print copies.
copiedUTC=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
record=struct('documentType',"inkprof.print-delivery",'schemaVersion',1, ...
 'projectName',string(project.name),'projectId',string(project.projectId),'projectRoot',string(root), ...
 'step',string(id),'iteration',state.cycle,'iterationId',string(state.iterationId), ...
 'copiedUTC',copiedUTC,'destination',string(destination),'sourceTarget',string(target), ...
 'sourceTargetSHA256',inkprof.internal.sha256(target),'files',files,'instructions',instructions);
record.targetCreatedUTC="unknown";record.targetIteration="unknown";record.targetIterationId="unknown";
record.targetDescription="unknown";
layout=fullfile(fileparts(target),'target.json');
if isfile(layout)
 t=jsondecode(fileread(layout));
 if isfield(t,'ids'),record.patchCount=numel(t.ids);end
 if isfield(t,'targetInfo')&&isfield(t.targetInfo,'footerText'),record.targetDescription=string(t.targetInfo.footerText);end
end
manifest=fullfile(fileparts(target),'manifest.json');
if isfile(manifest)
 m=jsondecode(fileread(manifest));record.sourceManifestSHA256=inkprof.internal.sha256(manifest);
 if isfield(m,'createdUTC'),record.targetCreatedUTC=string(m.createdUTC);end
 if isfield(m,'pageCount'),record.pageCount=m.pageCount;end
end
% A target may be reused in a later cycle. Do not call the copy cycle its origin.
if isfield(state,'history')
 history=state.history;if isstruct(history),history=num2cell(history);end
 for k=numel(history):-1:1
  e=history{k};if string(e.step)~=string(id)||string(e.status)~="completed",continue;end
  if ~isfield(e.details,'result')||~isfield(e.details.result,'outputs')||~isfield(e.details.result.outputs,'target'),continue;end
  old=fullfile(root,string(e.details.result.outputs.target));
  if inkprof.internal.absolutePath(old)~=inkprof.internal.absolutePath(target),continue;end
  record.targetIteration=string(e.cycle);record.targetIterationId=string(e.iterationId);break
 end
end
lines=["InkProf print delivery";"Project name (exact): "+record.projectName; ...
 "Project ID: "+record.projectId;"Project folder: "+record.projectRoot; ...
 "Workflow step: "+record.step;"Workflow iteration at copy: "+record.iteration; ...
 "Workflow iteration ID at copy: "+record.iterationId; ...
 "Target origin iteration: "+record.targetIteration;"Target origin iteration ID: "+record.targetIterationId; ...
 "Target description: "+record.targetDescription; ...
 "Copy saved (local): "+inkprof.internal.localReportTime(record.copiedUTC); ...
 "Copy saved (UTC): "+record.copiedUTC;"Target package created (UTC): "+record.targetCreatedUTC; ...
 "Original TI2: "+record.sourceTarget;"TI2 SHA-256: "+record.sourceTargetSHA256; ...
 "";"Printing settings from project:";string(jsonencode(project.printing,PrettyPrint=true)); ...
 "";"Copied files and SHA-256:"];
if record.targetCreatedUTC~="unknown"
 lines=[lines(1:end-1);"Target package created (local): "+inkprof.internal.localReportTime(record.targetCreatedUTC);lines(end)];
end
for k=1:numel(files),lines(end+1)=string(files(k).name)+" | "+string(files(k).sha256);end
lines=[lines(:);"";"The date identifies file creation/copy, not physical printing or drying."; ...
 "PRINT COPY ONLY - this folder is not the editable InkProf project. Keep the original project folder."; ...
 "Return to the original project and matching workflow step for measurement. The TIFF copies alone do not define patch identities."; ...
 "";instructions];
fid=fopen(fullfile(destination,'PROJECT_INFO.txt'),'w','n','UTF-8');assert(fid>=0,'inkprof:IO','Cannot write print identification.');
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',lines);clear cleanup
inkprof.internal.writeJson(fullfile(destination,'print-delivery.json'),record);
fid=fopen(fullfile(destination,'PRINT_COPY_ONLY.txt'),'w','n','UTF-8');assert(fid>=0,'inkprof:IO','Cannot write print-copy notice.');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',"PRINT COPY ONLY - NOT AN INKPROF PROJECT", ...
 "Original project: "+string(root),"Project ID: "+string(project.projectId), ...
 "Keep the original project folder. Reopen that folder in InkProf to measure.");
end
