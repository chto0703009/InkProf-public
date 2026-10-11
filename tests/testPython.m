% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testPython
tests=functiontests(localfunctions);
end
function testDiscovery(tc)
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
verifyEqual(tc,inkprof.internal.pythonExecutable("",w,""),"");
if ispc,p=fullfile(w,'.venv','Scripts','python.exe');else,p=fullfile(w,'.venv','bin','python');end
mkdir(fileparts(p));fid=fopen(p,'w');fclose(fid);
verifyEqual(tc,inkprof.internal.pythonExecutable("",w,""),p);
verifyEqual(tc,inkprof.internal.pythonExecutable("custom/python",w,""),fullfile(w,'custom','python'));
verifyEqual(tc,inkprof.internal.pythonExecutable("",w,"missing/python"),fullfile(w,'missing','python'));
verifyError(tc,@()inkprof.checkPython(PythonExecutable=fullfile(w,'missing')),'inkprof:PythonMissing');
end
function testRuntime(tc)
executable=string(getenv('INKPROF_TEST_PYTHON'));
assumeTrue(tc,executable~="",'Set INKPROF_TEST_PYTHON to run real process tests.');
r=inkprof.checkPython(PythonExecutable=executable,RequiredModules=["json","sys"]);verifyTrue(tc,r.passed);
r=inkprof.checkPython(PythonExecutable=executable,RequiredModules="scipy");verifyTrue(tc,r.passed);
verifyError(tc,@()inkprof.checkPython(PythonExecutable=executable,RequiredModules="inkprof_missing_module_test"),'inkprof:PythonModules');
w=string(tempname)+" space";mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
f=fullfile(w,'echo script.py');fid=fopen(f,'w');fprintf(fid,'import sys,json\nprint(json.dumps(sys.argv[1:]))\n');fclose(fid);
a=["space in argument","literal $HOME ; &"];
r=inkprof.runPython(f,a,PythonExecutable=executable,WorkingDirectory=w);
verifyEqual(tc,string(jsondecode(r.output)),a(:));
end

function testBrokenScipyGivesRepairForSelectedPython(tc)
executable=string(getenv('INKPROF_TEST_PYTHON'));
assumeTrue(tc,executable~="",'Set INKPROF_TEST_PYTHON to run real process tests.');
w=string(tempname);mkdir(fullfile(w,'scipy'));cleanup=onCleanup(@()rmdir(w,'s'));
fid=fopen(fullfile(w,'scipy','__init__.py'),'w');fclose(fid);
fid=fopen(fullfile(w,'scipy','spatial.py'),'w');
fprintf(fid,'raise ImportError("__thread_bss has a zero-fill section type, but offset field is not zero")\n');fclose(fid);
old=getenv('PYTHONPATH');restore=onCleanup(@()setenv('PYTHONPATH',old));setenv('PYTHONPATH',w);
try
    inkprof.checkPython(PythonExecutable=executable,RequiredModules="scipy");
    verifyFail(tc,'The broken compiled import must stop analysis.');
catch failure
    verifyEqual(tc,failure.identifier,'inkprof:PythonImport');
    verifySubstring(tc,failure.message,'scipy==1.16.3');
    verifySubstring(tc,failure.message,char(executable));
    verifySubstring(tc,failure.message,'__thread_bss');
end
end

function testVenvLauncherIsPreserved(tc)
p=inkprof.paths();
if ispc,exe=fullfile(p.Root,'.venv','Scripts','python.exe');else,exe=fullfile(p.Root,'.venv','bin','python');end
assumeTrue(tc,isfile(exe),'Local .venv is optional.');
r=inkprof.checkPython(PythonExecutable=exe);
verifyEqual(tc,r.executable,exe);
verifyEqual(tc,r.prefix,fullfile(p.Root,'.venv'));
verifyNotEqual(tc,r.prefix,r.basePrefix);
end
