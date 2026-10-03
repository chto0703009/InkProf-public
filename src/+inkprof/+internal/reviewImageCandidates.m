function selected=reviewImageCandidates(proposal)
% Editable inclusion and source colour swatches before a target is rendered.
selected=[];c=proposal.candidates;n=numel(c);
f=uifigure('Name','InkProf - Review image patches','Position',[60 100 1380 750],'WindowStyle','modal');
cleanup=onCleanup(@()delete(f));f.CloseRequestFcn=@(~,~)uiresume(f);
g=uigridlayout(f,[4 1]);g.RowHeight={105,'1x',95,42};
header=sprintf('%d proposed new patches. Excluded near existing/duplicate RGB: %d.\nUncheck any patches you do not want. Additional print controls are not counted here.',n,proposal.excludedNearExistingOrDuplicate);
if isfield(proposal,'fitEstimates')&&proposal.fitEstimates.available
 stats=proposal.fitEstimates.summary;header=header+string(newline)+sprintf('Latest profile: training fit ΔE00 — mean %.2f; p95 %.2f; max %.2f. Local estimates below use nearby measured patches.',stats.mean,stats.p95,stats.max);
else
 header=string(header)+newline+"No current training-fit report: local error estimates are unavailable.";
end
uilabel(g,'Text',header,'WordWrap','on');
rows=cell(n,9);
for k=1:n
 q=c(k);estimate='Unavailable';support='None';
 if isfield(q,'estimatedLocalFitDeltaE00')&&~isempty(q.estimatedLocalFitDeltaE00)
  estimate=sprintf('~ %.2f',q.estimatedLocalFitDeltaE00);support=sprintf('%d; nearest %.2f%%',q.localFitSupportCount,q.nearestFitRGBDistancePercent);
 end
 rows(k,:)={true,char(q.patchId),' ',char(join(compose('%.2f',q.rgbPercent),' / ')),q.pixelCount,estimate,support,q.sourceMappingDeltaE00,char(q.kind)};
end
t=uitable(g,'Data',rows,'ColumnName',{'Use','Patch','Image colour','Device RGB %','Sampled pixels','Est. local fit ΔE00','Support: points / distance','Model mapping ΔE00','Probe'}, ...
 'ColumnEditable',[true,false,false,false,false,false,false,false,false],'ColumnWidth',{45,90,85,155,95,140,185,155,'auto'},'RowName',{});
for k=1:n,addStyle(t,uistyle('BackgroundColor',double(c(k).previewRGB(:)')),'cell',[k,3]);end
uilabel(g,'Text','Est. local fit ΔE00 is an indication from up to four measured training patches within 10% RGB per channel, not a verified print-error prediction. Unavailable means no nearby support. Colour swatches preview image colours in sRGB. Model mapping ΔE00 is the difference between desired image colour and the ICC round trip, not a measured print error or proof of being outside gamut. Neighbor probes use nearby device RGB.','WordWrap','on');
bar=uigridlayout(g,[1 2]);uibutton(bar,'Text','Cancel','ButtonPushedFcn',@(~,~)uiresume(f));uibutton(bar,'Text','Create TIFF16 target','ButtonPushedFcn',@accept);
uiwait(f);
 function accept(~,~)
  use=cell2mat(t.Data(:,1));
  if ~any(use),uialert(f,'Select at least one patch.','No patches selected');return;end
  selected=find(use);uiresume(f);
 end
end
