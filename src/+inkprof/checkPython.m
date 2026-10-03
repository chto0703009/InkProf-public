% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function report=checkPython(options)
%CHECKPYTHON Validate the optional external Python runtime, only on demand.
arguments
    options.PythonExecutable (1,1) string = ""
    options.RequiredModules (1,:) string = strings(1,0)
end
executable=inkprof.internal.pythonExecutable(options.PythonExecutable);
assert(executable~=""&&isfile(executable),'inkprof:PythonMissing', ...
    'Python is unavailable. Create .venv in the InkProf root or configure PythonExecutable with setupInkProf.');
folder=string(tempname);mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s'));
code="import sys,json,importlib.util; print(json.dumps({'version':list(sys.version_info[:3]),'executable':sys.executable,'prefix':sys.prefix,'basePrefix':sys.base_prefix,'missing':[m for m in sys.argv[1:] if importlib.util.find_spec(m) is None]}))";
try
    result=inkprof.internal.runTool(executable,["-c",code,options.RequiredModules],folder,30);
    data=jsondecode(result.output);
catch error
    exception=MException('inkprof:PythonCheck','Cannot validate Python at %s: %s',executable,error.message);
    throwAsCaller(exception);
end
assert(data.version(1)==3&&data.version(2)>=10,'inkprof:PythonVersion','Python 3.10 or later (3.x) is required.');
assert(isempty(data.missing),'inkprof:PythonModules','Missing Python modules: %s. Install bridge requirements in the selected environment.',strjoin(string(data.missing),', '));
report=struct('executable',executable,'reportedExecutable',string(data.executable), ...
    'prefix',string(data.prefix),'basePrefix',string(data.basePrefix), ...
    'version',double(data.version(:)'),'requiredModules',options.RequiredModules,'passed',true);
end
