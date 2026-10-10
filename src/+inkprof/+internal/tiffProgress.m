% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function guard=tiffProgress(parent,status,label)
% Keep timer state outside the render dialog's shared nested workspace.
% Clearing the guard must close feedback as soon as rendering finishes.
state=struct('started',tic,'dialog',[],'status',status,'label',string(label));
watch=timer('ExecutionMode','fixedSpacing','Period',1,'StartDelay',2,'BusyMode','drop', ...
    'Tag','InkProfTiffClock','TimerFcn',@(watch,~)update(watch,parent));
watch.UserData=state;
guard=onCleanup(@()finish(watch));
start(watch);
end
function update(watch,parent)
if ~isgraphics(parent),finish(watch);return;end
state=watch.UserData;
seconds=floor(toc(state.started));
clockText=sprintf('Working — elapsed %d min %02d sec',floor(seconds/60),mod(seconds,60));
message=sprintf('%s\n%s. Please wait.',state.label,clockText);
try
    if isempty(state.dialog)||~isvalid(state.dialog)
        state.dialog=uiprogressdlg(parent,'Title','TIFF16 target','Message',message, ...
            'Indeterminate','on','Cancelable','on','CancelText','Cancel');
        watch.UserData=state;
    elseif state.dialog.CancelRequested
        parent.UserData.cancelled=true;
        state.dialog.Message=sprintf('Cancelling at the next safe checkpoint…\n\n%s.',clockText);
    else
        state.dialog.Message=message;
    end
    state.status.Text=state.label+" ("+clockText+")";
    drawnow limitrate
catch
    % Feedback must never interrupt rendering.
end
end
function finish(watch)
if ~isvalid(watch),return;end
state=watch.UserData;
stop(watch);delete(watch);
if ~isempty(state.dialog)&&isvalid(state.dialog),close(state.dialog);end
end
