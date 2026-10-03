% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function prefs=paperPreferences(project)
% Defaults in JSON; each project carries its own measurement-sled limits.
paths=inkprof.paths();prefs=jsondecode(fileread(fullfile(paths.Root,'config','target-paper-defaults.json')));
if nargin>0&&project~=""
 record=jsondecode(fileread(fullfile(project,'inkprof-project.json')));
 if isfield(record,'paperLayout')
  for key=string(fieldnames(prefs))',if isfield(record.paperLayout,key),prefs.(key)=record.paperLayout.(key);end;end
 end
end
for key=string(fieldnames(prefs))'
 assert(isnumeric(prefs.(key))&&isscalar(prefs.(key))&&isfinite(prefs.(key))&&prefs.(key)>=65, ...
  'inkprof:Paper','Paper limits must be finite numbers of at least 65 mm.');
end
end
