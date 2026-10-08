% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function profileTradeoffDialog(w,parent)
a=inkprof.internal.withFocus(parent,@inputdlg, ...
 {'Final colprof -r values (%) separated by spaces (positive numbers):'}, ...
 'Compare accuracy and gradients',1,{'0.5 1 1.5'});
if isempty(a),return;end
values=str2double(regexp(strtrim(a{1}),'\s+','split'));
assert(~isempty(values)&&all(isfinite(values)&values>0)&&numel(values)<=6, ...
 'inkprof:Comparison','Enter 1-6 positive numeric values.');
choice=uiconfirm(parent,'Compare Argyll colprof smoothing on the raw locked B1 measurements. This can take several minutes. No profile is selected or approved.', ...
 'Compare accuracy and gradients','Options',{'Compare Argyll candidates','Cancel'},'CancelOption',2);
if strcmp(choice,'Cancel'),return;end
progress=inkprof.internal.calculationProgress("Comparing accuracy and gradients","Building separate candidates and evaluating photographic conversion. This can take several minutes.",Parent=parent);
[T,folder]=inkprof.comparePreRegularization(fileparts(w.output('input','input')),AvgDev=[], ...
 FinalSmoothing=values(:)',A2BQuality="high",RunC1=false,RunSky=true);
clear progress;
inkprof.internal.showProfileTradeoffResults(T,folder);
end
