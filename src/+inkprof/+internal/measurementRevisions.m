% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function revisions=measurementRevisions(folder,target)
% List usable saved revisions for this exact target, newest saved file first.
revisions=struct('file',{},'label',{},'saved',{});
if ~isfolder(folder),return;end
targetHash=inkprof.internal.sha256(target);
files=dir(fullfile(folder,'**','measurement-*.json'));
for f=reshape(files,1,[])
 try
  file=string(fullfile(f.folder,f.name));m=jsondecode(fileread(file));
  if ~isfield(m,'documentType')||string(m.documentType)~="inkprof.chart-measurement"||~m.complete,continue;end
  chartFile=fullfile(f.folder,'chart.json');[~,stem]=fileparts(file);ti3=fullfile(f.folder,stem+".ti3");
  if ~isfile(chartFile)||~isfile(ti3),continue;end
  chart=jsondecode(fileread(chartFile));
  if string(chart.sourceSHA256)~=targetHash||inkprof.internal.sha256(chartFile)~=string(m.chartJSONSHA256)||inkprof.internal.sha256(ti3)~=string(m.sourceTI3SHA256),continue;end
  saved=string(datetime(f.datenum,'ConvertFrom','datenum','Format','yyyy-MM-dd HH:mm:ss'));
  label=saved+" | "+m.measuredSourcePatches+" / "+m.expectedSourcePatches+" patches | Complete";
  if isfield(m,'patchOverrides'),label=label+" | "+numel(m.patchOverrides)+" patch corrections";end
  revisions(end+1)=struct('file',file,'label',label,'saved',f.datenum); %#ok<AGROW>
 catch
  % Incomplete, damaged or unrelated JSON is not a usable revision.
 end
end
if ~isempty(revisions)
 [~,order]=sort([revisions.saved],'descend');revisions=revisions(order);
 for k=1:numel(revisions),revisions(k).label="Revision "+(numel(revisions)-k+1)+" | "+revisions(k).label;end
 revisions(1).label="Latest saved — "+revisions(1).label;
end
end
