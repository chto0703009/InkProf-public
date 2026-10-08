% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function report=estimateMeasurementNoise(inputFolder)
%ESTIMATEMEASUREMENTNOISE Noise of a locked B1 input and an approximate colprof -r.
%   r = inkprof.estimateMeasurementNoise(b1Folder)
% Print/position noise comes from patches with identical RGB at different
% chart positions; instrument repeatability from paired scans, if present.
% Reports an approximate colprof -r. Nothing is written to B1.
arguments
 inputFolder (1,1) string
end
inputFolder=inkprof.internal.absolutePath(inputFolder);
if isfile(inputFolder),inputFolder=fileparts(inputFolder);end
assert(isfile(fullfile(inputFolder,'profiling.ti3')),'inkprof:Noise','Select a B1 profile-input folder.');
paths=inkprof.paths();w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
inkprof.runPython(fullfile(paths.Root,'profiles','noise_report.py'), ...
 [inputFolder,fullfile(w,'noise.json')],RequiredModules="numpy",TimeoutSeconds=300);
report=jsondecode(fileread(fullfile(w,'noise.json')));
n=report.printNoise;
fprintf('\nInkProf measurement noise (%d patches)\n',report.patchCount);
if n.groups>0
 fprintf('  Repeated colours at different positions: %d groups, %d pairs\n',n.groups,n.pairs);
 fprintf('  Pair difference dE00: median %.3f, mean %.3f, max %.3f\n',n.pairDeltaE00.median,n.pairDeltaE00.mean,n.pairDeltaE00.max);
 fprintf('  Noise per reading: sigma %.3f Lab units\n',n.sigmaLab);
 if n.groups<5,fprintf('  Too few repeated colours for a reliable estimate; add Extra repeat patches (30-50).\n');end
else
 fprintf('  No repeated colours in this input: noise cannot be estimated. Add Extra repeat patches to the target.\n');
end
if ~isempty(report.instrumentRepeatability)
 r=report.instrumentRepeatability.pairDeltaE00;
 fprintf('  Instrument repeatability (paired scans): median %.3f, p95 %.3f dE00 (lower bound)\n',r.median,r.p95);
end
if ~isempty(report.argyllAvgdevSuggestion)
 a=report.argyllAvgdevSuggestion;fprintf('  Approximate colprof -r: %.2f %% (Argyll default 0.5 %%; rough Lab-to-percent mapping)\n\n',a.suggestedPercent);
end
end
