% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function dialog=measureChart(ti2Path,options)
%MEASURECHART Open the complete modal measurement workflow; no instrument starts yet.
arguments
    ti2Path (1,1) string = ""
    options.SessionFolder (1,1) string = ""
    options.ArgyllBin (1,1) string = ""
    options.PythonExecutable (1,1) string = ""
    options.PairedWarningDeltaE (1,1) double {mustBePositive,mustBeFinite} = 1
    options.ScanTolerance (1,1) double {mustBePositive,mustBeFinite} = 1
    options.ScanMode (1,1) string {mustBeMember(options.ScanMode,["","single","alternating","paired"])} = ""
    options.Direction (1,1) string {mustBeMember(options.Direction,["auto","forward","both"])} = "both"
    options.Condition (1,1) string {mustBeMember(options.Condition,["M0","default"])} = "M0"
    options.Port (1,1) double {mustBeInteger,mustBeNonnegative} = 0
end
dialog=inkprof.MeasurementDialog(options.SessionFolder,Source=ti2Path, ...
    ArgyllBin=options.ArgyllBin,PythonExecutable=options.PythonExecutable, ...
    ScanTolerance=options.ScanTolerance,Direction=options.Direction,Port=options.Port,Condition=options.Condition,ScanMode=options.ScanMode,PairedWarningDeltaE=options.PairedWarningDeltaE);
end
