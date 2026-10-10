% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function selected=reviewGamutCandidates(proposal)
% Review device values, without treating predictions as measured errors.
selected=[];
f=uifigure('Name','InkProf - Review gamut patches','Position',[150 120 850 600],'WindowStyle','alwaysontop');
cleanup=onCleanup(@()delete(f));
g=uigridlayout(f,[4 2]);g.RowHeight={70,'1x',55,36};g.ColumnWidth={'1x','1x'};
label=uilabel(g,'Text','Select patches to add around the clicked gamut area. Values are printer device RGB; Lab is predicted by the current ICC. Existing training colours and nearby duplicates have been excluded.','WordWrap','on');label.Layout.Column=[1 2];
p=proposal.candidates;rows=cell(numel(p),8);
for k=1:numel(p)
 a=p(k);rows(k,:)={true,char(a.patchId),a.anchorIndex,a.rgbPercent(1),a.rgbPercent(2),a.rgbPercent(3), ...
  sprintf('%.1f / %.1f / %.1f',a.predictedLab),char(a.kind)};
end
t=uitable(g,'Data',rows,'Tag','gamutPatchTable','ColumnName',{'Use','Patch','Area','R %','G %','B %','Predicted L* / a* / b*','Kind'}, ...
 'ColumnWidth',{45,100,50,75,75,75,190,130},'ColumnEditable',[true false false false false false false false],'RowName',{});
t.Layout.Column=[1 2];addStyle(t,uistyle('HorizontalAlignment','right'),'column',3:6);
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
