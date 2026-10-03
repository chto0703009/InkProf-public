% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testInteriorRefinement
 tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
end
function testInteriorPointsAndParents(tc)
d=inkprof.designRGBTarget(Levels=3,MaxPoints=70,GraySteps=9,ControlCount=5,RepeatCount=3);
n=size(d.initialRGB,1);p=d.rgb(1:d.fitCount,:);
verifyEqual(tc,p(1:n,:),d.initialRGB);verifyEqual(tc,d.fitCount,62);
verifyTrue(tc,all(p(n+1:end,:)>0 & p(n+1:end,:)<1,'all'));
verifyEqual(tc,d.coverage.boundaryFitCount,sum(any(d.initialRGB==0|d.initialRGB==1,2)));
for k=n+1:d.fitCount
    parents=d.parentTetrahedra(k,:);verifyTrue(tc,all(parents<k));
    if d.insertionKinds(k)=="centroid"
        verifyEqual(tc,p(k,:),mean(p(parents,:),1),'AbsTol',1e-14);
    else
        verifyEqual(tc,d.insertionKinds(k),"circumcenter");
        radii=sqrt(sum((p(parents,:)-p(k,:)).^2,2));
        verifyEqual(tc,radii,repmat(radii(1),4,1),'AbsTol',1e-10);
        verifyEqual(tc,min(sqrt(sum((p(1:k-1,:)-p(k,:)).^2,2))),radii(1),'AbsTol',1e-10);
    end
end
verifyEqual(tc,d.history(:,2),[d.initialRefinementDistances(1);d.history(1:end-1,3)]);
verifyTrue(tc,all(diff(d.sortedRefinementDistances)<=0));
verifyEqual(tc,d.sortedRefinementDistances,inkprof.internal.nearestRGBDistance(d.candidatePoints,p));
verifyTrue(tc,all(d.parentEdges==0,'all'));
end
function testInteriorStopping(tc)
a=inkprof.designRGBTarget(Levels=2,GraySteps=0,MaxPoints=20,ControlCount=0,RepeatCount=0,MaxEdge=2);
verifyEqual(tc,a.fitCount,8);verifyEqual(tc,a.stopReason,"distance threshold");
b=inkprof.designRGBTarget(Levels=2,GraySteps=0,MaxPoints=20,ControlCount=0,RepeatCount=0);
c=inkprof.designRGBTarget(Levels=2,GraySteps=0,MaxPoints=20,ControlCount=0,RepeatCount=0);
verifyEqual(tc,b.rgb,c.rgb);verifyEqual(tc,b.coverage.boundaryFitCount,8);
verifyLessThan(tc,b.coverage.interior.max,a.coverage.interior.max);
verifyEqual(tc,b.coverage.surface.probeCount+b.coverage.interior.probeCount,33^3);
end
function test575Coverage(tc)
old=inkprof.designRGBTarget(Refinement="edge");new=inkprof.designRGBTarget();
verifyEqual(tc,new.coverage.boundaryFitCount,98);verifyEqual(tc,new.coverage.interiorFitCount,401);
verifyEqual(tc,new.fitCount,old.fitCount);
verifyLessThan(tc,new.coverage.interior.mean,old.coverage.interior.mean);
verifyLessThan(tc,new.coverage.interior.p95,old.coverage.interior.p95);
verifyLessThan(tc,new.coverage.interior.max,old.coverage.interior.max);
end

function testCubeCenter(tc)
[r,g,b]=ndgrid([0 1]);rgb=[r(:) g(:) b(:)];
[p,~,dist,kinds]=inkprof.internal.interiorCandidates(rgb);
verifyEqual(tc,p(1,:),[.5 .5 .5],'AbsTol',1e-14);
verifyEqual(tc,dist(1),sqrt(3)/2,'AbsTol',1e-14);
verifyEqual(tc,kinds(1),"circumcenter");
verifyEqual(tc,size(unique(round(p,12),'rows'),1),size(p,1));
end
function testSpherePlacementVariants(tc)
for method=["circumcenter","contained-circumcenter"]
    d=inkprof.designRGBTarget(Levels=3,GraySteps=5,MaxPoints=65,ControlCount=0,RepeatCount=0,InteriorPlacement=method);
    p=d.rgb;first=size(d.initialRGB,1)+1;
    verifyTrue(tc,any(d.insertionKinds=="circumcenter"));
    for k=first:d.fitCount
        parents=d.parentTetrahedra(k,:);
        if d.insertionKinds(k)=="circumcenter"
            radius=sqrt(sum((p(parents,:)-p(k,:)).^2,2));
            verifyEqual(tc,radius,repmat(radius(1),4,1),'AbsTol',1e-10);
            verifyEqual(tc,min(sqrt(sum((p(1:k-1,:)-p(k,:)).^2,2))),radius(1),'AbsTol',1e-10);
            if method=="contained-circumcenter"
                bary=[p(parents,:) ones(4,1)]'\[p(k,:) 1]';
                verifyGreaterThanOrEqual(tc,min(bary),-1e-9);
            end
        end
    end
end
end
