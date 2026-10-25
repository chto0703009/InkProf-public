% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function fields=validateMetadataCorrection(record,printing,root)
% Descriptive corrections cannot change numerical processing configuration.
allowed=["status","printer","paper","ink","inkType","driver","quality", ...
 "colorManagement","media","printPath","dryingHours","settings", ...
 "printerCoating","coatingSettings","paperSurface","finish", ...
 "profileName","profileDescription"];
fields=strings(0,1);
for key=union(string(fieldnames(record.printing)),string(fieldnames(printing)))'
 old=[];new=[];
 if isfield(record.printing,key),old=record.printing.(key);end
 if isfield(printing,key),new=printing.(key);end
 if ~strcmp(jsonencode(old),jsonencode(new))
  assert(any(key==allowed),'inkprof:CorrectionProcessing','%s changes numerical processing or output configuration; use actual change instead.',key);
  fields(end+1)=key; %#ok<AGROW>
 end
end
for entry=reshape(record.files,1,[])
 if inkprof.internal.isFinderMetadata(string(entry.path)),continue;end
 file=inkprof.internal.absolutePath(fullfile(root,string(entry.path)));
 assert(startsWith(file,root+filesep)&&isfile(file)&&inkprof.internal.sha256(file)==string(entry.sha256), ...
  'inkprof:Integrity','Cannot preserve validity: registered file is missing or changed: %s',string(entry.path));
end
end
