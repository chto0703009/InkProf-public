% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function info=measurementPage(chart,pass,pairedPlan)
% Map chartread's logical pass to the printed page and row.
arguments
 chart (1,1) struct
 pass (1,1) double {mustBeInteger,mustBePositive}
 pairedPlan (1,1) struct = struct
end
counts=double(chart.passesInStrips(:)');
if ~isempty(fieldnames(pairedPlan))
 assert(pass<=numel(pairedPlan.passes),'inkprof:Layout','Pass outside paired plan.');
 p=pairedPlan.passes(pass);page=p.page;row=string(p.physicalRow);local=p.rowOnPage;
else
 assert(pass<=sum(counts),'inkprof:Layout','Pass outside chart.');
 page=find(pass<=cumsum(counts),1);local=pass-sum(counts(1:page-1));
 % TI2 records can be in source/random order. chartread traverses physical
 % locations, so derive row labels from coordinates, never record offsets.
 labels=regexp(cellstr(string({chart.patches.sampleLoc})),'^\d+','match','once');
 numbers=str2double(string(labels));
 assert(all(isfinite(numbers)),'inkprof:Layout','Invalid physical row labels.');
 physicalRows=unique(numbers,'sorted');
 assert(numel(physicalRows)==sum(counts),'inkprof:Layout','Physical row count differs from pass count.');
 row=string(physicalRows(pass));
end
info=struct('page',page,'totalPages',numel(counts),'row',row,'rowOnPage',local);
end
