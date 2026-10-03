% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function check=checkPairedReadings(result,threshold)
% Keep analysis failures separate from successful measurement saving.
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
input=fullfile(w,'input.json');output=fullfile(w,'result.json');
inkprof.internal.writeJson(input,result);paths=inkprof.paths();
try
 inkprof.runPython(fullfile(paths.Root,'analysis','paired_check.py'), ...
  [input,output,"--threshold",string(threshold)],RequiredModules=["numpy","colour"]);
 check=jsondecode(fileread(output));check.available=true;
catch err
 check=struct('available',false,'threshold',threshold,'reason',string(err.message));
end
end
