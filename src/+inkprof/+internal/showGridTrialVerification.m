% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function f=showGridTrialVerification(result,folder)
f=uifigure('Name','InkProf - ICC grid trial','Position',[100 80 1150 800]);
g=uigridlayout(f,[6 1]);g.RowHeight={75,130,150,32,'1x',36};
uilabel(g,'Text',"Numerical verification: same measurements, separate candidate. Dashed curves: source; solid: candidate. Predicted colours, not measured print accuracy. Results: "+folder,'WordWrap','on');
rows=result.grids.comparison;data=cell(numel(rows),5);
for k=1:numel(rows)
 r=rows(k);data(k,:)={char(r.table),r.sourceLevels,r.sourcePoints,r.candidateLevels,r.candidatePoints};
end
uitable(g,'Data',data,'ColumnName',{'Table','Source n','Source n³','Candidate n','Candidate n³'},'ColumnWidth','auto','RowName',{});
counts=uiaxes(g);values=[[rows.sourcePoints]' [rows.candidatePoints]'];
if numel(rows)==1,values=[values;NaN NaN];end
bar(counts,values);
counts.XTick=1:numel(rows);counts.XTickLabel={rows.table};ylabel(counts,'Actual LUT points (n³)');legend(counts,{'Source','Candidate'});title(counts,'ICC table resolution');
curves=jsondecode(fileread(result.curveFile));
choice=uidropdown(g,'Items',{curves.paths.name},'ValueChangedFcn',@(~,~)drawCurves());
plots=uigridlayout(g,[1 2]);rgbAx=uiaxes(plots);labAx=uiaxes(plots);drawCurves();
uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
 function drawCurves()
  index=find(strcmp({curves.paths.name},choice.Value),1);p=curves.paths(index);
  cla(rgbAx);cla(labAx);hold(rgbAx,'on');hold(labAx,'on');
  x=linspace(0,1,size(p.source.rgbPercent,1));colours=eye(3);
  for channel=1:3
   plot(rgbAx,x,p.source.rgbPercent(:,channel),'--','Color',colours(channel,:));
   plot(rgbAx,x,p.candidate.rgbPercent(:,channel),'-','Color',colours(channel,:));
  end
  plot(labAx,x,p.source.lab(:,1),'--');plot(labAx,x,p.candidate.lab(:,1),'-');
  xlabel(rgbAx,'Position along source gradient');ylabel(rgbAx,'Printer RGB (%)');
  title(rgbAx,'Dashed: source; solid: candidate');grid(rgbAx,'on');
  xlabel(labAx,'Position along source gradient');ylabel(labAx,'Predicted L*');legend(labAx,{'Source','Candidate'});grid(labAx,'on');
 end
end
