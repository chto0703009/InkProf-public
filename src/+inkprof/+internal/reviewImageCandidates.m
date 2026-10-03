function [selected,review]=reviewImageCandidates(proposal)
% Filter and select original candidate IDs; hidden rows are never printed.
selected=[];review=struct;c=proposal.candidates;n=numel(c);
f=uifigure('Name','InkProf - Review image patches','Position',[60 100 1380 750],'WindowStyle','modal');
cleanup=onCleanup(@()delete(f));f.CloseRequestFcn=@cancel;
g=uigridlayout(f,[6 1]);g.RowHeight={85,42,30,'1x',95,52};
header=sprintf('%d proposed new patches. Excluded near existing/duplicate RGB: %d.\nOnly visible, checked patches will be added. Print controls are additional.',n,proposal.excludedNearExistingOrDuplicate);
if isfield(proposal,'fitEstimates')&&proposal.fitEstimates.available
 stats=proposal.fitEstimates.summary;header=header+string(newline)+sprintf('Latest profile: training fit ΔE00 — mean %.2f; p95 %.2f; max %.2f.',stats.mean,stats.p95,stats.max);
else
 header=string(header)+newline+"No current training-fit report: local error estimates are unavailable.";
end
uilabel(g,'Text',header,'WordWrap','on');
filterbar=uigridlayout(g,[1 4]);filterbar.ColumnWidth={125,300,145,'1x'};filterbar.Padding=[0 0 0 0];
uilabel(filterbar,'Text','Filter ΔE00 metric:');
metric=uidropdown(filterbar,'Items',{'Estimated local fit ΔE00','Model mapping ΔE00'}, ...
 'ItemsData',{'estimatedLocalFitDeltaE00','sourceMappingDeltaE00'},'Value','estimatedLocalFitDeltaE00', ...
 'Tag','imageDeltaEMetric','ValueChangedFcn',@refresh);
uilabel(filterbar,'Text','Show values greater than:');
threshold=uieditfield(filterbar,'numeric','Value',5,'Limits',[0 Inf],'Tag','imageDeltaEThreshold','ValueChangedFcn',@refresh);
status=uilabel(g,'Text','','Tag','imagePatchFilterStatus');
t=uitable(g,'Data',cell(0,9),'ColumnName',{'Use','Patch','Image colour','Device RGB %','Sampled pixels','Est. local fit ΔE00','Support: points / distance','Model mapping ΔE00','Probe'}, ...
 'ColumnEditable',[true,false,false,false,false,false,false,false,false],'ColumnFormat',{'logical','char','char','char','numeric','char','char','numeric','char'}, ...
 'ColumnWidth',{45,90,85,155,95,140,185,155,'auto'},'RowName',{},'Tag','imagePatchTable','CellEditCallback',@edited);
uilabel(g,'Text','Est. local fit ΔE00 is an indication from up to four measured training patches within 10% RGB per channel, not a verified print-error prediction. Model mapping ΔE00 describes the image colour versus the ICC round trip; it is not a measured print error. Missing values are excluded from the filter. Lower the threshold to see more patches. Swatches show image colours in sRGB.','WordWrap','on');
bar=uigridlayout(g,[1 2]);bar.Padding=[0 0 0 0];bar.RowHeight={'1x'};
uibutton(bar,'Text','Cancel','ButtonPushedFcn',@cancel);
add=uibutton(bar,'Text','Create TIFF16 target','ButtonPushedFcn',@accept);
included=true(n,1);visible=[];refresh([],[]);
if isgraphics(f),uiwait(f);end
% Explicit destruction is required: nested callbacks retain this workspace,
% so relying on onCleanup alone can leave a modal window blocking the app.
if isgraphics(f),delete(f);end
 function edited(~,event)
  included(visible(event.Indices(1)))=logical(event.NewData);
 end
 function refresh(~,~)
  values=nan(n,1);
  for k=1:n
   if isfield(c(k),metric.Value)
    value=c(k).(metric.Value);
    if isnumeric(value)&&isscalar(value)&&isfinite(value),values(k)=value;end
   end
  end
  visible=find(values>threshold.Value);rows=cell(numel(visible),9);
  for j=1:numel(visible)
   k=visible(j);q=c(k);estimate='Unavailable';support='None';
   if isfield(q,'estimatedLocalFitDeltaE00')&&~isempty(q.estimatedLocalFitDeltaE00)
    estimate=sprintf('~ %.2f',q.estimatedLocalFitDeltaE00);support=sprintf('%d; nearest %.2f%%',q.localFitSupportCount,q.nearestFitRGBDistancePercent);
   end
   rows(j,:)={included(k),char(q.patchId),' ',char(join(compose('%.2f',q.rgbPercent),' / ')),q.pixelCount,estimate,support,q.sourceMappingDeltaE00,char(q.kind)};
  end
  removeStyle(t);t.Data=rows;
  for j=1:numel(visible),addStyle(t,uistyle('BackgroundColor',double(c(visible(j)).previewRGB(:)')),'cell',[j,3]);end
  status.Text=sprintf('%d of %d patches above ΔE00 %.2f. %d without a value for this metric.',numel(visible),n,threshold.Value,sum(isnan(values)));
  if isempty(visible)
   status.Text=status.Text+string(' Lower the threshold or choose another metric.');add.Enable='off';
  else
   add.Enable='on';
  end
 end
 function cancel(~,~)
  selected=[];if isgraphics(f),delete(f);end
 end
 function accept(~,~)
  use=cell2mat(t.Data(:,1));
  if ~any(use),uialert(f,'Select at least one visible patch.','No patches selected');return;end
  selected=visible(use);
  review=struct('metric',string(metric.Value),'comparison',">",'threshold',threshold.Value,'visibleCount',numel(visible),'selectedCount',numel(selected));
  delete(f);
 end
end
