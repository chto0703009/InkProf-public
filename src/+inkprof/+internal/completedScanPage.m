% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [page,offset]=completedScanPage(transcript,offset,chart,pairedPlan)
%COMPLETEDSCANPAGE Consume new successful scans, tied to their preceding pass.
% A hardware scan can bypass Page loaded. Never infer progress from navigation
% or a failed scan, and never replay an old success after manual page changes.
arguments
    transcript (1,1) string
    offset (1,1) double
    chart (1,1) struct
    pairedPlan (1,1) struct = struct
end
page=[];
text=char(transcript);
[starts,ends]=regexp(text,'Strip read OK');
for k=find(ends>offset)
    tokens=regexp(text(1:starts(k)-1),'Ready to read strip pass\s+(\d+)','tokens');
    if ~isempty(tokens)
        info=inkprof.internal.measurementPage(chart,str2double(tokens{end}{1}),pairedPlan);
        page=info.page;
    end
    offset=ends(k);
end
end
