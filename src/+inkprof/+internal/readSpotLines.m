% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [lines,pending]=readSpotLines(reader,pending)
% ready() guarantees a character, not a whole line. Never call readLine here.
% Bound work per GUI timer tick even when debug output arrives continuously.
started=tic;count=0;
while reader.ready()&&count<16384&&toc(started)<.04
 value=reader.read();if value<0,break;end
 pending(end+1)=char(value);count=count+1; %#ok<AGROW>
end
ends=find(pending==newline);lines=cell(1,numel(ends));first=1;
for k=1:numel(ends),lines{k}=pending(first:ends(k)-1);first=ends(k)+1;end
pending=pending(first:end);
end
