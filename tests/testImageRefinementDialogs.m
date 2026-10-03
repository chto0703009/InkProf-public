function tests=testImageRefinementDialogs
tests=functiontests(localfunctions);
end
function testSelectionAndPreview(tc)
p=string(tempname)+".png";imwrite(uint8(ones(10,20,3)*100),p);c=onCleanup(@()delete(p));
t=timer('ExecutionMode','fixedSpacing','Period',0.2,'TimerFcn',@acceptSelection);cleanup=onCleanup(@()stopTimer(t));start(t);
d=struct('ROI',[2 3 5 4],'MaxNewPatches',12,'MinSpacingPercent',1,'NeighborRadiusPercent',0);
s=inkprof.internal.imageRefinementDialog(p,d,"sRGB");
verifyEqual(tc,s.ROI,d.ROI);verifyEqual(tc,s.MaxNewPatches,12);
end
function testCandidateReview(tc)
r=struct('candidates',struct('patchId',"IMG-0001",'rgbPercent',[10;20;30],'pixelCount',5,'sourceMappingDeltaE00',1,'kind',"image-colour",'previewRGB',[.2;.3;.4]),'excludedNearExistingOrDuplicate',2);
r.fitEstimates=struct('available',true,'summary',struct('mean',1,'p95',2,'max',3));
r.candidates.estimatedLocalFitDeltaE00=1.25;r.candidates.localFitSupportCount=4;r.candidates.nearestFitRGBDistancePercent=2;
t=timer('ExecutionMode','fixedSpacing','Period',0.2,'TimerFcn',@acceptReview);cleanup=onCleanup(@()stopTimer(t));start(t);
selected=inkprof.internal.reviewImageCandidates(r);verifyEqual(tc,selected,1);
end
function acceptSelection(~,~)
b=findall(groot,'Type','uibutton','Text','Propose patches');if ~isempty(b),feval(b(1).ButtonPushedFcn,b(1),[]);end
end
function acceptReview(~,~)
b=findall(groot,'Type','uibutton','Text','Create TIFF16 target');if ~isempty(b),feval(b(1).ButtonPushedFcn,b(1),[]);end
end
function stopTimer(t)
stop(t);delete(t);
end
