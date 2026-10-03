% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function guard=restoreAppFocus(parent,options)
% Restore the owning app after dialogs; adopt newly opened MATLAB figures.
% Keep each child's existing close/save/cancel callbacks intact.
arguments
 parent
 options.RestoreOnReturn (1,1) logical = true
end
before=findall(groot,'Type','figure');
guard=onCleanup(@finish);
    function finish()
        if ~isgraphics(parent,'figure'),return;end
        after=findall(groot,'Type','figure');adopted=false;
        for child=reshape(after,1,[])
            if child==parent||any(child==before)||~strcmp(child.Visible,'on'),continue;end
            if isappdata(child,'InkProfFocusOwner'),continue;end
            setappdata(child,'InkProfFocusOwner',parent);
            listener=addlistener(child,'ObjectBeingDestroyed',@(~,~)scheduleReturn(parent));
            setappdata(child,'InkProfFocusListener',listener);
            adopted=true;
        end
        if ~adopted&&options.RestoreOnReturn,returnFocus(parent);end
    end
end
function scheduleReturn(parent)
if ~isgraphics(parent,'figure')||strcmp(parent.BeingDeleted,'on'),return;end
% macOS may activate the desktop during destruction; restore after it finishes.
t=timer('ExecutionMode','singleShot','StartDelay',0.08, ...
 'TimerFcn',@(~,~)returnFocus(parent),'StopFcn',@(timer,~)delete(timer));
start(t);
end
function returnFocus(parent)
if ~isgraphics(parent,'figure')||strcmp(parent.BeingDeleted,'on'),return;end
% An open sibling (especially a modal dialog) must retain focus.
target=parent;figures=findall(groot,'Type','figure');
for child=reshape(figures,1,[])
 if child==parent||strcmp(child.BeingDeleted,'on')||~strcmp(child.Visible,'on'),continue;end
 if isappdata(child,'InkProfFocusOwner')&&isequal(getappdata(child,'InkProfFocusOwner'),parent)
  target=child;break
 end
end
try
 if isprop(target,'WindowState')&&strcmp(target.WindowState,'minimized'),target.WindowState='normal';end
 figure(target);
catch
 % Focus is cosmetic; never interrupt saving or closing if the OS rejects it.
end
end
