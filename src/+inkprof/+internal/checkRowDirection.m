% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function check=checkRowDirection(folder,result)
% Diagnostic failure must not prevent saving the measured data.
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
try
 input=fullfile(w,'measurement.json');output=fullfile(w,'check.json');
 inkprof.internal.writeJson(input,result);paths=inkprof.paths();
 inkprof.runPython(fullfile(paths.Root,'analysis','row_direction_check.py'), ...
  [fullfile(folder,'chart.json'),input,output],RequiredModules=["numpy","colour"]);
 check=jsondecode(fileread(output));
catch err
 check=struct('available',false,'reason',string(err.message));
end
end
