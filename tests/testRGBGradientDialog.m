% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testRGBGradientDialog
tests=functiontests(localfunctions);
end
function testOptionalNonblockingWindow(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
f=inkprof.internal.rgbGradientDialog("unused-until-user-runs-test");c=onCleanup(@()delete(f));
verifyEqual(tc,string(f.Visible),"on");verifyEqual(tc,string(f.Tag),"InkProfRGBGradient");
verifyEqual(tc,string(findall(f,'Tag','RunRGBGradientCheck').Enable),"on");
verifyEqual(tc,string(findall(f,'Tag','RGBGradientPath').Enable),"off");
end
