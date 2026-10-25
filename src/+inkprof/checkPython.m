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
if options.PythonExecutable==""
    runtime=inkprof.internal.ensurePython();
    options.PythonExecutable=string(runtime.Executable);
end
executable=inkprof.internal.pythonExecutable(options.PythonExecutable);
assert(executable~=""&&isfile(executable),'inkprof:PythonMissing', ...
    'Python is unavailable. Create .venv in the InkProf root or configure PythonExecutable with setupInkProf.');
folder=string(tempname);mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s'));
paths=inkprof.paths();output=fullfile(folder,'runtime.json');
script=fullfile(paths.Root,'bridge','check_python_runtime.py');
try
    inkprof.internal.runTool(executable,[script,output,options.RequiredModules],folder,60);
    data=jsondecode(fileread(output));
catch failure
    exception=MException('inkprof:PythonCheck','Cannot validate Python at %s: %s',executable,failure.message);
    throwAsCaller(exception);
end
assert(data.version(1)==3&&data.version(2)>=10,'inkprof:PythonVersion','Python 3.10 or later (3.x) is required.');
assert(isempty(data.missing),'inkprof:PythonModules', ...
    'Missing Python modules: %s. Install requirements-report.txt in the selected environment: %s', ...
    strjoin(string(data.missing),', '),repairCommand(executable,paths.Root,false));
if ~isempty(data.failures)
    details=strjoin(string({data.failures.message}),newline);
    scipyFailure=any(string({data.failures.module})=="scipy") || contains(details,"__thread_bss");
    if scipyFailure
        advice="SciPy cannot load its compiled libraries. On macOS, __thread_bss / non-zero offset is a known binary compatibility problem. InkProf now uses SciPy 1.16.3, which passed the reported M4 import test.";
    else
        advice="A required Python package is installed but cannot be imported.";
    end
    error('inkprof:PythonImport','%s\nSelected Python: %s\nRepair in Terminal:\n%s\nThen run setupInkProf(CheckPython=true) in MATLAB and retry.\nDetails: %s', ...
        advice,executable,repairCommand(executable,paths.Root,scipyFailure),details);
end
report=struct('executable',executable,'reportedExecutable',string(data.executable), ...
    'prefix',string(data.prefix),'basePrefix',string(data.basePrefix), ...
    'version',double(data.version(:)'),'requiredModules',options.RequiredModules,'passed',true);
end

function command=repairCommand(executable,root,scipyOnly)
% Display commands for the selected environment; never install automatically.
if ispc
    quote=@(value) """"+string(value)+"""";
else
    quote=@(value) "'"+replace(string(value),"'","'""'""'")+"'";
end
python=quote(executable);
if scipyOnly
    install=python+" -m pip install --upgrade --force-reinstall --no-cache-dir --only-binary=:all: scipy==1.16.3";
else
    install=python+" -m pip install -r "+quote(fullfile(root,'requirements-report.txt'));
end
command=install+newline+python+" -m pip check";
end
