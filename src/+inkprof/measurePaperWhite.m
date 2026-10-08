% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function referenceFile=measurePaperWhite(inputFolder,options)
%MEASUREPAPERWHITE Approve native i1Pro2 M0 readings of blank target stock.
arguments
 inputFolder (1,1) string
 options.MeasurementCondition (1,1) struct = struct
 options.ArgyllBin (1,1) string = ""
 options.PythonExecutable (1,1) string = ""
end
inputFolder=inkprof.internal.absolutePath(inputFolder);
source=jsondecode(fileread(fullfile(inputFolder,'profile-input.json')));
c=options.MeasurementCondition;if isempty(fieldnames(c)),c=source.measurementCondition;end
assert(isfield(c,'interpreted')&&string(c.interpreted)=="M0"&&isfield(c,'instrument')&&string(c.instrument)=="X-Rite i1 Pro 2", ...
 'inkprof:FWA','Blank-paper acquisition currently requires verified native i1Pro2 M0 data.');
doc=inkprof.importCgats(fullfile(inputFolder,'profiling.ti3'));standard="";
for k=1:numel(doc.tables(1).metadata)
 item=doc.tables(1).metadata{k};if item(1)=="DEVCALSTD",standard=item(2);end
end
assert(any(standard==["XRGA","XRDI","GMDI"]),'inkprof:FWA','The target calibration standard must be recorded.');
base=fullfile(inputFolder,'paper-white-references',string(java.util.UUID.randomUUID()));mkdir(base);
referenceFile="";candidates=strings(0,1);session=[];closed=false;kind="";attempt="";
fig=uifigure('Name','InkProf - Measure blank paper','Position',[180 150 760 570],'WindowStyle','modal','Tag','InkProfPaperWhite');
g=uigridlayout(fig,[5 1]);g.RowHeight={95,55,'1x',50,50};
uilabel(g,'Text','Use unprinted paper from the same stock, with the same backing as the target. Close other instrument sessions. Measure at several clean locations. Averaging reduces random variation but cannot recover missing UV excitation. Native i1Pro2 M0; this is not a measured M1 reference.','WordWrap','on');
status=uilabel(g,'Text','Press Start to connect and calibrate.','WordWrap','on');
log=uitextarea(g,'Editable','off','FontName','Monospaced','Value',{'No reference is used until you explicitly accept it.'});
bar=uigridlayout(g,[1 2]);bar.Padding=[0 0 0 0];
action=uibutton(bar,'Text','Start / next location','ButtonPushedFcn',@trigger,'Tag','PaperWhiteAction');
accept=uibutton(bar,'Text','Accept mean reference','Enable','off','ButtonPushedFcn',@save,'Tag','PaperWhiteAccept');
uibutton(g,'Text','Cancel','ButtonPushedFcn',@close);
tick=timer('ExecutionMode','fixedSpacing','Period',.2,'BusyMode','drop','TimerFcn',@poll);
fig.CloseRequestFcn=@close;fig.DeleteFcn=@cleanup;
uiwait(fig);
 function trigger(~,~)
  try
   action.Enable='off';accept.Enable='off';
   if isempty(session)||~session.isRunning()
    if ~isempty(session),delete(session);end
    attempt=fullfile(base,'reading-'+string(numel(candidates)+1)+'-'+string(java.util.UUID.randomUUID()));mkdir(attempt);
    serial="";if isfield(c,'instrumentSerial'),serial=string(c.instrumentSerial);end
    req=struct('schemaVersion',1,'documentType',"inkprof.spot-request",'calibrationStandard',standard,'instrumentSerial',serial,'condition',"M0",'identityMethod',"Operator selected blank paper",'port',0);
    inkprof.internal.writeJson(fullfile(attempt,'request.json'),req);
    session=inkprof.SpotReadSession(attempt,ArgyllBin=options.ArgyllBin,PythonExecutable=options.PythonExecutable);
    if strcmp(tick.Running,'off'),start(tick);end
   else
    session.sendKey(' ');
   end
   status.Text='Working. Follow calibration prompts and keep the instrument stationary.';
  catch err,status.Text=string(err.message);action.Enable='on';end
 end
 function poll(~,~)
  if closed||isempty(session),return;end
  try
   events=session.poll(0,false);
   for j=1:numel(events)
    e=events{j};
    switch string(e.event)
     case 'output'
      values=log.Value;if ischar(values),values={values};end
      values=[values;cellstr(splitlines(string(e.text)))];log.Value=values(max(1,end-90):end);
     case 'state'
      kind=string(e.kind);
      if any(kind==["calibration","calibrationRetry"]),action.Text='Calibrate';action.Enable='on';status.Text='Place the instrument on its calibration reference, then click Calibrate.';
      elseif kind=="ready",action.Text='Measure blank paper';action.Enable='on';status.Text='Place on a clean blank-paper location. Click Measure blank paper. Do not swipe.';
      elseif kind=="retry",action.Text='Retry';action.Enable='on';end
     case 'candidate'
      candidates(end+1)=string(e.path);delete(session);session=[];
      action.Text='Measure next location';action.Enable='on';accept.Enable='on';status.Text=sprintf('%d native M0 readings saved. Move to another clean location or accept the mean.',numel(candidates));
     case 'error'
      status.Text=string(e.message);action.Enable='on';if ~isempty(candidates),accept.Enable='on';end
    end
   end
  catch err,status.Text=string(err.message);action.Enable='on';end
 end
 function save(~,~)
  if isempty(candidates),return;end
  choice=uiconfirm(fig,sprintf('Accept %d readings as blank paper of the same stock and backing? The mean is an M0-based fluorescence estimate, not a direct UV or native M1 measurement.',numel(candidates)), ...
   'Approve paper-white reference','Options',{'Accept','Cancel'},'DefaultOption',1,'CancelOption',2);
  if choice~="Accept",return;end
  try
   runtime=inkprof.checkPython(PythonExecutable=options.PythonExecutable);paths=inkprof.paths();output=fullfile(base,'paper-white-reference.json');
   result=inkprof.internal.runTool(runtime.executable,[fullfile(paths.Root,'analysis','fwa.py'),"--output",output,reshape(candidates,1,[])],base,30);
   assert(result.exitCode==0,'inkprof:FWA','Cannot create blank-paper reference: %s',result.output);
   referenceFile=output;close();
  catch err,uialert(fig,err.message,'Paper-white reference');end
 end
 function close(varargin)
  closed=true;if isgraphics(fig),uiresume(fig);delete(fig);end
 end
 function cleanup(varargin)
  try,stop(tick);delete(tick);catch,end
  if ~isempty(session),try,session.stop();delete(session);catch,end,end
 end
end
