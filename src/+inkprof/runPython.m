% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function result=runPython(scriptPath,args,options)
%RUNPYTHON Run a bridge script with the selected runtime and direct argv.
arguments
    scriptPath (1,1) string
    args (1,:) string = strings(1,0)
    options.PythonExecutable (1,1) string = ""
    options.RequiredModules (1,:) string = strings(1,0)
    options.WorkingDirectory (1,1) string = string(pwd)
    options.TimeoutSeconds (1,1) double {mustBePositive,mustBeFinite} = 120
end
runtime=inkprof.checkPython(PythonExecutable=options.PythonExecutable,RequiredModules=options.RequiredModules);
scriptPath=inkprof.internal.absolutePath(scriptPath);
folder=inkprof.internal.absolutePath(options.WorkingDirectory);
assert(isfile(scriptPath)&&isfolder(folder),'inkprof:PythonInput','Script or working directory does not exist.');
try
    result=inkprof.internal.runTool(runtime.executable,[scriptPath,args],folder,options.TimeoutSeconds);
catch error
    if strcmp(error.identifier,'inkprof:Timeout'),rethrow(error);end
    throwAsCaller(MException('inkprof:PythonRun','Python bridge failed: %s',error.message));
end
end
