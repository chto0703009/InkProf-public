% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function tests=testProfileTradeoffResults
tests=functiontests(localfunctions);
end
function testSavedStringsAndMissingMetricsDisplay(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
folder=string(tempname);mkdir(folder);c=onCleanup(@()rmdir(folder,'s'));
T=table(["Raw";"Argyll -r 0.5 %"],["succeeded";"failed"], ...
 [NaN;NaN],[1;NaN],[2;NaN],[3;NaN],[10;NaN],[0;NaN],[72;NaN],["";"Build failed"], ...
 'VariableNames',{'variant','status','modelChangeMean','fitMean','fitP95','fitMax','photoCurvatureP95Mean','photoLightnessReversals','photoInteriorPaths','error'});
writetable(T,fullfile(folder,'comparison.csv'));
f=inkprof.showProfileQualityComparison(folder);closeFig=onCleanup(@()delete(f));
t=findall(f,'Type','uitable');verifyTrue(tc,iscell(t.Data));
verifyEqual(tc,t.Data{1,1},'Raw');verifyEqual(tc,t.Data{1,3},'unavailable');
verifyEqual(tc,t.Data{1,4},'1.0');verifyEqual(tc,t.Data{2,10},'Build failed');
end
