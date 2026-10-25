% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function f=showMeasuredDensity(report,job,file,options)
folder=fileparts(file);
f=uifigure('Name','InkProf - Measured Lab density','Position',[120 100 1050 780],'WindowStyle','alwaysontop');
g=uigridlayout(f,[8 1]);g.RowHeight={95,65,32,'1x','1x',60,40,35};
summary=uilabel(g,'Tag','densitySelectionSummary','Text',sprintf('%d measured fitting patches; %d retained in an experimental balanced subset; %d omitted from the trial only.\nComplete-link Lab distance %.2f ΔE76; target %d/group; inconsistent repeat threshold %.2f ΔE00. Provisional settings. RGB extrema, neutrals and inconsistent repeats can exceed the target.',report.originalCount,report.retainedCount,report.omittedCount,options.LabRadius,options.TargetPerGroup,options.RepeatLimit),'WordWrap','on');
settings=uigridlayout(g,[2 4]);settings.Padding=[0 0 0 0];settings.RowHeight={22,30};settings.ColumnWidth={'1x','1x','1x',160};
uilabel(settings,'Text','Lab distance (ΔE76)');uilabel(settings,'Text','Target per group');uilabel(settings,'Text','Repeat review (ΔE00)');uilabel(settings,'Text','');
radius=uieditfield(settings,'numeric','Value',options.LabRadius,'Limits',[.01 10],'Tag','densityLabRadius','ValueChangedFcn',@updateSelection);
cap=uieditfield(settings,'numeric','Value',options.TargetPerGroup,'Limits',[1 100],'RoundFractionalValues','on','Tag','densityTargetPerGroup','ValueChangedFcn',@updateSelection);
repeat=uieditfield(settings,'numeric','Value',options.RepeatLimit,'Limits',[.001 Inf],'Tag','densityRepeatLimit','ValueChangedFcn',@updateSelection);
uibutton(settings,'Text','Recalculate','Tag','densityRecalculate','ButtonPushedFcn',@recalculate);
selectionBar=uigridlayout(g,[1 2]);selectionBar.Padding=[0 0 0 0];selectionBar.RowHeight={28};
uibutton(selectionBar,'Text','Select all','Tag','densitySelectAll','ButtonPushedFcn',@selectAll);
uibutton(selectionBar,'Text','Clear all','Tag','densityClearAll','ButtonPushedFcn',@clearAll);
rows=cell(numel(report.groups),6);for k=1:numel(report.groups),a=report.groups(k);rows(k,:)={true,sprintf('%d',a.count),a.maxLabDistanceDeltaE76,sprintf('%.2f / %.2f / %.2f',a.rgbSpanPercent),sprintf('%d',a.retainedCount),mat2str(a.rows(:)')};end
groupTable=uitable(g,'Data',rows,'Tag','densityGroupTable','ColumnName',{'Use balancing','Count','Max Lab ΔE76','RGB span %','Retained','Source rows'},'ColumnWidth',{100,65,110,200,80,'auto'},'ColumnEditable',[true false false false false false],'ColumnFormat',{'logical','char','numeric','char','char','char'},'SelectionType','row','Multiselect','on','CellEditCallback',@updateSelection,'RowName',{});
repeatRows=cell(numel(report.repeats),4);for k=1:numel(report.repeats),a=report.repeats(k);repeatRows(k,:)={sprintf('%.4f / %.4f / %.4f',a.rgbPercent),sprintf('%d',numel(a.rows)),a.maxDeltaE00,char(string(logical(a.reviewRequired)))};end
uitable(g,'Data',repeatRows,'Tag','densityRepeatTable','ColumnName',{'Repeated RGB %','Readings','Maximum ΔE00','Review required'},'ColumnWidth',{'auto',90,140,130},'RowName',{});
flagged=0;if ~isempty(report.repeats),flagged=sum([report.repeats.reviewRequired]);end
uilabel(g,'Text',sprintf('%d repeated RGB groups; %d require repeatability review and remain protected. The candidate is compared to the full original fitting set, available development patches and photographic gradients. No automatic profile replacement.',numel(report.repeats),flagged),'WordWrap','on');
b=uibutton(g,'Tag','densityBuildCandidate','Text','Build separate balanced candidate','ButtonPushedFcn',@build);if report.omittedCount==0,b.Enable='off';end
uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
updateSelection();
 function recalculate(~,~)
  try
   inkprof.reviewMeasuredDensity(job,Parent=f,FitReportFile=string(report.fitReport),LabRadius=radius.Value,TargetPerGroup=cap.Value,RepeatLimit=repeat.Value, ...
    DevelopmentMeasurement=string(getOption('DevelopmentMeasurement',"")),DevelopmentIds=string(getOption('DevelopmentIds',strings(0,1))));
   if isgraphics(f),delete(f);end
  catch err
   uialert(f,err.message,'Recalculate density');
  end
 end
 function value=getOption(name,fallback)
  value=fallback;if isfield(options,name),value=options.(name);end
 end
 function selectAll(~,~)
  values=groupTable.Data;values(:,1)=repmat({true},size(values,1),1);groupTable.Data=values;groupTable.Selection=1:size(values,1);updateSelection();drawnow;
 end
 function clearAll(~,~)
  values=groupTable.Data;values(:,1)=repmat({false},size(values,1),1);groupTable.Data=values;groupTable.Selection=[];updateSelection();drawnow;
 end
 function current=chosen()
  values=groupTable.Data;indices=[];if ~isempty(values),indices=find(cell2mat(values(:,1)));end
  current=inkprof.internal.densityGroupSelection(report,indices);
 end
 function updateSelection(varargin)
  current=chosen();summary.Text=sprintf('%d / %d groups selected. %d measured fitting patches; %d retained; %d omitted in the separate trial.\nChecked groups use automatic representatives; unchecked groups keep every point. Originals remain unchanged. Lab distance %.2f ΔE76; target %d/group; repeat threshold %.2f ΔE00.',numel(current.groupSelection.selectedGroups),numel(report.groups),current.originalCount,current.retainedCount,current.omittedCount,options.LabRadius,options.TargetPerGroup,options.RepeatLimit);
  b.Enable='off';if current.omittedCount>0,b.Enable='on';
  else,summary.Text=string(summary.Text)+newline+"No points omitted. Increase Lab distance or lower target/group, then Recalculate. Protected points remain retained.";end
  if radius.Value~=options.LabRadius||cap.Value~=options.TargetPerGroup||repeat.Value~=options.RepeatLimit
   b.Enable='off';summary.Text=string(summary.Text)+newline+"Settings changed. Press Recalculate before building the candidate.";
  end
 end
 function stage(message)
  if isgraphics(f)&&isappdata(f,'InkProfCalculationState')
   state=getappdata(f,'InkProfCalculationState');state.message=string(message);setappdata(f,'InkProfCalculationState',state);
   inkprof.internal.updateCalculationProgress(f);drawnow;
  end
 end
 function build(~,~)
  b.Enable='off';drawnow;
  try
   progress=inkprof.internal.calculationProgress("Balanced density trial","Building a separate candidate and comparing original patches, development controls and gradients.",Parent=f);
   current=chosen();
   selectionFolder=fullfile(folder,'reviewed-selections',string(java.util.UUID.randomUUID()));mkdir(selectionFolder);
   selectionFile=fullfile(selectionFolder,'measurement-density.json');
   current.groupSelection.reviewedUTC=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
   current.groupSelection.originalReportSHA256=inkprof.internal.sha256(file);
   inkprof.internal.writeJson(selectionFile,current);
   inkprof.internal.recordProjectStep(selectionFolder,"Reviewed density group selection; original report retained");
   [result,trialFolder]=inkprof.buildDensityTrial(job,selectionFile,Activity=@stage,ShowJobDialog=false,DevelopmentMeasurement=options.DevelopmentMeasurement,DevelopmentIds=options.DevelopmentIds);
   clear progress;
   inkprof.internal.showDensityTrial(result,trialFolder);
  catch err
   clear progress;uialert(f,err.message,'Density trial');
  end
  if isgraphics(b),updateSelection();end
 end
end
