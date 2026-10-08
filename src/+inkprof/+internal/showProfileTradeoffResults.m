% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function f=showProfileTradeoffResults(T,folder)
f=uifigure('Name','InkProf - Accuracy and gradient comparison','Position',[110 100 1200 650]);
g=uigridlayout(f,[3 1]);g.RowHeight={70,'1x',36};
uilabel(g,'Text',"Numerical comparison only. Fit columns are training error; model change describes the preprocessing model. Compare matching photographic paths before judging gradient quality. Reports: "+folder,'WordWrap','on');
keep={'variant','status','modelChangeMean','fitMean','fitP95','fitMax','photoCurvatureP95Mean','photoLightnessReversals','photoInteriorPaths','error'};
data=table2cell(T(:,keep));
% MATLAB uitable rejects string scalars inside a cell array.
for index=1:numel(data)
 if isstring(data{index})
  if ismissing(data{index}),data{index}='';else,data{index}=char(data{index});end
 end
end
for k=1:size(data,1)
 for j=3:9
  value=data{k,j};
  if ~isfinite(value),data{k,j}='unavailable';
  elseif j>=8,data{k,j}=sprintf('%d',value);
  else,data{k,j}=sprintf('%.1f',value);end
 end
end
t=uitable(g,'Data',data,'ColumnName',{'Candidate','Build','Model change dE00','Fit mean dE00','Fit P95 dE00','Fit max dE00','Photo curvature P95 mean','L* reversals','Interior paths','Diagnostic error'}, ...
 'ColumnEditable',false,'ColumnWidth','auto','RowName',{});
addStyle(t,uistyle('HorizontalAlignment','right'),'column',3:9);
uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
end
