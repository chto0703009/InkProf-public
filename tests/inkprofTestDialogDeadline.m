% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function guard=inkprofTestDialogDeadline(seconds)
% Closing test windows releases modal waits; assertions still fail if the
% expected interaction did not complete. Avoid nested cleanup reference cycles.
f=uifigure('Visible','off');drawnow;delete(f);
t=timer('Name','InkProfTestDeadline','StartDelay',seconds,'TimerFcn',@(~,~)expire(seconds));
setappdata(groot,'InkProfTestDialogExpired',false);
start(t);guard=onCleanup(@()dispose(t));
end
function expire(seconds)
setappdata(groot,'InkProfTestDialogExpired',true);
warning('inkprof:TestDialogTimeout','Dialog test exceeded %.0f seconds.',seconds);
delete(findall(groot,'Type','figure'));
end
function dispose(t)
if isvalid(t),stop(t);delete(t);end
end
