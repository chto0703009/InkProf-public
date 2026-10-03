% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function distances=nearestRGBDistance(query,rgb)
%NEARESTRGBDISTANCE Euclidean nearest-point distance without extra toolboxes.
distances=zeros(size(query,1),1);
for first=1:512:size(query,1)
    idx=first:min(first+511,size(query,1));q=query(idx,:);
    squared=zeros(numel(idx),size(rgb,1));
    for channel=1:3,squared=squared+(q(:,channel)-rgb(:,channel)').^2;end
    distances(idx)=sqrt(min(squared,[],2));
end
end
