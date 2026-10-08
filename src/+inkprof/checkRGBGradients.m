% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [report,reportFile]=checkRGBGradients(jobFolder,options)
%CHECKRGBGRADIENTS Evaluate device RGB ramps through a completed ICC profile.
arguments
 jobFolder (1,1) string = ""
 options.ShowDialog (1,1) logical = true
end
report=[];reportFile="";
if jobFolder==""
 p=uigetdir(pwd,'Select ICC job folder');if isequal(p,0),return;end;jobFolder=string(p);
end
jobFolder=inkprof.internal.absolutePath(jobFolder);
if options.ShowDialog
 inkprof.internal.rgbGradientDialog(jobFolder);return
end
paths=inkprof.paths();status=jsondecode(fileread(fullfile(jobFolder,'status.json')));
profile=fullfile(jobFolder,'result','profile.icc');
assert(string(status.status)=="succeeded"&&isfile(profile)&&inkprof.internal.sha256(profile)==string(status.profileSHA256), ...
 'inkprof:RGBGradient','Select a successful, unchanged ICC job.');
bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'xicclu');if ispc,exe=exe+".exe";end
assert(isfile(exe),'inkprof:Argyll','xicclu not found.');
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
inkprof.runPython(fullfile(paths.Root,'analysis','rgb_gradients.py'),[profile,exe,fullfile(w,'report')], ...
 RequiredModules=["numpy","scipy"],TimeoutSeconds=300);
report=jsondecode(fileread(fullfile(w,'report','rgb-gradients.json')));
parent=fullfile(jobFolder,'checks');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,string(java.util.UUID.randomUUID()));
[ok,msg]=movefile(fullfile(w,'report'),folder);assert(ok,'inkprof:IO','%s',msg);
reportFile=fullfile(folder,'rgb-gradients.json');
inkprof.internal.recordProjectStep(folder,"RGB gradient diagnostic (numerical only)");
fprintf('InkProf RGB gradient report: %s\n',reportFile);
end
