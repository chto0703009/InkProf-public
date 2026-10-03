% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testProfileInputDialog
tests=functiontests(localfunctions);
end
function testAccept(tc)
exercise(tc,'LockProfileInput',true);
end
function testCancel(tc)
exercise(tc,'CancelProfileInput',false);
end
function exercise(tc,button,expected)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
t=timer('ExecutionMode','fixedSpacing','Period',.5,'TimerFcn',@clickButton);
c=onCleanup(@()cleanupTimer(t));start(t);
[accepted,name]=inkprof.internal.confirmProfileInput("Synthetic dialog test", "Test revision");
verifyEqual(tc,accepted,expected);verifyEqual(tc,name,"Test revision");
verifyEmpty(tc,findall(groot,'Tag','InkProfProfileInput'));
cleanupTimer(t);
 function clickButton(~,~)
  f=findall(groot,'Tag','InkProfProfileInput');
  if isempty(f),return;end
  b=findall(f,'Tag',button);if isempty(b),return;end
  stop(t);cb=b.ButtonPushedFcn;cb(b,[]);
 end
end
function cleanupTimer(t)
if isvalid(t),stop(t);delete(t);end
end
