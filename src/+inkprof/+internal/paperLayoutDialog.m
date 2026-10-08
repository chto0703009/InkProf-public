% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function choice=paperLayoutDialog(count,project,source,rgbScale)
% Shared editable proposals for base, verification and refinement targets.
if nargin<3,source="";end
if nargin<4,rgbScale=NaN;end
choice=[];prefs=inkprof.internal.paperPreferences(project);
f=uifigure('Name','InkProf | Paper suggestions','Position',[150 150 1100 650],'WindowStyle','modal','Tag','paperLayoutDialog','Visible','off');
g=uigridlayout(f,[9 2]);g.ColumnWidth={'1x','1x'};g.RowHeight={55,30,32,'1x',32,55,35,35,35};
t=uilabel(g,'Text',sprintf('%d source patches, including controls. Suggestions preserve patch size. Estimates use standard i1 geometry; preview confirms the actual pages.',count),'WordWrap','on');t.Layout.Column=[1 2];
uilabel(g,'Text','Maximum sweep / target length (mm)');uilabel(g,'Text','Roll width (mm)');
a=uigridlayout(g,[1 2]);a.Padding=[0 0 0 0];
scan=uieditfield(a,'numeric','ValueDisplayFormat','%.1f','Value',prefs.MaxScanMm,'Limits',[65 Inf],'ValueChangedFcn',@refresh);
len=uieditfield(a,'numeric','ValueDisplayFormat','%.1f','Value',prefs.MaxLengthMm,'Limits',[65 Inf],'ValueChangedFcn',@refresh);
roll=uieditfield(g,'numeric','ValueDisplayFormat','%.1f','Value',prefs.RollWidthMm,'Limits',[65 Inf],'ValueChangedFcn',@refresh);
tab=uitable(g,'ColumnName',{'Source / cut','Sweep mm','Length mm','Est. pages','Stock sheets / strips','Used area cm2','Stock area cm2','Roll total mm'},'ColumnWidth',{330,75,75,80,115,100,100,100},'CellSelectionCallback',@select);tab.Layout.Column=[1 2];
a=uigridlayout(g,[1 2]);a.Padding=[0 0 0 0];
w=uieditfield(a,'numeric','ValueDisplayFormat','%.1f','Limits',[65 Inf],'Value',297);h=uieditfield(a,'numeric','ValueDisplayFormat','%.1f','Limits',[65 Inf],'Value',210);
uilabel(g,'Text','Editable final target: sweep × length (mm)');
note=uilabel(g,'Text','Choose a row, then edit the dimensions if needed. Print at 100%. Cut larger stock as described; the TIFF is one measurement piece.','WordWrap','on');note.Layout.Column=[1 2];
status=uilabel(g,'Text','','WordWrap','on');status.Layout.Column=[1 2];
previewButton=uibutton(g,'Text','Preview selected dimensions (actual pages)','ButtonPushedFcn',@preview);previewButton.Layout.Column=[1 2];
if source=="",previewButton.Enable='off';end
uibutton(g,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(f));useButton=uibutton(g,'Text','Use these dimensions','ButtonPushedFcn',@accept);
selected=[];proposals=[];refresh([],[]);useButton.Tag='usePaperDimensions';f.Visible='on';topGuard=inkprof.internal.lowerTopWindows(f);if isvalid(f)&&isempty(choice),uiwait(f);end;delete(topGuard);if isvalid(f),delete(f);end
 function refresh(~,~)
  try
   proposals=inkprof.planTargetPaper(count,MaxScanMm=scan.Value,MaxLengthMm=len.Value,RollWidthMm=roll.Value);
  catch err
   selected=[];tab.Data=cell(0,8);status.Text=err.message;useButton.Enable='off';return
  end
  useButton.Enable='on';
  rows=cell(numel(proposals),8);
  for k=1:numel(proposals),p=proposals(k);rows(k,:)={char(p.description),sprintf('%.1f',p.sizeMm(1)),sprintf('%.1f',p.sizeMm(2)),p.estimatedPages,p.stockSheets,sprintf('%.1f',p.usedAreaMm2/100),sprintf('%.1f',p.stockAreaMm2/100),sprintf('%.1f',p.rollFeedMm)};end
  tab.Data=rows;selected=proposals(1);w.Value=selected.sizeMm(1);h.Value=selected.sizeMm(2);
  status.Text='Sorted by target-piece area, then stock area. Leftover cut pieces can be kept. Wide rolls can be cut into several measurement pieces.';
 end
 function select(~,e)
  if isempty(e.Indices),return;end
  selected=proposals(e.Indices(1));w.Value=selected.sizeMm(1);h.Value=selected.sizeMm(2);
 end
 function preview(~,~)
  if w.Value>scan.Value||h.Value>len.Value,uialert(f,'Dimensions exceed your measurement limits.','Paper layout');return;end
  temp=string(tempname);clean=onCleanup(@()removePreview(temp));previewButton.Enable='off';drawnow;
  try
   metadata=struct('preferences',struct('MaxScanMm',scan.Value,'MaxLengthMm',len.Value,'RollWidthMm',roll.Value));
   m=inkprof.createTarget(temp,Source=source,RGBScale=rgbScale,PaperSizeMm=[w.Value h.Value],PaperLayout=metadata,SpacerMode="bw");
   images=inkprof.internal.previewFiles(m);
   view=uifigure('Name',sprintf('Paper preview: %d actual page(s)',m.pageCount),'Position',[200 160 800 600],'WindowStyle','modal');
   grid=uigridlayout(view,[2 1]);grid.RowHeight={'1x',35};im=uiimage(grid,'ScaleMethod','fit');
   pager=inkprof.internal.previewPager(grid,im);data=cell(1,numel(images));
   for k=1:numel(images),data{k}=imread(fullfile(temp,images(k)));end
   pager.setImages(data);status.Text=sprintf('Actual preview: %d page(s). No target saved.',m.pageCount);
  catch err,uialert(f,err.message,'Paper preview');end
  previewButton.Enable='on';
 end
 function accept(~,~)
  if isempty(selected),return;end
  if w.Value>scan.Value||h.Value>len.Value,uialert(f,'Dimensions exceed your measurement limits.','Paper layout');return;end
  choice=struct('schemaVersion',1,'documentType',"inkprof.paper-layout",'sourcePatchCount',count, ...
   'paperSizeMm',[w.Value h.Value],'proposal',selected,'edited',~isequal([w.Value h.Value],selected.sizeMm), ...
   'preferences',struct('MaxScanMm',scan.Value,'MaxLengthMm',len.Value,'RollWidthMm',roll.Value), ...
   'pageCountStatus',"estimated; manifest contains actual page count");
  uiresume(f);
 end
end

function removePreview(folder)
if isfolder(folder),rmdir(folder,'s');end
end
