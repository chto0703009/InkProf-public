% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Run this script from any folder. MATLAB Base + Java + ArgyllCMS.
inkprofRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(inkprofRoot);
inkprofPaths=setupInkProf();
% Choose a new output folder each time (existing packages are never replaced).
inkprof.createTarget(fullfile(inkprofPaths.Projects,'generated-100'), PatchCount=100, ...
    Randomize=true, Seed=42, DPI=300);

% Import actual i1Profiler patch definitions into a NEW Argyll chart.
inkprof.createTarget(fullfile(inkprofPaths.Projects,'imported-2033'), ...
    Source=fullfile(inkprofPaths.Tests,'fixtures','i1profiler','chart-2033','Chart 2033 Patches.txf'), ...
    Randomize=false, DPI=300);
% To retain the greater precision of the CGATS TXT reference instead:
% inkprof.createTarget('projects/imported-txt', Source='chart.txt', RGBScale=255);

report=inkprof.verifyPackage(fullfile(inkprofPaths.Projects,'generated-100'));
disp(report);
