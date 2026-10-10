% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function tests=testGamutPicker
tests=functiontests(localfunctions);
end
function testReviewKeepsOnlyCheckedPatches(tc)
p=struct('patchId',"GAM-0001",'anchorIndex',1,'rgbPercent',[10;20;30],'predictedLab',[40;0;0],'kind',"gamut-neighbour");
proposal=struct('candidates',repmat(p,3,1));
for k=1:3,proposal.candidates(k).patchId="GAM-000"+k;end
t=timer('ExecutionMode','fixedSpacing','StartDelay',1,'Period',.2,'TimerFcn',@choose);
watchdog=timer('StartDelay',20,'TimerFcn',@(~,~)delete(findall(groot,'Name','InkProf - Review gamut patches')));
c=onCleanup(@()stopTimers([t watchdog]));start(t);start(watchdog);
selected=inkprof.internal.reviewGamutCandidates(proposal);verifyEqual(tc,selected,[1 3]);
verifyEmpty(tc,findall(groot,'Name','InkProf - Review gamut patches'));
clear c;
 function choose(~,~)
  table=findall(groot,'Tag','gamutPatchTable');if isempty(table),return;end
  table.Data{2,1}=false;button=findall(groot,'Type','uibutton','Text','Create TIFF16 target');
  feval(button.ButtonPushedFcn,button,[]);
 end
end
function stopTimers(t)
stop(t);delete(t);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testClickModesIdentityAndClear(tc)
f=figure('Visible','off');cleanup=onCleanup(@()delete(f));ax=axes(f);
data=struct('vertices',[10 20 30;50 40 60;90 0 0],'profileSHA256',"fixture", ...
 'deviceMapping',struct('rgb',[0 .5 1;.2 .4 .6;1 1 1],'lab',[10 20 30;49 40 60;90 0 0],'distanceDeltaE76',[0;1;0]));
f.UserData=data;p=patch(ax,'Vertices',data.vertices(:,[2 3 1]),'Faces',[1 2 3]);
inkprof.internal.gamutPicker(f,ax,p,data,"/missing/profile.icc");
e=struct('IntersectionPoint',[40 60 50]);
feval(p.ButtonDownFcn,p,e);t=findobj(f,'Tag','gamutAnchorTable');verifyEmpty(tc,t.Data);
b=findobj(f,'Tag','gamutSelectMode');feval(b.Callback,b,[]);feval(p.ButtonDownFcn,p,e);
verifyEqual(tc,size(t.Data,1),1);a=f.UserData.selectedGamutAnchors;
verifyEqual(tc,a.vertexIndex,2);verifyEqual(tc,a.rgbPercent,[20 40 60]);verifyEqual(tc,a.distanceDeltaE76,1);
feval(p.ButtonDownFcn,p,e);verifyEqual(tc,size(t.Data,1),1);
% Read-only profiles may be inspected, but cannot create a project target.
b=findobj(f,'Tag','gamutCreatePatches');verifyEqual(tc,b.Enable,'off');
b=findobj(f,'String','Clear selection');feval(b.Callback,b,[]);verifyEmpty(tc,t.Data);verifyEmpty(tc,f.UserData.selectedGamutAnchors);
end
