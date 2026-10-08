% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function guard=lowerTopWindows(dialog)
%LOWERTOPWINDOWS Keep a blocking dialog above InkProf's always-on-top windows.
% On macOS an 'alwaysontop' figure stays above a 'modal' uifigure. A dialog
% that then waits with uiwait is hidden and unreachable, and MATLAB must be
% force-quit. Other always-on-top figures are set to 'normal' while the
% dialog is open; the returned onCleanup object restores them.
%   guard = inkprof.internal.lowerTopWindows(f); f.Visible='on'; uiwait(f);
lowered=gobjects(0);
for fig=reshape(findall(groot,'Type','figure'),1,[])
    if fig~=dialog&&strcmp(fig.WindowStyle,'alwaysontop')
        fig.WindowStyle='normal';lowered(end+1)=fig; %#ok<AGROW>
    end
end
drawnow;
if isgraphics(dialog,'figure')&&strcmp(dialog.Visible,'on')
    try, figure(dialog);catch, end
end
guard=onCleanup(@()restore(lowered));
end

function restore(lowered)
for fig=reshape(lowered,1,[])
    if isgraphics(fig,'figure')&&~strcmp(fig.BeingDeleted,'on'),fig.WindowStyle='alwaysontop';end
end
end
