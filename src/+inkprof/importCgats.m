% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function document=importCgats(path)
%IMPORTCGATS Preserve all CGATS tables, field values and ordered metadata.
% No scale inference, colour conversion, reordering or patch deduplication.
arguments
    path (1,1) string
end
assert(isfile(path),'inkprof:Input','File does not exist: %s',path);
path=inkprof.internal.absolutePath(path);raw=fileread(path);
document=struct('schemaVersion',1,'documentType',"inkprof.cgats", ...
    'sourcePath',path,'sourceSHA256',inkprof.internal.sha256(path), ...
    'rawText',raw,'tables',inkprof.internal.parseCgats(raw));
end
