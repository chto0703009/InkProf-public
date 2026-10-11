% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function count=referenceSetCount(file)
%REFERENCESETCOUNT Use the same parser as C2 to inspect the selected set.
output=string(tempname)+".json";
cleanup=onCleanup(@()removeOutput(output));
inkprof.runPython(fullfile(inkprof.paths().Root,'analysis','reference_sets.py'), ...
    [string(file),output]);
record=jsondecode(fileread(output));count=record.count;
assert(count>=1&&count<=2000,'inkprof:Verification','Reference set must have 1..2000 patches.');
end
function removeOutput(file)
if isfile(file),delete(file);end
end
