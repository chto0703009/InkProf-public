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
function testNestedPhasesRestoreOuterWithoutExtraTimers(tc)
f=uifigure('Visible','off','Tag','InkProfWorkflow');c=onCleanup(@()delete(f));setappdata(f,'InkProfRunning',true);
[outer,p]=inkprof.internal.calculationProgress("Building next iteration","Fitting profiles");
[inner,q]=inkprof.internal.calculationProgress("Writing TIFF16","Creating verification target");
verifyEqual(tc,p,q);verifyEqual(tc,numel(timerfindall('Tag','InkProfCalculationTimer')),1);
verifyEqual(tc,string(p.Title),"Writing TIFF16");clear inner;
verifyTrue(tc,isvalid(p));verifyEqual(tc,string(p.Title),"Building next iteration");
verifyEqual(tc,getappdata(f,'InkProfCalculationPhase'),"Building next iteration");clear outer;
verifyEmpty(tc,timerfindall('Tag','InkProfCalculationTimer'));
end
function testExplicitMeasurementParent(tc)
f=uifigure('Visible','off','Name','Measurement test');c=onCleanup(@()delete(f));
[guard,p]=inkprof.internal.calculationProgress("Saving measurement","Checking rows",Parent=f);
verifyTrue(tc,isvalid(p));verifyEqual(tc,string(p.Title),"Saving measurement");clear guard;
verifyFalse(tc,isappdata(f,'InkProfCalculationState'));
end
function testExternalProcessKeepsActivityUpdating(tc)
assumeTrue(tc,isunix);
f=uifigure('Visible','off','Tag','InkProfWorkflow');c=onCleanup(@()delete(f));setappdata(f,'InkProfRunning',true);
[guard,p]=inkprof.internal.calculationProgress("External calculation","Waiting for a worker process");
inkprof.internal.runTool("/bin/sleep","2",string(tempdir),10);
elapsed=regexp(char(p.Message),'elapsed (\d+) min (\d+) sec','tokens','once');
verifyNotEmpty(tc,elapsed);verifyGreaterThanOrEqual(tc,60*str2double(elapsed{1})+str2double(elapsed{2}),1);
clear guard;verifyEmpty(tc,timerfindall('Tag','InkProfCalculationTimer'));
end
function fail()
guard=inkprof.internal.calculationProgress("Testing failure","Working"); %#ok<NASGU>
error('inkprof:TestFailure','Expected test failure');
end
