% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function run=startMeasurement(sessionFolder,options)
%STARTMEASUREMENT Open an independent terminal measurement owned by Python.
% run=inkprof.startMeasurement(folder); then result=inkprof.finishMeasurement(run)
% Resume=true also permits rereading rows in a previously completed chart.
arguments
    sessionFolder (1,1) string
    options.ScanTolerance (1,1) double {mustBePositive,mustBeFinite} = 1
    options.Direction (1,1) string {mustBeMember(options.Direction,["auto","forward","both"])} = "auto"
    options.Resume (1,1) logical = false
    options.Port (1,1) double {mustBeInteger,mustBeNonnegative} = 0
    options.ArgyllBin (1,1) string = ""
    options.PythonExecutable (1,1) string = ""
    options.OpenTerminal (1,1) logical = true
end
assert(isunix,'inkprof:Platform','Terminal measurement currently supports macOS/Linux.');
if options.OpenTerminal
    assert(ismac,'inkprof:Platform','On Linux use OpenTerminal=false and run the launcher in your terminal.');
end
folder=inkprof.internal.absolutePath(sessionFolder);
bin=inkprof.internal.argyllBin(options.ArgyllBin);
paths=inkprof.paths();args=["prepare",folder,fullfile(bin,'chartread')];
args=[args,"--scan-tolerance",compose("%.17g",options.ScanTolerance),"--direction",options.Direction];
if options.Resume,args(end+1)="--resume";end
if options.Port>0,args=[args,"--port",string(options.Port)];end
output=inkprof.runPython(fullfile(paths.Root,'bridge','measure_chart.py'),args, ...
    PythonExecutable=options.PythonExecutable);
run=jsondecode(output.output);
if options.OpenTerminal
    inkprof.internal.runTool('/usr/bin/open',["-a","Terminal",string(run.launcher)],folder,15);
end
fprintf('InkProf: mätningen sker i Terminal. Inga poll/sendKey behövs.\n');
fprintf('Efter sparning: result=inkprof.finishMeasurement(run);\n');
end
