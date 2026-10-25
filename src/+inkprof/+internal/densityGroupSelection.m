% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function selected=densityGroupSelection(report,groups)
% Apply balancing only to checked groups; all other measured rows stay in use.
groups=double(groups(:));assert(all(groups>=1&groups<=numel(report.groups)&groups==floor(groups))&&numel(unique(groups))==numel(groups), ...
 'inkprof:Density','Invalid selected groups.');
keep=true(report.originalCount,1);
for k=groups'
 a=report.groups(k);keep(setdiff(a.rows,a.retainedRows))=false;
end
keep(report.protectedRows)=true;
selected=report;selected.automaticSelectedRows=report.selectedRows;
selected.selectedRows=find(keep);selected.retainedCount=nnz(keep);selected.omittedCount=report.originalCount-nnz(keep);
selected.groupSelection=struct('selectedGroups',groups,'totalGroups',numel(report.groups),'basis',"Checked groups use automatic representatives; unchecked groups retain all measured rows. Protected observations always retained.");
end
