% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function guard=suspendForFileDialog(owner)
% Native file dialogs cannot be parented to uifigures on all macOS releases.
% Remove the owner from the window stack until the dialog returns.
guard=[];
if ~isgraphics(owner,'figure'),return;end
visible=owner.Visible;
guard=onCleanup(@restore);
owner.Visible='off';drawnow;
    function restore
        if isgraphics(owner,'figure')&&~strcmp(owner.BeingDeleted,'on')
            owner.Visible=visible;
        end
    end
end
