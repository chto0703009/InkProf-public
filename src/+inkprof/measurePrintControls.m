% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function reportFile=measurePrintControls(folder,options)
% Stationary per-page controls, saved separately from the chart's fit points.
arguments
 folder (1,1) string
 options.SourceTI3 (1,1) string = ""
 options.ArgyllBin (1,1) string = ""
 options.PythonExecutable (1,1) string = ""
 options.Port (1,1) double {mustBeInteger,mustBeNonnegative} = 0
 options.ThresholdDeltaE00 (1,1) double {mustBePositive,mustBeFinite} = 5
end
chart=jsondecode(fileread(fullfile(folder,'chart.json')));reportFile="";
if ~isfield(chart,'printControls'),return;end % Legacy prints have no requirement.
controlFile=fullfile(folder,chart.printControls.file);
assert(inkprof.internal.sha256(controlFile)==string(chart.printControls.sha256),'inkprof:Integrity','Print-control definition changed.');
controls=jsondecode(fileread(controlFile));
source=options.SourceTI3;if source=="",source=fullfile(folder,'chart.ti3');end
standard="XRGA";serial="";
if isfile(source)
doc=inkprof.importCgats(source);standard="";
for k=1:numel(doc.tables(1).metadata)
 t=doc.tables(1).metadata{k};if t(1)=="DEVCALSTD",standard=t(2);end
end
assert(any(standard==["XRGA","XRDI","GMDI"]),'inkprof:Condition','Control measurement requires a known calibration standard.');
condition=inkprof.internal.measurementCondition(fileparts(source),chart.sourceSHA256,doc.tables(1).metadata);
assert(condition.interpreted=="M0"&&contains(replace(string(condition.instrument),' ',''),'i1Pro2'), ...
 'inkprof:Condition','Page controls currently require native i1 Pro 2 M0.');
serial="";if isfield(condition,'instrumentSerial'),serial=string(condition.instrumentSerial);end
end
project=inkprof.internal.findProject(folder);context=struct('projectId',"",'printing',struct);
referenceFile=fullfile(fileparts(chart.sourcePath),'print-control-reference.json');
context.projectId=chart.sourceSHA256;
if project~=""
 p=jsondecode(fileread(fullfile(project,'inkprof-project.json')));context.projectId=p.projectId;
 for field=["printer","paper","paperSurface","finish","media","quality","colorManagement","highSpeed","ink","driver","printPath","printerCoating","coatingSettings"]
  if isfield(p.printing,field),context.printing.(field)=p.printing.(field);end
 end
 referenceFile=fullfile(project,'print-control-reference.json');
end
readings=struct('colour',{},'page',{},'rgbPercent',{},'rectMm',{},'tiff',{});
for k=1:numel(controls.patches)
 q=controls.patches(k);readings(k)=struct('colour',q.label,'page',q.page,'rgbPercent',q.rgbPercent,'rectMm',q.rectMm,'tiff',q.tiff);
end
base=fullfile(folder,'print-control-spots',string(java.util.UUID.randomUUID()));mkdir(base);
request=struct('documentType',"inkprof.print-control-test",'schemaVersion',1,'calibrationStandard',standard, ...
 'instrumentSerial',serial,'condition',"M0",'port',options.Port,'readings',readings,'context',context,'pageCount',numel(chart.passesInStrips));
inkprof.internal.writeJson(fullfile(base,'request.json'),request);
session=[];closed=false;busy=false;index=1;referenceUsed="";check=struct;
sessionBase=base;pendingIndices=1:numel(readings);selected=1;complete=false;
fig=uifigure('Name','InkProf - Page RGB print controls','Position',[160 110 850 690],'WindowStyle','modal','Tag','InkProfPrintControls');
g=uigridlayout(fig,[7 1]);g.RowHeight={35,100,65,'1x',55,38,50};g.Padding=[18 16 18 16];
uilabel(g,'Text','Separate RGB print checks','FontSize',22,'FontWeight','bold');
uilabel(g,'Text','On new targets, the R, G and B squares sit at the upper right above the profiling grid. Older targets have them below the grid. Measure one square at a time with i1 Pro 2 stationary at its centre, using the same backing. Do not swipe. Click Measure square, not the instrument button. Follow the displayed page and colour. If placement or order was wrong, restart the checks or select a measured row and remeasure it here. These readings never enter the profiling data.','WordWrap','on');
status=uilabel(g,'Text','Start to connect and calibrate.','WordWrap','on','FontSize',18,'FontWeight','bold','Tag','printControlStatus');
table=uitable(g,'Data',cell(numel(readings),4),'ColumnName',{'Page','Control','Status','Delta E00'}, ...
 'ColumnWidth',{70,90,450,'auto'},'ColumnEditable',false,'RowName',{},'Tag','printControlTable','CellSelectionCallback',@selectReading);
for k=1:numel(readings),table.Data(k,:)={readings(k).page,char(readings(k).colour),'Waiting',''};end
notice=uilabel(g,'Text','An approved reference from a known-correct print is needed for an absolute print check. Without one, pages are compared with page 1. Default review threshold: 5 Delta E00.','WordWrap','on');
retrybar=uigridlayout(g,[1 2]);retrybar.Padding=[0 0 0 0];
redo=uibutton(retrybar,'Text','Remeasure selected square','Enable','off','Tag','printControlRemeasure','ButtonPushedFcn',@remeasureSelected);
restart=uibutton(retrybar,'Text','Restart all RGB checks','Enable','off','Tag','printControlRestart','ButtonPushedFcn',@restartAll);
bar=uigridlayout(g,[1 4]);bar.Padding=[0 0 0 0];bar.ColumnWidth={'1x',220,140,'1x'};
action=uibutton(bar,'Text','Start RGB checks','Tag','printControlAction','ButtonPushedFcn',@trigger);
reference=uibutton(bar,'Text','Approve as print reference','Enable','off','Tag','printControlReference','ButtonPushedFcn',@approveReference);
override=uibutton(bar,'Text','Override…','Enable','off','Tag','printControlOverride','ButtonPushedFcn',@openOverride);
finish=uibutton(bar,'Text','Skip / close','Tag','printControlClose','ButtonPushedFcn',@closeDialog);
poller=timer('ExecutionMode','fixedSpacing','Period',.15,'BusyMode','drop','TimerFcn',@poll);
fig.CloseRequestFcn=@closeDialog;fig.DeleteFcn=@cleanup;
uiwait(fig);
 function trigger(~,~)
  if busy||closed,return;end
  busy=true;action.Enable='off';restart.Enable='off';redo.Enable='off';
  try
   if isempty(session)
    session=inkprof.SpotReadSession(sessionBase,ArgyllBin=options.ArgyllBin,PythonExecutable=options.PythonExecutable,PrintControls=true);
    start(poller);
   else,session.sendKey(' ');end
   status.Text='Instrument working. Wait for the next instruction.';
  catch err,status.Text=string(err.message);restart.Enable='on';end
  busy=false;
 end
 function poll(~,~)
  if closed||busy||isempty(session),return;end
  busy=true;
  try
   events=session.poll(0,false);
   for j=1:numel(events)
    e=events{j};
    switch string(e.event)
     case 'state'
      restart.Enable='off';
      if any(string(e.kind)==["calibration","calibrationRetry"])
       action.Text='Calibrate';action.Enable='on';restart.Enable='on';status.BackgroundColor=[.94 .94 .94];status.FontColor=[0 0 0];status.Text='Place i1 Pro 2 on its white calibration reference, then click Calibrate.';
      elseif any(string(e.kind)==["ready","retry"])&&index<=numel(pendingIndices)
       action.Text='Measure square';action.Enable='on';restart.Enable='on';q=readings(pendingIndices(index));
       showSquare(q);
       action.Text=sprintf('Measure page %d - %s',q.page,string(q.colour));
       status.Text=sprintf('PAGE %d — %s\nKeep the instrument still at the centre. Then click Measure page %d - %s. (%d/%d)',q.page,string(q.colour),q.page,string(q.colour),index,numel(pendingIndices));
      else,action.Enable='off';end
     case 'candidate'
      row=pendingIndices(index);
      if sessionBase~=base
       copyfile(fullfile(sessionBase,sprintf('reading-%03d.json',index)),fullfile(base,sprintf('reading-%03d.json',row)));
      end
      table.Data{row,3}='Measured and saved separately';index=index+1;
     case 'completed'
      stop(poller);action.Enable='off';analyse();complete=true;redo.Enable='on';restart.Enable='on';updateSelected();finish.Text='Continue with saved chart';
      if ~check.referenceAvailable&&check.status~="review-required",reference.Enable='on';end
      if check.complete&&check.status=="review-required",override.Enable='on';end
     case 'error'
      stop(poller);action.Enable='off';restart.Enable='on';status.Text=string(e.message);notice.Text='Chart readings are retained. Print controls require review; partial spots are also retained.';
    end
   end
  catch err,stop(poller);action.Enable='off';restart.Enable='on';status.Text=string(err.message);end
  busy=false;
 end
 function selectReading(~,event)
  if ~isempty(event.Indices),selected=event.Indices(1,1);updateSelected();end
 end
 function updateSelected()
  q=readings(selected);redo.Text=sprintf('Remeasure page %d - %s',q.page,string(q.colour));
 end
 function showSquare(q)
  switch string(q.colour)
   case "R",status.BackgroundColor=[.8 .08 .08];status.FontColor=[1 1 1];
   case "G",status.BackgroundColor=[.15 .8 .15];status.FontColor=[0 0 0];
   case "B",status.BackgroundColor=[.08 .08 .8];status.FontColor=[1 1 1];
  end
 end
 function remeasureSelected(~,~)
  if ~complete||busy||closed,return;end
  beginAgain(selected);
 end
 function restartAll(~,~)
  if busy||closed,return;end
  beginAgain(1:numel(readings));
 end
 function beginAgain(indices)
  busy=true;stop(poller);
  if ~isempty(session),delete(session);session=[];end
  previous=base;base=fullfile(folder,'print-control-spots',string(java.util.UUID.randomUUID()));mkdir(base);
  inkprof.internal.writeJson(fullfile(base,'request.json'),request);
  if numel(indices)<numel(readings)
   for row=1:numel(readings)
    if ~ismember(row,indices)
     copyfile(fullfile(previous,sprintf('reading-%03d.json',row)),fullfile(base,sprintf('reading-%03d.json',row)));
    end
   end
   sessionBase=fullfile(base,'replacement');mkdir(sessionBase);
   subset=request;subset.readings=num2cell(readings(indices));
   inkprof.internal.writeJson(fullfile(sessionBase,'request.json'),subset);
  else
   sessionBase=base;
   for row=1:numel(readings),table.Data(row,3:4)={'Waiting',''};end
  end
  % Retain previous evidence, but never let an old pass authorize an incomplete retry.
  active=fullfile(folder,'print-control-check.json');
  if isfile(active),copyfile(active,fullfile(previous,'superseded-check.json'));delete(active);end
  inkprof.internal.writeJson(fullfile(base,'retry.json'),struct('previousSpotFolder',previous,'remeasuredIndices',indices));
  for row=reshape(indices,1,[]),table.Data(row,3:4)={'Waiting for remeasurement',''};end
  index=1;pendingIndices=indices;complete=false;referenceUsed="";check=struct;reportFile="";
  reference.Enable='off';override.Enable='off';redo.Enable='off';restart.Enable='off';
  finish.Text='Skip / close';action.Text='Start RGB checks';action.Enable='on';
  q=readings(indices(1));showSquare(q);status.Text=sprintf('Remeasure page %d, %s. Start RGB checks, calibrate, then measure the displayed square.',q.page,string(q.colour));
  notice.Text='Previous readings are retained as evidence. The revised check must finish before continuing.';
  busy=false;
 end
 function analyse()
  paths=inkprof.paths();args=[base,fullfile(base,'check.json'),"--threshold",string(options.ThresholdDeltaE00)];
  if referenceFile~=""&&isfile(referenceFile)
   saved=jsondecode(fileread(referenceFile));
   if isequal(saved.context,context)&&string(saved.calibrationStandard)==standard
    referenceUsed=referenceFile;args(end)=string(saved.thresholdDeltaE00);args=[args,"--reference",referenceFile];
   else,notice.Text='Previous reference uses different printer/paper/settings. A new approved reference is required.';end
  end
  inkprof.runPython(fullfile(paths.Root,'analysis','print_controls.py'),args,PythonExecutable=options.PythonExecutable,RequiredModules="numpy");
  check=jsondecode(fileread(fullfile(base,'check.json')));publish();
  for k=1:numel(check.readings)
   q=check.readings(k);table.Data{k,4}=sprintf('%.3f',q.deltaE00);
   table.Data{k,3}='Within review threshold';if q.flagged,table.Data{k,3}='REVIEW - unexpected print colour';end
  end
  status.BackgroundColor=[.94 .94 .94];status.FontColor=[0 0 0];
  status.Text="RGB print check: "+string(check.status)+". These readings do not affect profile fitting.";
 end
 function publish()
  check.definitionSHA256=chart.printControls.sha256;check.spotFolder=extractAfter(base,strlength(string(folder))+1);
  if referenceUsed~="",check.referenceSHA256=inkprof.internal.sha256(referenceUsed);end
  reportFile=fullfile(folder,'print-control-check.json');inkprof.internal.writeJson(reportFile,check);
 end
 function approveReference(~,~)
  choice=uiconfirm(fig,'Only approve if you have independently checked that this print used the correct paper and colour-management settings. The measured RGB colours will become the reference for this project.','Approve known-correct print','Options',{'Cancel','Approve'},'DefaultOption',1,'CancelOption',1);
  if ~strcmp(choice,'Approve'),return;end
  xyz=inkprof.internal.printControlReferenceXYZ(check.readings);
  value=struct('documentType',"inkprof.print-control-reference",'schemaVersion',1,'context',context, ...
   'calibrationStandard',standard,'instrumentSerial',serial,'xyz',xyz,'thresholdDeltaE00',options.ThresholdDeltaE00, ...
   'approval',"User approved known-correct print",'sourceCheckSHA256',inkprof.internal.sha256(reportFile));
  inkprof.internal.writeJson(referenceFile,value);reference.Enable='off';status.Text='Approved project print reference saved. Future pages are compared with these RGB values.';
  check.status="reference-approved";check.referenceApproval=value.approval;publish();
 end
 function openOverride(~,~)
  dialog=uifigure('Name','Override RGB print check','Position',[220 180 620 350], ...
   'WindowStyle','modal','Tag','InkProfPrintControlOverride');
  layout=uigridlayout(dialog,[4 1]);layout.RowHeight={65,25,'1x',40};
  uilabel(layout,'Text','The RGB check found deviations. Explain why you accept this print and want to continue. The measurements, threshold and reference remain unchanged.','WordWrap','on');
  uilabel(layout,'Text','Reason (required):');
  reason=uitextarea(layout,'Tag','printControlOverrideReason');
  buttons=uigridlayout(layout,[1 2]);buttons.Padding=[0 0 0 0];
  uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(dialog));
  uibutton(buttons,'Text','Save override and continue','Tag','printControlOverrideSave','ButtonPushedFcn',@saveOverride);
  function saveOverride(~,~)
   explanation=strtrim(join(string(reason.Value),newline));
   if strlength(explanation)==0
    uialert(dialog,'Enter a reason before saving the override.','Reason required');return;
   end
   check=inkprof.internal.overridePrintControls(folder,explanation);
   override.Enable='off';status.Text='RGB check overridden with a recorded reason. Continue to strip measurement.';
   notice.Text="Override reason: "+explanation;
   delete(dialog);
  end
 end
 function closeDialog(varargin)
  if busy,return;end
  closed=true;if isgraphics(fig),uiresume(fig);delete(fig);end
 end
 function cleanup(varargin)
  try,stop(poller);delete(poller);catch,end
  if ~isempty(session),try,delete(session);catch,end,end
 end
end
