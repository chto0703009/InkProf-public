% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testCertificateOutliers
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
end
function testThresholdIdentitySortingAndNoTruncation(tc)
p=struct('sampleId',"a",'coordinate',"A1",'page',1,'role',"colour",'deltaE00',5,'measuredLab',[50 0 0],'desiredLab',[60 0 0],'predictedLab',[55 0 0]);
patches=repmat(p,1,43);
for i=1:43,patches(i).sampleId=string(i);patches(i).deltaE00=5+i/10;end
patches(1).deltaE00=5;patches(2).deltaE00=4;
patches(3).role="repeat";patches(4).role="paperwhite";patches(5).role="challenge";
r=inkprof.internal.certificatePatchOutliers(struct('patches',patches));
verifyTrue(tc,r.available);verifyEqual(tc,r.evaluatedCount,41);verifyEqual(tc,r.count,39);
verifyEqual(tc,r.patches(1).sampleId,"43");verifyEqual(tc,r.patches(end).sampleId,"5");
verifyNotEqual(tc,r.patches(1).desiredHex,r.patches(1).hex);
verifyNotEqual(tc,r.patches(1).predictedHex,r.patches(1).hex);
verifyEqual(tc,r.patches(end).role,"challenge");verifyEqual(tc,r.isoCompliance,"not-assessed");
verifyTrue(tc,all(vertcat(r.patches.sRGB8)>=0,'all'));verifyTrue(tc,all(vertcat(r.patches.sRGB8)<=255,'all'));
end
function testEmptyMissingAndSingle(tc)
r=inkprof.internal.certificatePatchOutliers(struct);verifyFalse(tc,r.available);
p=struct('sampleId',"x",'coordinate',"B2",'page',2,'role',"gray",'deltaE00',5,'measuredLab',[100 0 0]);
r=inkprof.internal.certificatePatchOutliers(struct('patches',p));verifyTrue(tc,r.available);verifyEqual(tc,r.count,0);
p.deltaE00=5.00001;r=inkprof.internal.certificatePatchOutliers(struct('patches',p));verifyEqual(tc,r.count,1);verifyEqual(tc,r.patches.coordinate,"B2");
p.deltaE00=NaN;verifyError(tc,@()inkprof.internal.certificatePatchOutliers(struct('patches',p)),'inkprof:FinalReport');
end
function testReferenceNamesSurvive(tc)
p=struct('sampleId',"1",'referenceName',"A1",'coordinate',"B2",'page',1,'role',"colour",'deltaE00',1.25,'measuredLab',[50 0 0]);
r=inkprof.internal.certificatePatchOutliers(struct('patches',p));
verifyEqual(tc,r.allPatches.referenceName,"A1");verifyEqual(tc,r.allPatches.deltaE00,1.25);
end
function testSRGBPreview(tc)
[rgb,clipped]=inkprof.internal.labD50ToSRGB([0 0 0;100 0 0;50 200 200]);
verifyEqual(tc,rgb(1,:),[0 0 0],'AbsTol',1e-8);verifyEqual(tc,rgb(2,:),[1 1 1],'AbsTol',.001);
verifyTrue(tc,clipped(3));
end

function testReachabilityIsNotPhysicalGamutProof(tc)
p=struct('sampleId',"a",'coordinate',"A1",'page',1,'role',"colour",'deltaE00',6,'predictedDeltaE00',.5,'measuredLab',[50 0 0],'gamutAssessment',"model-reachable");
q=p;q.sampleId="b";q.role="challenge";q.gamutAssessment="outside-or-inversion-unresolved";q.deltaE00=30;
r=inkprof.internal.certificatePatchOutliers(struct('patches',[p q]));
verifyTrue(tc,contains(r.contextText,'model-reachable: 1 unique patches'));
verifyTrue(tc,contains(r.contextText,'not confirmed outside the physical gamut'));
verifyTrue(tc,contains(r.patches(1).reachabilityLabel,'Challenge colour'));
verifyEqual(tc,r.patches(2).predictedDeltaE00,.5);
end

function testOverviewIncludesGoodColoursAndExactBoundaries(tc)
p=struct('sampleId',"a",'coordinate',"A1",'page',1,'role',"colour",'deltaE00',0,'measuredLab',[50 0 0]);
patches=repmat(p,1,6);v=[0 1 2 5 6 100];
for k=1:6,patches(k).deltaE00=v(k);end
patches(6).role="repeat";
r=inkprof.internal.certificatePatchOutliers(struct('patches',patches));
verifyEqual(tc,[r.distribution.count],[2 1 1 1]);
verifyEqual(tc,numel(r.allPatches),5);verifyEqual(tc,r.count,1);
verifyEqual(tc,sum([r.distribution.percent]),100,'AbsTol',1e-10);
end
