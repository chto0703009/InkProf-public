% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function text=measurementLog(transcript,chart,pairedPlan)
% Display printed coordinates instead of chartread's internal scan numbers.
arguments
 transcript (1,1) string
 chart (1,1) struct
 pairedPlan (1,1) struct = struct
end
text=replace(transcript,char(13),"");
[tokens,starts,ends]=regexp(char(text),'Ready to read strip pass (\d+)(?=\s|$)','tokens','start','end');
for k=numel(tokens):-1:1
 pass=str2double(tokens{k}{1});
 info=inkprof.internal.measurementPage(chart,pass,pairedPlan);
 label=sprintf('Ready to read printed row %s on page %d/%d',info.row,info.page,info.totalPages);
 if ~isempty(fieldnames(pairedPlan))
  scan=pairedPlan.passes(pass);
  label=sprintf('%s · %s scan (%d/2)',label,upper(string(scan.expectedDirection)),scan.phase);
 end
 text=extractBefore(text,starts(k))+string(label)+extractAfter(text,ends(k));
end
end
