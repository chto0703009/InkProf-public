% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [files,report]=iccOutputVersion(profile,version,options)
%ICCOUTPUTVERSION Deliver a colprof RGB profile as ICC v2, v4.4 or both.
% colprof writes ICC v2 only. "v4" and "both" write <name>-v4.icc and
% <name>-v4-report.json beside the built profile via profiles/icc_v2_to_v4.py.
% The v2 file is never modified: job hashes and inspection refer to it, and
% Argyll steps (profcheck, refinement) need v2.
%   files: the profile(s) to deliver - v2: the profile; v4: the -v4 file;
%          both: [v2; v4].
arguments
 profile (1,1) string
 version (1,1) string {mustBeMember(version,["v2","v4","both"])}
 options.B2AGrid (1,1) string {mustBeMember(options.B2AGrid,["fine","same"])} = "fine"
 options.PythonExecutable (1,1) string = ""
end
profile=inkprof.internal.absolutePath(profile);
assert(isfile(profile),'inkprof:ICC','Profile not found: %s',profile);
files=profile;report=struct([]);
if version=="v2",return;end
paths=inkprof.paths();[folder,name,ext]=fileparts(profile);
target=fullfile(folder,name+"-v4"+ext);reportFile=fullfile(folder,name+"-v4-report.json");
sourceHash=inkprof.internal.sha256(profile);
inkprof.runPython(fullfile(paths.Root,'profiles','icc_v2_to_v4.py'), ...
 [profile,target,"--b2a-grid",options.B2AGrid,"--report",reportFile], ...
 PythonExecutable=options.PythonExecutable,RequiredModules="numpy", ...
 WorkingDirectory=folder,TimeoutSeconds=300);
report=jsondecode(fileread(reportFile));
assert(inkprof.internal.sha256(profile)==sourceHash&&string(report.inputSHA256)==sourceHash, ...
 'inkprof:Integrity','ICC v2 profile changed during v4 conversion.');
assert(isfile(target)&&inkprof.internal.sha256(target)==string(report.outputSHA256), ...
 'inkprof:Integrity','ICC v4 output does not match its report.');
assert(isempty(report.problems),'inkprof:ICC','ICC v4 checks failed: %s', ...
 strjoin(string(report.problems),'; '));
if version=="v4",files=target;else,files=[profile;target];end
fprintf(['InkProf ICC v4.4: %s\nPerceptual black L* %.2f (A2B0) / %.2f (B2A0) -> 3.14; ' ...
 'colorimetric tables unchanged.\n'],target,report.v2BlackLstar.A2B0,report.v2BlackLstar.B2A0);
end
