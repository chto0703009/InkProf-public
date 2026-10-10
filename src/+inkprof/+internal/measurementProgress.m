% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function progress=measurementProgress(transcript,totalPasses)
% Count instrument confirmations, never navigation or attempted scans.
arguments
 transcript (1,1) string
 totalPasses (1,1) double {mustBeInteger,mustBePositive}
end
read=false(1,totalPasses);current=NaN;
tokens=regexp(char(transcript),'Ready to read strip pass (\d+)(?=\s|$)|Strip read OK','match');
for k=1:numel(tokens)
 row=regexp(tokens{k},'^Ready to read strip pass (\d+)','tokens','once');
 if ~isempty(row)
  current=str2double(row{1});
 elseif isfinite(current)&&current>=1&&current<=totalPasses
  read(current)=true;
 end
end
progress=struct('confirmed',read,'count',sum(read),'total',totalPasses,'missing',find(~read));
end
