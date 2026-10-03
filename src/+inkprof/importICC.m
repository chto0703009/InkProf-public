% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [profileFile,record]=importICC(source,projectFolder)
%IMPORTICC Preserve an ICC original and inspection in a profiling project.
arguments
 source (1,1) string = ""
 projectFolder (1,1) string = ""
end
profileFile="";record=[];
if source==""
 [n,p]=uigetfile({'*.icc;*.icm','ICC profiles'},'Import ICC profile');
 if isequal(n,0),return;end
 source=fullfile(p,n);
end
if projectFolder==""
 paths=inkprof.paths();
 p=uigetdir(char(paths.Projects),'Select an existing InkProf project');
 if isequal(p,0),return;end
 projectFolder=string(p);
end
project=inkprof.internal.findProject(projectFolder);
assert(project~="",'inkprof:Project','Select an existing InkProf project, or create one with inkprof.createProject first.');
source=inkprof.internal.absolutePath(source);
work=string(tempname);mkdir(work);cleanup=onCleanup(@()rmdir(work,'s'));
[~,stem,ext]=fileparts(source);name=stem+ext;
stage=fullfile(work,'package');mkdir(stage);
[ok,msg]=copyfile(source,fullfile(stage,name));assert(ok,'inkprof:IO','%s',msg);
[record,inspection]=inkprof.readICC(fullfile(stage,name),OutputFolder=stage,ShowDialog=false);
assert(inkprof.internal.sha256(source)==string(record.source.sha256),'inkprof:Integrity','Source changed during import.');
parent=fullfile(project,'profiles','imported');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,string(java.util.UUID.randomUUID()));profileFile=fullfile(folder,name);
record.source.path=name; % Relative to inspection.json for portable projects.
record.source.originalPath=source;
record.source.projectRelativePath=replace(extractAfter(profileFile,strlength(project)+1),"\","/");
record.importedUTC=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
delete(inspection);inkprof.internal.writeJson(fullfile(stage,'inspection.json'),record);
[ok,msg]=movefile(stage,folder);assert(ok,'inkprof:IO','%s',msg);
inkprof.internal.recordProjectStep(folder,"Imported ICC profile byte-identically (A2)");
fprintf('InkProf: imported ICC profile: %s\n',profileFile);
end
