% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function selected=reviewGamutCandidates(proposal)
% Review device values, without treating predictions as measured errors.
selected=[];
f=uifigure('Name','InkProf - Review gamut patches','Position',[100 70 1100 850],'WindowStyle','alwaysontop');
cleanup=onCleanup(@()delete(f));
g=uigridlayout(f,[5 2]);g.RowHeight={70,'1x',260,55,36};g.ColumnWidth={'1x','1x'};
label=uilabel(g,'Text','Select patches to add near the gamut surface in the chosen area or inner shell. Values are printer device RGB; Lab is predicted by the current ICC. Existing training colours and nearby duplicates have been excluded.','WordWrap','on');label.Layout.Column=[1 2];
p=proposal.candidates;rows=cell(numel(p),8);areaColumn="Area";
if isfield(p,'surfaceDistanceDeltaE76'),areaColumn="Depth ΔE76";end
for k=1:numel(p)
 a=p(k);location=a.anchorIndex;if isfield(a,'surfaceDistanceDeltaE76'),location=a.surfaceDistanceDeltaE76;end
 rows(k,:)={true,char(a.patchId),location,a.rgbPercent(1),a.rgbPercent(2),a.rgbPercent(3), ...
  sprintf('%.1f / %.1f / %.1f',a.predictedLab),char(a.kind)};
end
t=uitable(g,'Data',rows,'Tag','gamutPatchTable','ColumnName',{'Use','Patch',char(areaColumn),'R %','G %','B %','Predicted L* / a* / b*','Kind'}, ...
 'ColumnWidth',{45,100,90,75,75,75,190,130},'ColumnEditable',[true false false false false false false false],'RowName',{});
t.Layout.Column=[1 2];addStyle(t,uistyle('HorizontalAlignment','right'),'column',3:6);
plots=uigridlayout(g,[1 2]);plots.Layout.Column=[1 2];
ax=uiaxes(plots);depthAx=uiaxes(plots);
if isfield(proposal,'surface')
 mesh=proposal.surface;patch(ax,'Vertices',mesh.vertices(:,[2 3 1]),'Faces',mesh.triangles+1,'FaceColor',[.6 .6 .6],'FaceAlpha',.12,'EdgeColor','none');hold(ax,'on');
end
points=reshape([p.predictedLab],3,[])';
scatter3(ax,points(:,2),points(:,3),points(:,1),25,'filled');view(ax,3);axis(ax,'equal');grid(ax,'on');xlabel(ax,'a*');ylabel(ax,'b*');zlabel(ax,'L*');title(ax,'Proposed points: ICC-predicted Lab');
if isfield(p,'surfaceDistanceDeltaE76')
 scatter(depthAx,1:numel(p),[p.surfaceDistanceDeltaE76],15,'filled');
 yline(depthAx,proposal.parameters.shellThicknessDeltaE76,'--','Shell thickness');ylabel(depthAx,'Distance inward (ΔE76)');xlabel(depthAx,'Patch');grid(depthAx,'on');
else
 plot(depthAx,points(:,1),'.');ylabel(depthAx,'Predicted L*');xlabel(depthAx,'Patch');
end
label=uilabel(g,'Text','The printed target includes extra repeat controls and development patches. Print without colour conversion, measure, then rebuild the profile. A fresh independent print is needed to assess the result.','WordWrap','on');label.Layout.Column=[1 2];
uibutton(g,'Text','Create TIFF16 target','ButtonPushedFcn',@accept);
uibutton(g,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(f));
f.CloseRequestFcn=@(~,~)delete(f);uiwait(f);
if isgraphics(f),delete(f);end
clear cleanup;
 function accept(~,~)
  choice=find(cell2mat(t.Data(:,1)));
  if isempty(choice),uialert(f,'Select at least one patch.','Gamut patches');return;end
  selected=choice';delete(f);
 end
end
