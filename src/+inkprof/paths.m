% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function paths=paths()
%PATHS Resolve paths from the code location, never a developer's home folder.
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
paths=struct('Root',root,'Source',fullfile(root,'src'),'Projects',fullfile(root,'projects'), ...
    'Examples',fullfile(root,'examples'),'Tests',fullfile(root,'tests'), ...
    'LocalConfig',fullfile(root,'local-config','settings.json'),'ArgyllBin',"",'ArgyllConfigLegacy',false,'PythonConfigured',"",'PythonExecutable',"");
if isfile(paths.LocalConfig)
    config=jsondecode(fileread(paths.LocalConfig));
    assert(isfield(config,'schemaVersion')&&config.schemaVersion==1,'inkprof:Config','Unsupported local configuration version.');
    if isfield(config,'pythonExecutable'),paths.PythonConfigured=string(config.pythonExecutable);end
    if isfield(config,'argyllBin')
        paths.ArgyllBin=string(config.argyllBin);
        paths.ArgyllConfigLegacy=~isfield(config,'argyllBinSource');
    end
end
paths.PythonExecutable=inkprof.internal.pythonExecutable("",root,paths.PythonConfigured);
end
