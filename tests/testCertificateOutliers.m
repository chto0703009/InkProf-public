function tests=testCertificateOutliers
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
end
function testThresholdIdentitySortingAndNoTruncation(tc)
p=struct('sampleId',"a",'coordinate',"A1",'page',1,'role',"colour",'deltaE00',5,'measuredLab',[50 0 0]);
patches=repmat(p,1,43);
for i=1:43,patches(i).sampleId=string(i);patches(i).deltaE00=5+i/10;end
patches(1).deltaE00=5;patches(2).deltaE00=4;
patches(3).role="repeat";patches(4).role="paperwhite";patches(5).role="challenge";
r=inkprof.internal.certificatePatchOutliers(struct('patches',patches));
verifyTrue(tc,r.available);verifyEqual(tc,r.evaluatedCount,41);verifyEqual(tc,r.count,39);
verifyEqual(tc,r.patches(1).sampleId,"43");verifyEqual(tc,r.patches(end).sampleId,"5");
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
function testSRGBPreview(tc)
[rgb,clipped]=inkprof.internal.labD50ToSRGB([0 0 0;100 0 0;50 200 200]);
verifyEqual(tc,rgb(1,:),[0 0 0],'AbsTol',1e-8);verifyEqual(tc,rgb(2,:),[1 1 1],'AbsTol',.001);
verifyTrue(tc,clipped(3));
end
