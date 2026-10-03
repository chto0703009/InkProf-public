function [guard,progress]=calculationProgress(title,message)
% A scoped busy dialog for calculations in the active workflow app.
% Close the guard before asking for input. Never opens UI for batch jobs.
guard=[];progress=[];parents=findall(groot,'Type','figure','Tag','InkProfWorkflow');parent=[];
for candidate=reshape(parents,1,[])
 if isappdata(candidate,'InkProfRunning')&&getappdata(candidate,'InkProfRunning'),parent=candidate;break;end
end
if isempty(parent),return;end
parent.Visible='on';if strcmp(parent.WindowState,'minimized'),parent.WindowState='normal';end
figure(parent);setappdata(parent,'InkProfCalculationPhase',string(title));
progress=uiprogressdlg(parent,'Title',char(title),'Message',char(string(message)+newline+"Please wait. This can take several minutes."), ...
 'Indeterminate','on','Cancelable','off');
started=tic;
watch=timer('ExecutionMode','fixedSpacing','Period',1,'BusyMode','drop', ...
 'Tag','InkProfCalculationTimer','TimerFcn',@(~,~)update(progress,string(message),started));
guard=onCleanup(@()finish(progress,watch,parent));start(watch);drawnow;
end
function update(progress,message,started)
if ~isvalid(progress),return;end
elapsed=floor(toc(started));
progress.Message=char(message+newline+sprintf('Working — elapsed %d min %02d sec. Please wait.',floor(elapsed/60),mod(elapsed,60)));
end
function finish(progress,watch,parent)
if isvalid(watch),stop(watch);delete(watch);end
if isvalid(progress),close(progress);end
if isgraphics(parent)
 if isappdata(parent,'InkProfCalculationPhase'),rmappdata(parent,'InkProfCalculationPhase');end
 parent.Visible='on';figure(parent);
end
end
