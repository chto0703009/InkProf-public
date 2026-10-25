% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [report,reportFile]=checkProfileC1(jobFolder,options)
%CHECKPROFILEC1 Float CMM, local inverse behaviour and damaged-profile controls.
arguments
 jobFolder (1,1) string = ""
 options.ShowDialog (1,1) logical = true
end
report=[];reportFile="";
if jobFolder==""
 p=uigetdir(pwd,'Select ICC job folder');if isequal(p,0),return;end;jobFolder=string(p);
end
jobFolder=inkprof.internal.absolutePath(jobFolder);paths=inkprof.paths();
activity=[];
if options.ShowDialog
 activity=inkprof.internal.profileCheckProgress(jobFolder,"InkProfGridResult","Step 8 - C1 (3/3)", ...
  "Grid checks are ready. Checking the colour engine, inverse neighbourhoods and damaged-profile controls before opening C1 results.");
end
bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'xicclu');if ispc,exe=exe+".exe";end
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
fprintf('InkProf C1: checking float CMM, inverse neighbourhoods and negative controls...\n');
inkprof.runPython(fullfile(paths.Root,'analysis','profile_c1.py'), ...
 [jobFolder,exe,fullfile(w,'report')],RequiredModules=["numpy","colour","PIL"],TimeoutSeconds=300);
report=jsondecode(fileread(fullfile(w,'report','c1-check.json')));
parent=fullfile(jobFolder,'checks');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,string(java.util.UUID.randomUUID()));
[ok,msg]=movefile(fullfile(w,'report'),folder);assert(ok,'inkprof:IO','%s',msg);
reportFile=fullfile(folder,'c1-check.json');
inkprof.internal.recordProjectStep(folder,"C1 float CMM, inverse neighbourhood and negative-control diagnostics");
fprintf('InkProf C1: float CMM forward max dE00 %.6f; inverse max RGB difference %.6f percentage points.\n', ...
 report.cmmFloat.forwardDeltaE00.max,report.cmmFloat.backwardRGBPercent.max);
fprintf('All negative controls detected: %d. ISSUE-001 was closed by user decision on 2026-10-25 after repeated measurements without observed problems.\nReport: %s\n',report.allNegativeControlsDetected,reportFile);
if ~isempty(report.grossFailureAlerts)||~report.allNegativeControlsDetected
 warning('inkprof:C1Review','C1 diagnostic alerts require review; inspect the saved report.');
end
if ~options.ShowDialog,return;end
clear activity
f=uifigure('Name','InkProf - C1 numerical diagnostics','Position',[150 100 1000 700], ...
 'WindowStyle','alwaysontop','Visible','off');
g=uigridlayout(f,[3 1]);g.RowHeight={75,'1x',36};
uilabel(g,'Text',sprintf('C1 numerical diagnostics saved.\nISSUE-001 was closed by user decision on 2026-10-25 after repeated measurements without observed problems. Print quality is assessed separately.'),'WordWrap','on');
uitextarea(g,'Editable','off','Value',splitlines(string(fileread(fullfile(folder,'c1-check.md')))));
uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));f.Visible='on';drawnow;focus(f);
end
