% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function layout=printFurnitureLayout(widthMm)
% Shared space budget for renderer, text and paper suggestions.
layout=struct('footerReservedMm',22,'footerCenterInsetMm',12,'bottomClearMm',8, ...
    'compact',round(widthMm,1)<240,'summaryInsetMm',17.3,'dateInsetMm',12);
if layout.compact
 layout.footerReservedMm=30;layout.footerCenterInsetMm=19;
 layout.summaryInsetMm=27;layout.dateInsetMm=10;
end
end
