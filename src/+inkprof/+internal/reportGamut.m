% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function ref=reportGamut(profile,folder)
% Surface generation is optional; failure never changes verification status.
ref=struct('status',"unavailable",'reason',"");
[guard,~]=inkprof.internal.calculationProgress("ICC gamut","Calculating the ICC gamut surface..."); %#ok<ASGLU>
try
 config=inkprof.paths();bin=inkprof.internal.argyllBin("");suffix="";if ispc,suffix=".exe";end
 inkprof.runPython(fullfile(config.Root,'analysis','gamut_surface.py'), ...
  [string(profile),string(folder),fullfile(bin,"iccgamut"+suffix)], ...
  RequiredModules=["numpy","colour"],WorkingDirectory=config.Root,TimeoutSeconds=220);
 ref=jsondecode(fileread(fullfile(folder,'gamut-reference.json')));
catch err
 ref.reason=string(err.message);
end
end
