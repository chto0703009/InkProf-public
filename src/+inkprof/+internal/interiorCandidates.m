% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [points,parents,distances,kinds]=interiorCandidates(rgb,placement)
%INTERIORCANDIDATES Rank interior empty-sphere centers and centroid fallbacks.
arguments
    rgb (:,3) double
    placement (1,1) string {mustBeMember(placement,["circumcenter","centroid","contained-circumcenter"])} = "circumcenter"
end
t=delaunayTriangulation(rgb);parents=sort(t.ConnectivityList,2);
points=(rgb(parents(:,1),:)+rgb(parents(:,2),:)+rgb(parents(:,3),:)+rgb(parents(:,4),:))/4;
kinds=repmat("centroid",size(points,1),1);
if placement~="centroid"
    centers=circumcenter(t);
    centerParents=parents;
    if placement=="contained-circumcenter"
        bary=cartesianToBarycentric(t,(1:size(centers,1))',centers);
        keep=all(bary>=-1e-10,2);centers=centers(keep,:);centerParents=centerParents(keep,:);
    end
    points=[centers;points];parents=[centerParents;parents];
    kinds=[repmat("circumcenter",size(centers,1),1);kinds];
end
% An empty-sphere center may be outside its defining tetrahedron. Accept it
% only inside the cube. Parents identify the sphere, not a containing element.
keep=all(isfinite(points) & points>1e-10 & points<1-1e-10,2);
points=points(keep,:);parents=parents(keep,:);kinds=kinds(keep);
% Co-spherical tetrahedra can yield the same center. Retain one reproducibly.
[~,uniqueRows]=unique(round(points,12),'rows','stable');
points=points(uniqueRows,:);parents=parents(uniqueRows,:);kinds=kinds(uniqueRows);
distances=inkprof.internal.nearestRGBDistance(points,rgb);
keep=distances>1e-10;points=points(keep,:);parents=parents(keep,:);kinds=kinds(keep);distances=distances(keep);
[~,order]=sortrows([-distances points parents]);
points=points(order,:);parents=parents(order,:);distances=distances(order);kinds=kinds(order);
end
