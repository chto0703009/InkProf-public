% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [pass,offset]=lastConfirmedPass(transcript,offset)
% Consume actual successes; failed scans and navigation never advance.
pass=NaN;text=char(transcript);[starts,ends]=regexp(text,'Strip read OK');
for k=find(ends>offset)
 tokens=regexp(text(1:starts(k)-1),'Ready to read strip pass\s+(\d+)','tokens');
 if ~isempty(tokens),pass=str2double(tokens{end}{1});end
 offset=ends(k);
end
end
