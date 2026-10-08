% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [report,reportFile]=checkSkyRamp(jobFolder,options)
%CHECKSKYRAMP Blue-sky gradient (L* 38-70, banding window L* 40-55) through
%the profile's B2A and back. Numerical diagnostic only; see analysis/sky_ramp.py.
arguments
 jobFolder (1,1) string = ""
 options.ShowDialog (1,1) logical = true
end
report=[];reportFile="";
if jobFolder==""
 p=uigetdir(pwd,'Select ICC job folder');if isequal(p,0),return;end;jobFolder=string(p);
end
jobFolder=inkprof.internal.absolutePath(jobFolder);paths=inkprof.paths();
status=jsondecode(fileread(fullfile(jobFolder,'status.json')));
profile=fullfile(jobFolder,'result','profile.icc');
assert(string(status.status)=="succeeded"&&isfile(profile)&&inkprof.internal.sha256(profile)==string(status.profileSHA256), ...
 'inkprof:SkyRamp','Select a successful, unchanged ICC job.');
bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'xicclu');if ispc,exe=exe+".exe";end
assert(isfile(exe),'inkprof:Argyll','xicclu not found.');
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
fprintf('InkProf: blue-sky gradient check (relative colorimetric and perceptual)...\n');
inkprof.runPython(fullfile(paths.Root,'analysis','sky_ramp.py'),[profile,exe,fullfile(w,'report')], ...
 RequiredModules="numpy",TimeoutSeconds=300);
report=jsondecode(fileread(fullfile(w,'report','sky-ramp.json')));
parent=fullfile(jobFolder,'checks');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,string(java.util.UUID.randomUUID()));
[ok,msg]=movefile(fullfile(w,'report'),folder);assert(ok,'inkprof:IO','%s',msg);
reportFile=fullfile(folder,'sky-ramp.json');
inkprof.internal.recordProjectStep(folder,"Blue-sky gradient diagnostic (numerical only)");
s=report.summary.relativeColorimetric;
fprintf('Relative colorimetric: max RGB second difference %.4f pp (L* 40-55: %.4f), channel reversals in L* 40-55: %d.\nReport: %s\n', ...
 s.secondDiffMax,s.secondDiffBandMax,s.reversalsBand,reportFile);
if ~options.ShowDialog,return;end
f=uifigure('Name','InkProf - Blue-sky gradient','Position',[150 100 1100 520],'WindowStyle','alwaysontop','Visible','off');
g=uigridlayout(f,[2 1]);g.RowHeight={'1x',36};
uitextarea(g,'Editable','off','Value',splitlines(string(fileread(fullfile(folder,'sky-ramp.md')))));
uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));f.Visible='on';drawnow;focus(f);
end
