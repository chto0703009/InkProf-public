% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function watch=workflowProgressTimer(fig,w,active,label,started,progress,details,status)
% Keep the timer callback outside the workflow run's cleanup workspace.
watch=timer('ExecutionMode','fixedSpacing','Period',1,'BusyMode','drop','TimerFcn',@updateProgress);
function updateProgress(~,~)
            if ~isvalid(fig),return;end
            elapsed=seconds(datetime('now')-started);
            phase=label;
            if isappdata(fig,'InkProfCalculationPhase'),phase=getappdata(fig,'InkProfCalculationPhase');end
            text=phase+" — elapsed "+floor(elapsed/60)+" min "+mod(floor(elapsed),60)+" sec";
            logs=dir(fullfile(w.Root,'profiles','iterations','*','progress.log'));
            if any(active==["profile","continue"])&&~isempty(logs)
                [~,last]=max([logs.datenum]);entry=logs(last);
                if entry.datenum>=datenum(started)
                    try
                        lines=splitlines(strtrim(string(fileread(fullfile(entry.folder,entry.name)))));
                        text=text+newline+lines(end);
                    catch
                        % The writer may be replacing the progress file.
                    end
                end
            end
            if ~isempty(progress)&&isvalid(progress),progress.Message=char(text);end
            details.Value=cellstr(splitlines(text+newline+"Work is in progress. Complete any open input dialog; otherwise please wait."));status.Text="Running: "+phase+". Please wait.";
        end
end
