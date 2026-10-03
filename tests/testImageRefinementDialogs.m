function tests=testImageRefinementDialogs
tests=functiontests(localfunctions);
end
function teardown(~)
delete(findall(groot,'Name','InkProf - Review image patches'));
delete(findall(groot,'Name','InkProf - Select image colours'));
end
function testSelectionAndPreview(tc)
p=string(tempname)+".png";imwrite(uint8(ones(10,20,3)*100),p);c=onCleanup(@()delete(p));
cleanup=clickLater(@(~,~)click('Propose patches'));
d=struct('ROI',[2 3 5 4],'MaxNewPatches',12,'MinSpacingPercent',1,'NeighborRadiusPercent',0);
s=inkprof.internal.imageRefinementDialog(p,d,"sRGB");clear cleanup;
verifyEmpty(tc,findall(groot,'Name','InkProf - Select image colours'));verifyEqual(tc,s.ROI,d.ROI);verifyEqual(tc,s.MaxNewPatches,12);
end
function testCandidateDefaultFilterAndClose(tc)
r=fixture();cleanup=clickLater(@(~,~)click('Create TIFF16 target'));
[selected,filter]=inkprof.internal.reviewImageCandidates(r);clear cleanup;
verifyEqual(tc,selected,3);verifyEqual(tc,filter.threshold,5);verifyEqual(tc,filter.metric,"estimatedLocalFitDeltaE00");
verifyEmpty(tc,findall(groot,'Name','InkProf - Review image patches'));
end
function testCancelCloses(tc)
cleanup=clickLater(@(~,~)click('Cancel'));
selected=inkprof.internal.reviewImageCandidates(fixture());clear cleanup;verifyEmpty(tc,selected);
verifyEmpty(tc,findall(groot,'Name','InkProf - Review image patches'));
end
function testSelectionCancelCloses(tc)
p=string(tempname)+".png";imwrite(uint8(ones(10,20,3)*100),p);c=onCleanup(@()delete(p));
cleanup=clickLater(@(~,~)click('Cancel'));
d=struct('ROI',[],'MaxNewPatches',12,'MinSpacingPercent',1,'NeighborRadiusPercent',0);
s=inkprof.internal.imageRefinementDialog(p,d,"sRGB");clear cleanup;verifyEmpty(tc,s);
verifyEmpty(tc,findall(groot,'Name','InkProf - Select image colours'));
end
function testChangedThresholdAndSelection(tc)
cleanup=clickLater(@change);[selected,filter]=inkprof.internal.reviewImageCandidates(fixture());clear cleanup;
verifyEqual(tc,selected,2);verifyEqual(tc,filter.threshold,1);verifyEqual(tc,filter.visibleCount,3);
 function change(~,~)
  e=findall(groot,'Tag','imageDeltaEThreshold');if isempty(e),return;end
  e.Value=1;feval(e.ValueChangedFcn,e,[]);
  t=findall(groot,'Tag','imagePatchTable');t.Data{1,1}=false;t.Data{3,1}=false;
  click('Create TIFF16 target');
 end
end
function testEmptyFilterCanRecover(tc)
cleanup=clickLater(@change);[selected,filter]=inkprof.internal.reviewImageCandidates(fixture());clear cleanup;
verifyEqual(tc,selected,1);verifyEqual(tc,filter.metric,"sourceMappingDeltaE00");
 function change(~,~)
  e=findall(groot,'Tag','imageDeltaEThreshold');if isempty(e),return;end
  e.Value=100;feval(e.ValueChangedFcn,e,[]);
  b=findall(groot,'Type','uibutton','Text','Create TIFF16 target');verifyEqual(tc,b.Enable,matlab.lang.OnOffSwitchState.off);
  e.Value=5;feval(e.ValueChangedFcn,e,[]);
  m=findall(groot,'Tag','imageDeltaEMetric');m.Value='sourceMappingDeltaE00';feval(m.ValueChangedFcn,m,[]);
  click('Create TIFF16 target');
 end
end
function r=fixture()
r=struct('candidates',struct('patchId',"IMG-0001",'rgbPercent',[10;20;30],'pixelCount',5,'sourceMappingDeltaE00',9,'kind',"image-colour",'previewRGB',[.2;.3;.4]),'excludedNearExistingOrDuplicate',2);
r.fitEstimates=struct('available',true,'summary',struct('mean',1,'p95',2,'max',8));
r.candidates.estimatedLocalFitDeltaE00=1.25;r.candidates.localFitSupportCount=4;r.candidates.nearestFitRGBDistancePercent=2;
r.candidates=repmat(r.candidates,4,1);
r.candidates(2).estimatedLocalFitDeltaE00=5;r.candidates(3).estimatedLocalFitDeltaE00=8;r.candidates(4).estimatedLocalFitDeltaE00=[];
for k=2:4,r.candidates(k).patchId="IMG-000"+k;r.candidates(k).sourceMappingDeltaE00=1;end
end
function click(label)
b=findall(groot,'Type','uibutton','Text',label);if ~isempty(b)&&b(1).Enable,feval(b(1).ButtonPushedFcn,b(1),[]);end
end
function cleanup=clickLater(callback)
t=timer('ExecutionMode','fixedSpacing','StartDelay',2,'Period',0.2,'TimerFcn',callback);
watchdog=timer('StartDelay',25,'TimerFcn',@(~,~)delete(findall(groot,'Type','figure')));
cleanup=onCleanup(@()stopTimers([t,watchdog]));start(t);start(watchdog);
end
function stopTimers(t)
stop(t);delete(t);
end
