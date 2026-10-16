% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function file=exportWorkflowCGATS(w,folder)
% Export the selected source measurement, never compensated profiling inputs.
assert(w.mode()~="verification",'inkprof:CGATS','Imported ICC profiles have no selected profiling measurement to export.');
source=w.output('measurement','measurement');
assert(isfile(source),'inkprof:CGATS','The selected profiling measurement is unavailable.');
file=fullfile(folder,'i1profiler-measurement.txt');
config=inkprof.paths();
inkprof.runPython(fullfile(config.Root,'exchange','export_i1profiler_cgats.py'), ...
 [source,file],WorkingDirectory=config.Root);
end
