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
fig=uifigure('Name','InkProf - Page RGB print controls','Position',[160 110 850 620],'WindowStyle','modal','Tag','InkProfPrintControls');
g=uigridlayout(fig,[6 1]);g.RowHeight={35,85,65,'1x',55,50};g.Padding=[18 16 18 16];
uilabel(g,'Text','Separate RGB print checks','FontSize',22,'FontWeight','bold');
uilabel(g,'Text','These R, G and B squares sit below the profiling grid. Measure one square at a time with i1 Pro 2 stationary at its centre, using the same backing. Do not swipe. Click Measure square, not the instrument button. These readings never enter the profiling data.','WordWrap','on');
status=uilabel(g,'Text','Start to connect and calibrate.','WordWrap','on','Tag','printControlStatus');
table=uitable(g,'Data',cell(numel(readings),4),'ColumnName',{'Page','Control','Status','Delta E00'}, ...
 'ColumnWidth',{70,90,450,'auto'},'ColumnEditable',false,'RowName',{},'Tag','printControlTable');
for k=1:numel(readings),table.Data(k,:)={readings(k).page,char(readings(k).colour),'Waiting',''};end
notice=uilabel(g,'Text','An approved reference from a known-correct print is needed for an absolute print check. Without one, pages are compared with page 1. Default review threshold: 5 Delta E00.','WordWrap','on');
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
  busy=true;action.Enable='off';
  try
   if isempty(session)
    session=inkprof.SpotReadSession(base,ArgyllBin=options.ArgyllBin,PythonExecutable=options.PythonExecutable,PrintControls=true);
    start(poller);
   else,session.sendKey(' ');end
   status.Text='Instrument working. Wait for the next instruction.';
  catch err,status.Text=string(err.message);end
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
      if any(string(e.kind)==["calibration","calibrationRetry"])
       action.Text='Calibrate';action.Enable='on';status.Text='Place i1 Pro 2 on its white calibration reference, then click Calibrate.';
      elseif any(string(e.kind)==["ready","retry"])&&index<=numel(readings)
       action.Text='Measure square';action.Enable='on';q=readings(index);
       status.Text=sprintf('Page %d - %s square, below the profiling grid. Place the instrument at its centre. Click Measure square. (%d/%d)',q.page,string(q.colour),index,numel(readings));
      else,action.Enable='off';end
     case 'candidate'
      table.Data{index,3}='Measured and saved separately';index=index+1;
     case 'completed'
      stop(poller);action.Enable='off';analyse();finish.Text='Continue with saved chart';
      if ~check.referenceAvailable&&check.status~="review-required",reference.Enable='on';end
      if check.complete&&check.status=="review-required",override.Enable='on';end
     case 'error'
      stop(poller);action.Enable='off';status.Text=string(e.message);notice.Text='Chart readings are retained. Print controls require review; partial spots are also retained.';
    end
   end
  catch err,stop(poller);action.Enable='off';status.Text=string(err.message);end
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
