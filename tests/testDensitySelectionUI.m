% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testDensitySelectionUI
tests=functiontests(localfunctions);
end
function testSelectAllUpdatesCheckboxesHighlightsAndCandidateState(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
a=struct('count',3,'maxLabDistanceDeltaE76',.4,'rgbSpanPercent',[1 2 3],'retainedCount',1,'rows',[1 2 3],'retainedRows',1);
b=a;b.rows=[4 5 6];b.retainedRows=4;
r=struct('originalCount',8,'retainedCount',4,'omittedCount',4,'selectedRows',[1;4;7;8],'protectedRows',[7;8], ...
 'groups',[a b],'repeats',struct('rgbPercent',[20 30 40],'rows',[1 2],'maxDeltaE00',.2,'reviewRequired',false));
r.fitReport='unused-fit.json';
o=struct('LabRadius',1,'TargetPerGroup',4,'RepeatLimit',1);
f=inkprof.internal.showMeasuredDensity(r,"unused","unused.json",o);c=onCleanup(@()delete(f)); %#ok<NASGU>
t=findall(f,'Tag','densityGroupTable');clearButton=findall(f,'Tag','densityClearAll');
feval(clearButton.ButtonPushedFcn,clearButton,[]);verifyFalse(tc,any(cell2mat(t.Data(:,1))));
button=findall(f,'Tag','densitySelectAll');feval(button.ButtonPushedFcn,button,[]);
verifyTrue(tc,all(cell2mat(t.Data(:,1))));verifyEqual(tc,t.Selection,[1 2]);
labels=findall(f,'Type','uilabel');verifyTrue(tc,any(contains(string({labels.Text}),'2 / 2 groups selected')));
repeatTable=findall(f,'Tag','densityRepeatTable');verifyEqual(tc,repeatTable.Data{1,2},'2');
verifyEqual(tc,string(findall(f,'Tag','densityRecalculate').Enable),"on");
feval(clearButton.ButtonPushedFcn,clearButton,[]);
verifyEqual(tc,string(findall(f,'Tag','densityBuildCandidate').Enable),"off");
verifyTrue(tc,contains(string(findall(f,'Tag','densitySelectionSummary').Text),'No points omitted'));
verifyEqual(tc,findall(f,'Tag','densityLabRadius').Value,1);
end
