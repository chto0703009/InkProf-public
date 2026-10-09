% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function record=updateProject(path,options)
%UPDATEPROJECT Hash project artifacts and append an atomic manifest revision.
% Unknown physical printing settings remain unknown; never infer them from TIFF.
arguments
 path (1,1) string
 options.WorkflowMetadataOnly (1,1) logical = false
 options.Step (1,1) string = "manual-refresh"
 options.Name (1,1) string = ""
 options.User (1,1) string = ""
 options.FolderName (1,1) string = ""
 options.FolderDecision (1,1) struct = struct
 options.PaperLayout (1,1) struct = struct
 options.Printing (1,1) struct = struct
 options.Relocations = []
end
if isfield(options.Printing,'profileOutputVersions')
 assert(any(string(options.Printing.profileOutputVersions)==["v2","v4","both"]),'inkprof:ICCVersion','Choose v2, v4 or both.');
end
root=inkprof.internal.findProject(path);
assert(root~="",'inkprof:Project','No inkprof-project.json found.');
lock=fullfile(root,'.manifest.lock');
assert(java.io.File(char(lock)).createNewFile(),'inkprof:ProjectBusy','Manifest is being updated. Retry after the other operation finishes.');
cleanup=onCleanup(@()delete(lock));
file=fullfile(root,'inkprof-project.json');record=jsondecode(fileread(file));
assert(record.schemaVersion==1&&string(record.documentType)=="inkprof.profiling-project",'inkprof:Project','Unsupported project manifest.');
listing=dir(fullfile(root,'**','*'));listing=listing(~[listing.isdir]);
files=struct('path',{},'sha256',{},'bytes',{},'documentType',{});
links=struct('from',{},'field',{},'sha256',{},'matches',{});
if options.WorkflowMetadataOnly
 files=record.files;
 if ~isempty(files),files=files(~inkprof.internal.isFinderMetadata(string({files.path})));end
end
for k=1:numel(listing)
 f=fullfile(listing(k).folder,listing(k).name);
 rel=replace(extractAfter(string(f),strlength(root)+1),"\","/");
 if inkprof.internal.isFinderMetadata(rel),continue;end
 if any(rel==["inkprof-project.json",".manifest.lock",".workflow.lock"])||startsWith(rel,".manifest-")||startsWith(rel,".workflow-"),continue;end
 if options.WorkflowMetadataOnly&&~any(rel==["workflow.json","result-log.jsonl","result-log.txt"]),continue;end
 kind="";
 if endsWith(rel,".json")
  try,v=jsondecode(fileread(f));if isstruct(v)&&isscalar(v)
   if isfield(v,'documentType'),kind=string(v.documentType);end
   for key=["chartJSONSHA256","sourceTI3SHA256","sourceSHA256","measurementSHA256","analysisSHA256","parentMeasurementSHA256","candidateSHA256"]
    if isfield(v,key)&&ischar(v.(key))&&strlength(string(v.(key)))==64
     links(end+1)=struct('from',rel,'field',key,'sha256',string(v.(key)),'matches',strings(0,1)); %#ok<AGROW>
    end
   end
   if isfield(v,'source')&&isstruct(v.source)&&isfield(v.source,'sha256')
    links(end+1)=struct('from',rel,'field',"source.sha256",'sha256',string(v.source.sha256),'matches',strings(0,1)); %#ok<AGROW>
   end
  end;catch,end
 end
 index=numel(files)+1;
 if options.WorkflowMetadataOnly
  match=find(string({files.path})==rel,1);if ~isempty(match),index=match;end
 end
 files(index)=struct('path',rel,'sha256',inkprof.internal.sha256(f),'bytes',listing(k).bytes,'documentType',kind); %#ok<AGROW>
end
for k=1:numel(links)
 links(k).matches=string({files(string({files.sha256})==links(k).sha256).path});
end
if ~options.WorkflowMetadataOnly
 record.links=links;
 record.unresolvedLinkCount=sum(arrayfun(@(x)isempty(x.matches),links));
end
old=record.files;changed=strings(0,1);removed=strings(0,1);
for k=1:numel(files)
 match=[];if ~isempty(old),match=find(string({old.path})==files(k).path);end
 if isempty(match)||string(old(match).sha256)~=files(k).sha256,changed(end+1)=files(k).path;end %#ok<AGROW>
end
if ~isempty(old),removed=string({old.path});removed=removed(~ismember(removed,string({files.path})));end
record.revision=record.revision+1;
record.updatedUTC=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
if strlength(strtrim(options.Name))>0,record.name=strtrim(options.Name);end
if strlength(strtrim(options.User))>0,record.user=strtrim(options.User);end
for field=string(fieldnames(options.Printing))'
 record.printing.(field)=options.Printing.(field);
end
if ~isempty(fieldnames(options.PaperLayout)),record.paperLayout=options.PaperLayout;end
if options.FolderName~="",record.folderName=options.FolderName;end
if ~isempty(fieldnames(options.FolderDecision))
 if ~isfield(record,'folderNameHistory')||isempty(record.folderNameHistory)
  record.folderNameHistory=options.FolderDecision;
 else
  record.folderNameHistory(end+1)=options.FolderDecision;
 end
end
if ~isempty(options.Relocations),record.relocations=options.Relocations;end
entry=struct('revision',record.revision,'utc',record.updatedUTC,'step',options.Step, ...
 'previousManifestSHA256',inkprof.internal.sha256(file),'changedPaths',changed,'removedPaths',removed);
% Retain previous manifest revisions for debugging, outside artifact inventory.
historyDir=fullfile(root,'.manifest-history');if ~isfolder(historyDir),mkdir(historyDir);end
copyfile(file,fullfile(historyDir,sprintf('%06d.json',record.revision-1)));
files=files(~startsWith(string({files.path}),".manifest-history/"));record.files=files;
if isempty(record.history),record.history=entry;else,record.history(end+1)=entry;end
stage=fullfile(root,".manifest-"+string(java.util.UUID.randomUUID())+".json");
inkprof.internal.writeJson(stage,record);
[ok,msg]=movefile(stage,file,'f');assert(ok,'inkprof:IO','%s',msg);
end
