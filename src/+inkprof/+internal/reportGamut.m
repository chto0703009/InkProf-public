% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function ref=reportGamut(profile,folder,includeDeviceRGB)
if nargin<3,includeDeviceRGB=false;end
% Surface generation is optional; failure never changes verification status.
ref=struct('status',"unavailable",'reason',"");
[guard,~]=inkprof.internal.calculationProgress("ICC gamut","Calculating the ICC gamut surface..."); %#ok<ASGLU>
try
 config=inkprof.paths();bin=inkprof.internal.argyllBin("");suffix="";if ispc,suffix=".exe";end
 args=[string(profile),string(folder),fullfile(bin,"iccgamut"+suffix)];modules=["numpy","colour"];
 if includeDeviceRGB,args(end+1)="--device-rgb";modules(end+1)="scipy";end
 inkprof.runPython(fullfile(config.Root,'analysis','gamut_surface.py'),args, ...
  RequiredModules=modules,WorkingDirectory=config.Root,TimeoutSeconds=400);
 ref=jsondecode(fileread(fullfile(folder,'gamut-reference.json')));
catch err
 ref.reason=string(err.message);
end
end
