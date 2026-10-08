% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function [report,reportFile]=checkPhotoGradients(jobFolder,options)
%CHECKPHOTOGRADIENTS Working RGB -> printer ICC with intent/BPC and bit depth.
arguments
 jobFolder (1,1) string
 options.ShowDialog (1,1) logical = true
end
jobFolder=inkprof.internal.absolutePath(jobFolder);paths=inkprof.paths();
status=jsondecode(fileread(fullfile(jobFolder,'status.json')));profile=fullfile(jobFolder,'result','profile.icc');
assert(string(status.status)=="succeeded"&&inkprof.internal.sha256(profile)==string(status.profileSHA256), ...
 'inkprof:PhotoGradient','Select a successful, unchanged ICC job.');
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
fprintf('InkProf: photographic gradient conversion (sRGB / Adobe RGB, intent, BPC, float / 16 / 8 bit)...\n');
inkprof.runPython(fullfile(paths.Root,'analysis','photo_gradients.py'),[profile,fullfile(w,'report')], ...
 RequiredModules=["numpy","scipy","PIL"],TimeoutSeconds=300);
report=jsondecode(fileread(fullfile(w,'report','photo-gradients.json')));
folder=fullfile(jobFolder,'checks',string(java.util.UUID.randomUUID()));
[ok,msg]=movefile(fullfile(w,'report'),folder);assert(ok,'inkprof:IO','%s',msg);
reportFile=fullfile(folder,'photo-gradients.json');
inkprof.internal.recordProjectStep(folder,"Photographic gradient diagnostic (numerical only)");
if ~options.ShowDialog,return;end
f=uifigure('Name','InkProf - Photographic gradients','Tag','InkProfPhotoGradient','WindowStyle','alwaysontop','Position',[100 90 1250 700],'Visible','off');
g=uigridlayout(f,[3 1]);g.RowHeight={85,'1x',36};
uilabel(g,'Text',string(report.method)+newline+string(report.caveat),'WordWrap','on');
p=report.paths;rows=cell(numel(p),10);
for k=1:numel(p)
 a=p(k);v="unavailable";if ~isempty(a.metrics.interiorCurvatureP95),v=string(sprintf('%.1f',a.metrics.interiorCurvatureP95));end
 rows(k,:)={a.sourceSpace,a.intent,logical(a.bpc),a.path,a.precision,char(v), ...
  sprintf('%d',a.metrics.lightnessReversals),sprintf('%d',a.metrics.uniqueDeviceCodes),sprintf('%d',a.metrics.unchangedSteps),sprintf('%.1f%%',100*a.metrics.interiorFraction)};
end
t=uitable(g,'Data',rows,'ColumnName',{'Source RGB','Intent','BPC','Gradient','Precision','Curvature P95','L* reversals','Unique RGB','Unchanged steps','Interior'}, ...
 'ColumnWidth',{125,145,45,165,65,105,85,85,115,75},'RowName',{},'ColumnEditable',false);
addStyle(t,uistyle('HorizontalAlignment','right'),'column',6:10);
uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
f.Visible='on';drawnow;focus(f);
end
