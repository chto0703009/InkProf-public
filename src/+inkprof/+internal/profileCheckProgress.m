% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [guard,progress]=profileCheckProgress(job,previousTag,title,message)
% Keep the next check's activity above its existing always-on-top result.
parent=[];
windows=findall(groot,'Type','figure','Tag',char(previousTag));
for window=reshape(windows,1,[])
    if isappdata(window,'InkProfCheckJob')&&string(getappdata(window,'InkProfCheckJob'))==string(job)
        parent=window;break;
    end
end
[guard,progress]=inkprof.internal.calculationProgress(title,message,Parent=parent);
end
