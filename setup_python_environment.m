% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function report=setup_python_environment(mode,options)
%SETUP_PYTHON_ENVIRONMENT Maintain this program's own standardized .venv.
arguments
 mode (1,1) string="ensure"
 options.BootstrapPython (1,1) string=""
 options.TimeoutSeconds (1,1) double=900
end
root=string(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
report=inkprof.internal.ensurePython(Mode=mode,BootstrapPython=options.BootstrapPython,TimeoutSeconds=options.TimeoutSeconds);
end
