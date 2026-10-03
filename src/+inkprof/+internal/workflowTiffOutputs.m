% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function out=workflowTiffOutputs(target)
% Expose every TIFF page as a deliverable, retaining TI2 for instrument input.
folder=fileparts(target);listing=[dir(fullfile(folder,'*.tif'));dir(fullfile(folder,'*.tiff'))];
assert(~isempty(listing),'inkprof:Workflow','The saved target contains no TIFF16 files.');
[~,order]=sort(string({listing.name}));listing=listing(order);
out=struct;
for k=1:numel(listing),out.("TIFF16_sida_"+k)=string(fullfile(listing(k).folder,listing(k).name));end
out.target=target;
end
