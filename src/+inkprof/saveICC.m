% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [destination,receipt]=saveICC(source,destination,options)
%SAVEICC Copy ICC; interactive export also sets the internal display name.
arguments
 source (1,1) string
 destination (1,1) string = ""
 options.Overwrite (1,1) logical = false
end
receipt=[];source=inkprof.internal.absolutePath(source);interactive=destination=="";
if interactive
 [~,stem,ext]=fileparts(source);
 suggested=stem+ext;project=inkprof.internal.findProject(source);
 if project~=""
  record=jsondecode(fileread(fullfile(project,'inkprof-project.json')));
  suggested=inkprof.internal.iccDeliveryName(string(record.name));
 end
 [n,p]=uiputfile({'*.icc;*.icm','ICC profiles'},'Save ICC copy as',char(suggested));
 if isequal(n,0),destination="";return;end
 destination=fullfile(p,n);
end
destination=inkprof.internal.absolutePath(destination);
assert(destination~=source,'inkprof:SameFile','Choose a different destination; the original is preserved.');
assert(~isfolder(destination),'inkprof:Exists','Destination is a folder.');
if isfile(destination)&&~options.Overwrite
 if interactive
  answer=questdlg('Replace the existing destination file?','Save ICC copy','Replace','Cancel','Cancel');
  if ~strcmp(answer,'Replace'),destination="";return;end
 else,error('inkprof:Exists','Destination exists. Set Overwrite=true to replace it explicitly.');end
end
parent=fileparts(destination);assert(isfolder(parent),'inkprof:Output','Destination folder does not exist.');
work=string(tempname);mkdir(work);cleanup=onCleanup(@()rmdir(work,'s'));
[record,~]=inkprof.readICC(source,OutputFolder=work,ShowDialog=false);
stage=string(tempname(parent));stageCleanup=onCleanup(@()removeStage(stage));
[ok,msg]=copyfile(source,stage);assert(ok,'inkprof:IO','%s',msg);
assert(inkprof.internal.sha256(stage)==string(record.source.sha256),'inkprof:Integrity','Source changed during copying.');
naming=struct;expected=string(record.source.sha256);
if interactive
 [~,displayName]=fileparts(destination);naming=inkprof.internal.nameICC(source,stage,displayName);expected=string(naming.sha256);
end
[ok,msg]=movefile(stage,destination,'f');assert(ok,'inkprof:IO','%s',msg);
assert(inkprof.internal.sha256(destination)==expected,'inkprof:Integrity','Saved copy hash mismatch.');
receipt=struct('schemaVersion',1,'documentType',"inkprof.icc-export", ...
 'source',record.source,'destination',destination,'sha256',expected, ...
 'byteIdentical',~interactive,'exportedUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")));
if interactive,receipt.naming=naming;end
project=inkprof.internal.findProject(source);
if project~=""
 logs=fullfile(project,'profiles','exports');if ~isfolder(logs),mkdir(logs);end
 inkprof.internal.writeJson(fullfile(logs,string(java.util.UUID.randomUUID())+".json"),receipt);
 inkprof.internal.recordProjectStep(project,"Exported ICC copy; see export receipt for naming and hashes");
end
other=inkprof.internal.findProject(destination);
if other~=""&&other~=project,inkprof.internal.recordProjectStep(other,"Saved ICC copy; see source export receipt");end
fprintf('InkProf: saved ICC copy: %s\n',destination);
end
function removeStage(path)
if isfile(path),delete(path);end
end
