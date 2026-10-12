% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function activity=gamutActivity(parent,label)
% Visible elapsed-time feedback in the foreground classic gamut window.
phase="Calculating gamut patches";started=tic;
watch=timer('ExecutionMode','fixedSpacing','Period',1,'BusyMode','drop', ...
 'Tag','InkProfGamutActivity','TimerFcn',@(~,~)tick());
activity=struct('stage',@stage,'close',@closeActivity);start(watch);tick();
 function stage(value)
  if phase~=string(value),started=tic;end
  phase=string(value);
  waiting=any(phase==["Review patches","Choose save location"]);
  if waiting&&isvalid(watch)&&strcmp(watch.Running,'on'),stop(watch);end
  if ~waiting&&isvalid(watch)&&strcmp(watch.Running,'off'),start(watch);end
  tick();
 end
 function tick()
  if ~isgraphics(parent)||~isgraphics(label),closeActivity();return;end
  if any(phase==["Review patches","Choose save location"])
   label.String=char(phase+" — waiting for your selection.");
  else
   elapsed=floor(toc(started));
   label.String=char(phase+newline+sprintf('Working — elapsed %d min %02d sec. Please wait.',floor(elapsed/60),mod(elapsed,60)));
  end
  drawnow limitrate;
 end
 function closeActivity()
  if isvalid(watch),stop(watch);delete(watch);end
 end
end
