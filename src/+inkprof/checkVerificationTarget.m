% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [report,reportFile]=checkVerificationTarget(verificationFile,measurementFile,options)
%CHECKVERIFICATIONTARGET C3 diagnostic print analysis against desired D50 Lab.
% Does not approve a profile or assert that the print chain is colour unmanaged.
arguments
 verificationFile (1,1) string = ""
 measurementFile (1,1) string = ""
 options.ShowDialog (1,1) logical = true
 options.PrintSettings (1,1) struct = struct()
end
report=[];reportFile="";
if verificationFile==""
 [f,p]=uigetfile('*.json','Select C2 verification.json');if isequal(f,0),return;end;verificationFile=fullfile(p,f);
end
if measurementFile==""
 [f,p]=uigetfile('*.json','Select saved measurement revision JSON');if isequal(f,0),return;end;measurementFile=fullfile(p,f);
end
verificationFile=inkprof.internal.absolutePath(verificationFile);
measurementFile=inkprof.internal.absolutePath(measurementFile);
paths=inkprof.paths();bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'profcheck');if ispc,exe=exe+".exe";end
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
inkprof.internal.writeJson(fullfile(w,'print-settings.json'),options.PrintSettings);
fprintf('InkProf C3: checking identities and comparing measured spectra with desired D50 Lab...\n');
inkprof.runPython(fullfile(paths.Root,'analysis','verification_check.py'), ...
 [verificationFile,measurementFile,exe,fullfile(w,'report'),"--print-settings",fullfile(w,'print-settings.json')], ...
 RequiredModules=["numpy","colour","tifffile","imagecodecs"],TimeoutSeconds=150);
report=jsondecode(fileread(fullfile(w,'report','verification-check.json')));
parent=fullfile(fileparts(verificationFile),'checks');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,string(java.util.UUID.randomUUID()));
[ok,msg]=movefile(fullfile(w,'report'),folder);assert(ok,'inkprof:IO','%s',msg);
reportFile=fullfile(folder,'verification-check.json');
inkprof.internal.recordProjectStep(folder,"C3 diagnostic print comparison; print chain unverified; no profile approval");
s=report.summary;
fprintf('InkProf C3: %d unique patches; mean dE00 %.4f, p95 %.4f, max %.4f.\n',s.count,s.mean,s.p95,s.max);
fprintf('Measurement analysed. Review results, print settings and acceptance criteria before approving the profile in the workflow.\nReport: %s\n',reportFile);
cmWarning="";
if isfield(report,'colourManagementCheck')&&isfield(report.colourManagementCheck,'suspectedDoubleColourManagement')&&report.colourManagementCheck.suspectedDoubleColourManagement
    cmWarning=string(report.colourManagementCheck.message);warning('inkprof:DoubleColourManagement','%s',cmWarning);
end
if ~options.ShowDialog,return;end
f=uifigure('Name','InkProf - C3 print verification','Position',[90 90 1200 750],'WindowStyle','alwaysontop','Visible','off');
g=uigridlayout(f,[7 1]);g.RowHeight={70,40,100,35,'1x',50,35};
uilabel(g,'Text',sprintf('Measurement analysis: %d unique patches | mean %.1f | median %.1f | p95 %.1f | max %.1f dE00\nMeasured spectra versus desired absolute D50 Lab.',s.count,s.mean,s.median,s.p95,s.max),'WordWrap','on');
if cmWarning==""
 uilabel(g,'Text','Measurement analysed. Review the results and confirm the print settings before approving the profile in the workflow.','FontColor',[.1 .22 .3],'WordWrap','on');
else
 g.RowHeight{2}=75;uilabel(g,'Text',"⚠ "+cmWarning,'FontColor',[.7 0 0],'FontWeight','bold','WordWrap','on');
end
d=[];if isfield(report,'chainDiagnostics'),d=report.chainDiagnostics;end
chainText=inkprof.internal.verificationChainSummaryText(d);
uilabel(g,'Text',chainText,'WordWrap','on');
drop=uidropdown(g,'Items',{'All patches','Unique patches','Gray','Colour','Challenge','Repeat','Model-reachable unique'},'ValueChangedFcn',@(~,~)fill());
table=uitable(g,'ColumnName',{'Page','Coordinate','ID','Role','Measured vs desired (dE00)','Model vs measurement (dE00)','Desired L*','Desired a*','Desired b*','Measured L*','Measured a*','Measured b*','Inverse round-trip dE00','TIFF RGB16 code error'}, ...
 'ColumnWidth',{45,75,50,75,185,200,80,80,80,80,80,80,170,160},'RowName',{},'ColumnEditable',false);
addStyle(table,uistyle('HorizontalAlignment','right'),'column',[1,3,5:14]);
uilabel(g,'Text',reportFile,'WordWrap','on');uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
fill();f.Visible='on';drawnow;focus(f);
 function fill()
  p=report.patches;[~,order]=sort([p.deltaE00],'descend');p=p(order);roles=string({p.role});
  switch drop.Value
   case 'Unique patches',p=p(~ismember(roles,["repeat","paperwhite"]));
   case 'Model-reachable unique',p=p(roles~="repeat" & string({p.gamutAssessment})=="model-reachable");
   case {'Gray','Colour','Challenge','Repeat'},p=p(roles==lower(string(drop.Value)));
  end
  rows=cell(numel(p),14);
  for k=1:numel(p)
   a=p(k);values=[a.deltaE00,a.predictedDeltaE00,reshape(a.desiredLab,1,[]),reshape(a.measuredLab,1,[])];
   % Format only the display; keep the report's full measurement precision.
   rows(k,:)=[{sprintf('%d',a.page),a.coordinate,char(string(a.sampleId)),a.role}, ...
       arrayfun(@(v)sprintf('%.1f',v),values,'UniformOutput',false),{'unavailable','unavailable'}];
   if isfield(report,'chainDiagnostics')
    q=report.chainDiagnostics.patches;idx=find(string({q.sampleId})==string(a.sampleId),1);
    if ~isempty(idx)
     rows{k,13}=sprintf('%.1f',q(idx).inverseRoundtripDE00);
     if isfield(q,'tiffMaxChannelCodeError'),rows{k,14}=sprintf('%d',q(idx).tiffMaxChannelCodeError);end
    end
   end
  end
  table.Data=rows;
 end
end
