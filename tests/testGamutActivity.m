% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testGamutActivity
tests=functiontests(localfunctions);
end
function testVisibleStagesAndTimerCleanup(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
f=figure('Visible','off');cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
label=uicontrol(f,'Style','text');a=inkprof.internal.gamutActivity(f,label);
c=onCleanup(@()a.close());
verifyTrue(tc,any(contains(string(label.String),'elapsed')));
a.stage("Review patches");verifyTrue(tc,contains(string(label.String),'waiting'));
t=timerfindall('Tag','InkProfGamutActivity');verifyEqual(tc,string(t.Running),"off");
a.stage("Creating TIFF16 print package");verifyTrue(tc,any(contains(string(label.String),'Creating TIFF16')));
verifyEqual(tc,string(t.Running),"on");clear c;
verifyEmpty(tc,timerfindall('Tag','InkProfGamutActivity'));
end
