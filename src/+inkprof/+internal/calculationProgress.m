% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [guard,progress]=calculationProgress(title,message,options)
% Scoped activity feedback. Nested phases reuse one dialog and one timer.
% Close the guard before requesting input. Batch jobs never open a window.
arguments
 title (1,1) string
 message (1,1) string
 options.Parent = []
end
guard=[];progress=[];parents=findall(groot,'Type','figure','Tag','InkProfWorkflow');parent=options.Parent;
for candidate=reshape(parents,1,[])
 if isempty(parent)&&isappdata(candidate,'InkProfRunning')&&getappdata(candidate,'InkProfRunning'),parent=candidate;break;end
end
if isempty(parent),return;end
parent.Visible='on';if strcmp(parent.WindowState,'minimized'),parent.WindowState='normal';end
figure(parent);previous=[];
if isappdata(parent,'InkProfCalculationState')
 previous=getappdata(parent,'InkProfCalculationState');
 if ~isvalid(previous.progress)
  if isvalid(previous.watch),stop(previous.watch);delete(previous.watch);end
  previous=[];
 end
end
if isempty(previous)
 progress=uiprogressdlg(parent,'Title',char(title),'Message',char(message),'Indeterminate','on','Cancelable','off');
 watch=timer('ExecutionMode','fixedSpacing','Period',1,'BusyMode','drop', ...
  'Tag','InkProfCalculationTimer','TimerFcn',@(~,~)update(parent));
else
 progress=previous.progress;watch=previous.watch;
end
state=struct('progress',progress,'watch',watch,'title',string(title),'message',string(message), ...
 'started',tic,'token',string(java.util.UUID.randomUUID()));
setappdata(parent,'InkProfCalculationState',state);setappdata(parent,'InkProfCalculationPhase',state.title);
guard=onCleanup(@()finish(parent,state,previous));update(parent);
if isempty(previous),start(watch);end
drawnow;
end
function update(parent)
inkprof.internal.updateCalculationProgress(parent);
end
function finish(parent,state,previous)
if ~isgraphics(parent)
 if isvalid(state.watch),stop(state.watch);delete(state.watch);end
 return
end
if ~isappdata(parent,'InkProfCalculationState'),return;end
active=getappdata(parent,'InkProfCalculationState');
if active.token~=state.token,return;end
if isempty(previous)
 if isvalid(state.watch),stop(state.watch);delete(state.watch);end
 if isvalid(state.progress),close(state.progress);end
 rmappdata(parent,'InkProfCalculationState');
 if isappdata(parent,'InkProfCalculationPhase'),rmappdata(parent,'InkProfCalculationPhase');end
else
 setappdata(parent,'InkProfCalculationState',previous);setappdata(parent,'InkProfCalculationPhase',previous.title);update(parent);
end
parent.Visible='on';figure(parent);
end
