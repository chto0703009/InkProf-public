% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testRunProgress
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testReturnAndErrorReleaseOwnedTimer(tc)
for fail=[false true]
    released=[];lastwarn('');
    if fail
        verifyError(tc,@()runCallback(true),'inkprof:TestFailure');
    else
        runCallback(false);
    end
    verifyEqual(tc,released,~fail);
    verifyEmpty(tc,timerfindall('Tag','InkProfRunProgressTest'));
    [message,~]=lastwarn;verifyEmpty(tc,message);
end
    function runCallback(fail)
        operation=inkprof.internal.RunProgress(@release);
        cleanup=operation.guard(); %#ok<NASGU>
        operation.Watch=makeTimer();
        start(operation.Watch);
        if fail,error('inkprof:TestFailure','Expected test failure');end
        operation.Finished=true;
    end
    function release(finished)
        released=finished;
    end
end
function testRepeatedStopAndClosedParent(tc)
f=uifigure('Visible','on');parentCleanup=onCleanup(@()closeParent(f));
operation=inkprof.internal.RunProgress(@(~)[]);cleanup=operation.guard();
operation.Progress=uiprogressdlg(f);operation.Watch=timer('TimerFcn',@(~,~)[]);
watch=operation.Watch;delete(f);
operation.stop();operation.stop();operation.finish();clear cleanup;
verifyFalse(tc,isvalid(watch));
end

function closeParent(f)
if isgraphics(f),delete(f);end
end

function watch=makeTimer()
callbackLocal=1;
watch=timer('Tag','InkProfRunProgressTest','TimerFcn',@tick);
    function tick(~,~)
        callbackLocal=callbackLocal+1;
    end
end
