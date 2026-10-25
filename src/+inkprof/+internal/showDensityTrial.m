% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function showDensityTrial(result,folder)
f=uifigure('Name','InkProf - Balanced density candidate comparison','Position',[100 100 1100 760],'WindowStyle','alwaysontop');
g=uigridlayout(f,[6 1]);g.RowHeight={85,'1x',60,'1x',45,35};
a=result.commonFit.all;
uilabel(g,'Text',sprintf('All %d original fitting patches: original mean %.3f → trial mean %.3f ΔE00; worst individual regression %+.3f.\nIncludes observations omitted from trial fitting. Training fit is not independent print validation. The active profile is unchanged.',a.count,a.originalMean,a.trialMean,a.worstRegression),'WordWrap','on');
p=result.commonFit.patches;[~,order]=sort([p.changeDeltaE00],'descend');rows=cell(numel(p),4);
for k=1:numel(p),q=p(order(k));rows(k,:)={char(q.sampleId),q.originalDeltaE00,q.trialDeltaE00,q.changeDeltaE00};end
uitable(g,'Data',rows,'ColumnName',{'Source ID','Original ΔE00','Trial ΔE00','Change (+ worse)'},'ColumnWidth',{'auto',150,150,170},'RowName',{});
text="No development observations supplied: independent superiority has not been established.";
if result.development.available,a=result.development;text=sprintf('%d reserved development patches: mean %.3f → %.3f ΔE00; worst regression %+.3f. Adaptive development evidence, not final independent validation.',a.count,a.originalMean,a.candidateMean,a.worstRegression);end
uilabel(g,'Text',text,'WordWrap','on');
a=result.gradients.originalMetrics;b=result.gradients.candidateMetrics;rows=cell(numel(a),5);
for k=1:numel(a)
 j=find(string({b.key})==string(a(k).key));
 if numel(j)==1,rows(k,:)={char(a(k).key),a(k).curvatureP95,b(j).curvatureP95,a(k).lightnessReversals,b(j).lightnessReversals};
 else,rows(k,:)={char(a(k).key),a(k).curvatureP95,NaN,a(k).lightnessReversals,NaN};end
end
uitable(g,'Data',rows,'ColumnName',{'Matching gradient','Original curvature P95','Trial curvature P95','Original reversals','Trial reversals'},'ColumnWidth',{'auto',145,145,125,125},'RowName',{});
uilabel(g,'Text',folder,'WordWrap','on');uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
end
