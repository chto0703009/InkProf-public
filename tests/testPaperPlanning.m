function tests=testPaperPlanning
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testBoundariesAndStock(tc)
p=inkprof.planTargetPaper(120);
verifyTrue(tc,any(string({p.kind})=="Roll"));
verifyTrue(tc,any(contains(string({p.description}),"A3+ / 2")));
for v=p
 verifyLessThanOrEqual(tc,v.sizeMm(1),320);verifyLessThanOrEqual(tc,v.sizeMm(2),370);
 verifyGreaterThanOrEqual(tc,v.stockSheets*v.piecesPerSheet,v.estimatedPages);
end
end
function testFewerPatchesSavePaper(tc)
a=inkprof.planTargetPaper(20);b=inkprof.planTargetPaper(600);
verifyLessThan(tc,a(1).stockAreaMm2,b(1).stockAreaMm2);
a=a(string({a.kind})=="Roll");b=b(string({b.kind})=="Roll");
verifyLessThan(tc,a.rollFeedMm,b.rollFeedMm);
end
function testWideRollAndCustomLimits(tc)
p=inkprof.planTargetPaper(100,RollWidthMm=610,MaxScanMm=300,MaxLengthMm=350);
verifyTrue(tc,any(string({p.kind})=="Roll"));
for v=p,verifyLessThanOrEqual(tc,v.sizeMm(1),300);verifyLessThanOrEqual(tc,v.sizeMm(2),350);end
end

function testLimitsCanExceedOriginalSled(tc)
p=inkprof.planTargetPaper(800,MaxScanMm=500,MaxLengthMm=600,RollWidthMm=483);
verifyTrue(tc,any(arrayfun(@(v)v.sizeMm(1)>320||v.sizeMm(2)>370,p)));
end
function testSmallTargetAndLargerSled(tc)
folder=string(tempname);mkdir(folder);clean=onCleanup(@()rmdir(folder,'s'));
prefs=inkprof.internal.paperPreferences();
for count=[20 120]
p=inkprof.planTargetPaper(count);
m=inkprof.createTarget(fullfile(folder,'small'+string(count)),PatchCount=count,GraySteps=3,PaperSizeMm=p(1).sizeMm, ...
 PaperLayout=struct('preferences',prefs),DPI=100);
verifyTrue(tc,inkprof.verifyPackage(fullfile(folder,'small'+string(count))).passed);
verifyEqual(tc,m.sourcePatches,count);
end
prefs.MaxScanMm=400;prefs.MaxLengthMm=500;
m=inkprof.createTarget(fullfile(folder,'wide'),PatchCount=20,GraySteps=3,PaperSizeMm=[380 210], ...
 PaperLayout=struct('preferences',prefs),DPI=100);
verifyGreaterThan(tc,m.renderPaperSizeMm(1),320);
verifyTrue(tc,inkprof.verifyPackage(fullfile(folder,'wide')).passed);
end
function testDialogAcceptAndCancel(tc)
t=timer('ExecutionMode','fixedSpacing','Period',.2,'TimerFcn',@acceptPaper);
clean=onCleanup(@()disposeTimer(t));start(t);
c=inkprof.internal.paperLayoutDialog(120,"");
verifyEqual(tc,c.sourcePatchCount,120);verifyEqual(tc,c.preferences.MaxScanMm,320);
verifyEmpty(tc,findall(groot,'Tag','paperLayoutDialog'));
end
function acceptPaper(t,~)
f=findall(groot,'Tag','paperLayoutDialog');if isempty(f),return;end
b=findobj(f,'Tag','usePaperDimensions');if isempty(b),return;end
stop(t);try,b.ButtonPushedFcn(b,[]);catch err,disp(getReport(err));delete(f);end
end
function disposeTimer(t)
stop(t);delete(t);delete(findall(groot,'Tag','paperLayoutDialog'));
end
