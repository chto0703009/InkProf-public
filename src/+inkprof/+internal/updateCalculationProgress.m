% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function updateCalculationProgress(parent)
% Explicit checkpoints also update feedback inside another timer callback.
if ~isgraphics(parent)||~isappdata(parent,'InkProfCalculationState'),return;end
s=getappdata(parent,'InkProfCalculationState');if ~isvalid(s.progress),return;end
elapsed=floor(toc(s.started));s.progress.Title=char(s.title);
s.progress.Message=char(s.message+newline+sprintf('Working — elapsed %d min %02d sec. Please wait.',floor(elapsed/60),mod(elapsed,60)));
end
