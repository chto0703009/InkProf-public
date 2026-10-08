% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function fig=remeasureRow(measurementFile,page,row,options)
%REMEASUREROW Select a printed page/row, reread and review before replacement.
arguments
 measurementFile (1,1) string
 page (1,1) double {mustBeInteger,mustBePositive} = 1
 row (1,1) string = ""
 options.ParentPreview = []
 options.ArgyllBin (1,1) string = ""
 options.PythonExecutable (1,1) string = ""
end
measurementFile=inkprof.internal.absolutePath(measurementFile);
parent=jsondecode(fileread(measurementFile));chart=jsondecode(fileread(fullfile(fileparts(measurementFile),'chart.json')));
assert(isfield(parent.measurementCondition,'settings')&&isfield(parent.measurementCondition.settings,'scanMode'), ...
 'inkprof:Settings','Original scan mode is required for row remeasurement.');
s=parent.measurementCondition.settings;
fig=uifigure('Name','InkProf - Remeasure row','Tag','InkProfRowRemeasurement','Position',[180 100 920 650], ...
 'WindowStyle','modal','Visible','off');
g=uigridlayout(fig,[6 1]);g.RowHeight={40,45,65,45,'1x',40};
uilabel(g,'Text','Remeasure a whole printed row','FontSize',22,'FontWeight','bold');
selection=uigridlayout(g,[1 4]);selection.ColumnWidth={50,100,50,'1x'};selection.Padding=[0 0 0 0];
uilabel(selection,'Text','Page');pageChoice=uidropdown(selection,'Items',cellstr(string(1:numel(chart.passesInStrips))), ...
 'Value',char(string(page)),'Tag','rowRereadPage','ValueChangedFcn',@(~,~)updateRows());
uilabel(selection,'Text','Row');rowChoice=uidropdown(selection,'Tag','rowRereadRow');
uilabel(g,'Text','Use the same printed sheet, backing and instrument. Only this row is measured. The original scan mode and measurement settings are retained. Review the changes before accepting a new revision.','WordWrap','on');
status=uilabel(g,'Text',"Original scan mode: "+string(s.scanMode),'WordWrap','on','Tag','rowRereadStatus');
review=uitable(g,'Data',cell(0,3),'ColumnName',{'Patch','Change ΔE00','New Lab (L*, a*, b*)'}, ...
 'ColumnWidth',{100,150,'auto'},'RowName',{},'Tag','rowRereadReview');
bar=uigridlayout(g,[1 3]);bar.Padding=[0 0 0 0];
startButton=uibutton(bar,'Text','Measure selected row','Tag','rowRereadStart','ButtonPushedFcn',@startRow);
acceptButton=uibutton(bar,'Text','Accept row replacement','Tag','rowRereadAccept','Enable','off','ButtonPushedFcn',@acceptRow);
uibutton(bar,'Text','Discard / Close','ButtonPushedFcn',@closeDialog);
folder="";request=[];session=[];candidateFile="";busy=false;decided=false;
poller=timer('ExecutionMode','fixedSpacing','Period',.2,'BusyMode','drop','TimerFcn',@poll);
fig.CloseRequestFcn=@closeDialog;fig.DeleteFcn=@cleanup;updateRows();
if row~=""&&any(string(rowChoice.Items)==row),rowChoice.Value=char(row);end
fig.Visible='on';drawnow;focus(fig);
 function updateRows()
  numbers=zeros(numel(chart.patches),1);
  for k=1:numel(numbers),numbers(k)=str2double(inkprof.internal.decodeLocation(chart.patches(k).sampleLoc));end
  allRows=unique(numbers,'sorted');counts=double(chart.passesInStrips(:));p=str2double(pageChoice.Value);
  selected=allRows(sum(counts(1:p-1))+(1:counts(p)));rowChoice.Items=cellstr(string(selected));
 end
 function startRow(~,~)
  if busy||folder~="",return;end;busy=true;startButton.Enable='off';
  try
   [folder,request]=inkprof.prepareRowRemeasurement(measurementFile,str2double(pageChoice.Value),string(rowChoice.Value));
   pageChoice.Enable='off';rowChoice.Enable='off';
   threshold=1;if isfield(parent,'pairedReadings'),threshold=parent.pairedReadings.directionComparison.threshold;end
   session=inkprof.MeasurementDialog(fullfile(folder,'session'),ScanMode=string(s.scanMode), ...
    ScanTolerance=s.scanTolerance,Port=s.port,Condition=string(s.requestedCondition), ...
    PairedWarningDeltaE=threshold,ArgyllBin=options.ArgyllBin,PythonExecutable=options.PythonExecutable, ...
    ShowPreview=false,RowContext=request);
   status.Text=sprintf('Measure page %d, row %s in the measurement window. Mode: %s.',request.page,request.row,s.scanMode);
   fig.UserData=struct('attemptFolder',folder,'measurementFile',measurementFile,'measurementDialog',session);
   start(poller);
  catch err
   status.Text=err.message;uialert(fig,err.message,'Row remeasurement');
   if folder=="",startButton.Enable='on';end
  end
  busy=false;
 end
 function poll(~,~)
  if busy||decided||isempty(session),return;end
  if ~isvalid(session)||~isgraphics(session.Figure),stop(poller);status.Text='Measurement window closed. Original values retained.';return;end
  if isempty(session.Result),return;end
  busy=true;stop(poller);
  try
   files=dir(fullfile(folder,'session','measurement-*.json'));
   for entry=reshape(files,1,[])
    path=fullfile(entry.folder,entry.name);value=jsondecode(fileread(path));
    if string(value.sourceTI3SHA256)==string(session.Result.sourceTI3SHA256)&&string(value.chartJSONSHA256)==string(request.runtimeChartSHA256),candidateFile=path;break;end
   end
   assert(candidateFile~=""&&session.Result.complete,'inkprof:Measurement','Complete saved row candidate required.');
   delete(session);session=[];
   paths=inkprof.paths();comparisonFile=fullfile(folder,'comparison.json');
   inkprof.runPython(fullfile(paths.Root,'analysis','row_compare.py'),[measurementFile,candidateFile,fullfile(folder,'request.json'),comparisonFile], ...
    PythonExecutable=options.PythonExecutable,RequiredModules=["numpy","scipy"]);
   comparison=jsondecode(fileread(comparisonFile));rows=comparison.patches;data=cell(numel(rows),3);
   for k=1:numel(rows),data(k,:)={char(rows(k).location),rows(k).deltaE00,char(join(compose('%.3f',reshape(rows(k).newLab,1,[])),"  "))};end
   review.Data=data;
   status.Text=sprintf('Page %d · Row %s · %s | Change: mean %.3f, max %.3f ΔE00. This is change from previous values, not profile accuracy.', ...
    request.page,request.row,s.scanMode,comparison.meanDeltaE00,comparison.maxDeltaE00);
   candidate=jsondecode(fileread(candidateFile));
   if isfield(candidate,'pairedReadings')
    check=candidate.pairedReadings.directionComparison;
    if check.available,status.Text=string(status.Text)+sprintf(' New forward/reverse maximum: %.3f ΔE00.',check.maxDeltaE00);end
   end
   acceptButton.Enable='on';
  catch err,status.Text=err.message;uialert(fig,err.message,'Cannot review row');end
  busy=false;
 end
 function acceptRow(~,~)
  if busy||decided||candidateFile=="",return;end;busy=true;acceptButton.Enable='off';
  try
   [r,path]=inkprof.acceptRowRemeasurement(measurementFile,candidateFile,fullfile(folder,'request.json'));decided=true;
   inkprof.previewMeasurement(fileparts(path),r);
   if ~isempty(options.ParentPreview)&&isgraphics(options.ParentPreview),delete(options.ParentPreview);end
   delete(fig);
  catch err,status.Text=err.message;uialert(fig,err.message,'Cannot accept row');end
  busy=false;
 end
 function closeDialog(~,~)
  if busy,return;end;delete(fig);
 end
 function cleanup(~,~)
  if isvalid(poller),stop(poller);delete(poller);end
  if ~isempty(session)&&isvalid(session),delete(session);end
  if folder~=""&&~decided&&~isfile(fullfile(folder,'decision.json'))
   inkprof.internal.writeJson(fullfile(folder,'decision.json'),struct('decision',"discarded",'parentMeasurementSHA256',request.parentMeasurementSHA256));
  end
 end
end
