% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function varargout=withFocus(owner,dialog,varargin)
%WITHFOCUS Run a native/Java dialog and return focus to the InkProf window.
% On macOS, closing uigetfile, uiputfile, uigetdir, inputdlg or listdlg
% activates the MATLAB desktop, which then covers the app. Focus is restored
% immediately and again shortly after, once macOS has finished activating.
%   [n,p] = inkprof.internal.withFocus(fig,@uigetfile,filter,title);
before=findall(groot,'Type','figure');
% A delayed callback from the preceding dialog must not cover this one.
hadFlag=isgraphics(owner,'figure')&&isappdata(owner,'InkProfNativeDialogOpen');
previous=false;
if isgraphics(owner,'figure')
    if hadFlag,previous=getappdata(owner,'InkProfNativeDialogOpen');end
    setappdata(owner,'InkProfNativeDialogOpen',true);
    figure(owner);drawnow;
end
dialogGuard=onCleanup(@()restoreFlag(owner,hadFlag,previous));
fileDialogGuard=[];
if any(string(func2str(dialog))==["uigetfile","uiputfile","uigetdir"])
    fileDialogGuard=inkprof.internal.suspendForFileDialog(owner);
end
try
    [varargout{1:nargout}]=dialog(varargin{:});
catch err
    clear fileDialogGuard
    clear dialogGuard
    refocus(owner,before);rethrow(err);
end
clear fileDialogGuard
clear dialogGuard
refocus(owner,before);
end

function restoreFlag(owner,hadFlag,previous)
if ~isgraphics(owner,'figure'),return;end
if hadFlag,setappdata(owner,'InkProfNativeDialogOpen',previous);
elseif isappdata(owner,'InkProfNativeDialogOpen'),rmappdata(owner,'InkProfNativeDialogOpen');end
end

function refocus(owner,before)
if ~isgraphics(owner,'figure'),return;end
bring(owner,before);
for delay=[0.1 0.4]
    t=timer('ExecutionMode','singleShot','StartDelay',delay, ...
        'TimerFcn',@(~,~)bring(owner,before),'StopFcn',@(timer,~)delete(timer));
    start(t);
end
end

function bring(owner,before)
if ~isgraphics(owner,'figure')||strcmp(owner.BeingDeleted,'on')||~strcmp(owner.Visible,'on'),return;end
if isappdata(owner,'InkProfNativeDialogOpen')&&getappdata(owner,'InkProfNativeDialogOpen'),return;end
% A window opened after the dialog (for example the next step's window) keeps focus.
target=owner;
for f=reshape(findall(groot,'Type','figure'),1,[])
    if f~=owner&&~any(f==before)&&strcmp(f.Visible,'on')&&~strcmp(f.BeingDeleted,'on'),target=f;end
end
try
    if isprop(target,'WindowState')&&strcmp(target.WindowState,'minimized'),target.WindowState='normal';end
    figure(target);
catch
    % Focus is cosmetic; never interrupt the workflow.
end
end
