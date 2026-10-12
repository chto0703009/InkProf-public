% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function reports=failedIterationReports(project)
reports=struct('name',{},'path',{});project=inkprof.internal.absolutePath(project);
entries=dir(fullfile(project,'profiles','iterations','*','iteration.json'));
[~,order]=sort([entries.datenum],'descend');
for k=order
 file=fullfile(entries(k).folder,entries(k).name);
 try
  data=jsondecode(fileread(file));
  if string(data.status)~="failed",continue;end
  reports=struct('name',"Failed iteration details",'path',string(file));
  for key=["c1Report","gridReport"]
   if ~isfield(data,key),continue;end
   path=string(java.io.File(char(fullfile(entries(k).folder,string(data.(key))))).getCanonicalPath());
   if startsWith(path,project+filesep)&&isfile(path)
    reports(end+1)=struct('name',key,'path',path); %#ok<AGROW>
   end
  end
  return;
 catch
  % Skip incomplete records; never follow paths outside this project.
 end
end
end
