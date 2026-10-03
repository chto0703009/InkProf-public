function tests=testCalculationProgress
tests=functiontests(localfunctions);
end
function testBatchDoesNotOpenWindow(tc)
before=findall(groot,'Type','figure');[guard,p]=inkprof.internal.calculationProgress("Test","Batch");
verifyEmpty(tc,guard);verifyEmpty(tc,p);verifyEqual(tc,findall(groot,'Type','figure'),before);
end
function testVisibleElapsedAndCleanup(tc)
f=uifigure('Visible','off','Tag','InkProfWorkflow');c=onCleanup(@()delete(f));setappdata(f,'InkProfRunning',true);
[guard,p]=inkprof.internal.calculationProgress("Selecting patches","Converting colours");
verifyEqual(tc,f.Visible,matlab.lang.OnOffSwitchState.on);verifyEqual(tc,p.Indeterminate,matlab.lang.OnOffSwitchState.on);
verifyEqual(tc,getappdata(f,'InkProfCalculationPhase'),"Selecting patches");
pause(1.5);verifyTrue(tc,contains(string(p.Message),'elapsed'));
clear guard
verifyFalse(tc,isappdata(f,'InkProfCalculationPhase'));verifyEmpty(tc,timerfindall('Tag','InkProfCalculationTimer'));
end
function testFailureClosesProgress(tc)
f=uifigure('Visible','off','Tag','InkProfWorkflow');c=onCleanup(@()delete(f));setappdata(f,'InkProfRunning',true);
verifyError(tc,@fail,'inkprof:TestFailure');
verifyFalse(tc,isappdata(f,'InkProfCalculationPhase'));verifyEmpty(tc,timerfindall('Tag','InkProfCalculationTimer'));
end
function fail()
guard=inkprof.internal.calculationProgress("Testing failure","Working"); %#ok<NASGU>
error('inkprof:TestFailure','Expected test failure');
end
