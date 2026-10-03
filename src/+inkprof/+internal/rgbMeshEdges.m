% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [pairs,lengths]=rgbMeshEdges(rgb)
%RGBMESHEDGES Sorted local Delaunay edges, not all pairwise distances.
t=delaunayTriangulation(double(rgb));pairs=edges(t);
lengths=sqrt(sum((rgb(pairs(:,1),:)-rgb(pairs(:,2),:)).^2,2));
[~,order]=sortrows([-lengths pairs],[1 2 3]);pairs=pairs(order,:);lengths=lengths(order);
end
