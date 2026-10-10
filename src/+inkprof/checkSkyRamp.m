% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [report,reportFile]=checkSkyRamp(jobFolder,options)
%CHECKSKYRAMP Blue-sky gradient (L* 38-70, banding window L* 40-55) through
%the profile's B2A and back. Numerical diagnostic only; see analysis/sky_ramp.py.
arguments
 jobFolder (1,1) string = ""
 options.ShowDialog (1,1) logical = true
end
report=[];reportFile="";
if jobFolder==""
 p=uigetdir(pwd,'Select ICC job folder');if isequal(p,0),return;end;jobFolder=string(p);
end
jobFolder=inkprof.internal.absolutePath(jobFolder);paths=inkprof.paths();
status=jsondecode(fileread(fullfile(jobFolder,'status.json')));
profile=fullfile(jobFolder,'result','profile.icc');
assert(string(status.status)=="succeeded"&&isfile(profile)&&inkprof.internal.sha256(profile)==string(status.profileSHA256), ...
 'inkprof:SkyRamp','Select a successful, unchanged ICC job.');
bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'xicclu');if ispc,exe=exe+".exe";end
assert(isfile(exe),'inkprof:Argyll','xicclu not found.');
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
fprintf('InkProf: blue-sky gradient check (relative colorimetric and perceptual)...\n');
inkprof.runPython(fullfile(paths.Root,'analysis','sky_ramp.py'),[profile,exe,fullfile(w,'report')], ...
 RequiredModules="numpy",TimeoutSeconds=300);
report=jsondecode(fileread(fullfile(w,'report','sky-ramp.json')));
parent=fullfile(jobFolder,'checks');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,string(java.util.UUID.randomUUID()));
[ok,msg]=movefile(fullfile(w,'report'),folder);assert(ok,'inkprof:IO','%s',msg);
reportFile=fullfile(folder,'sky-ramp.json');
inkprof.internal.recordProjectStep(folder,"Blue-sky gradient diagnostic (numerical only)");
s=report.summary.relativeColorimetric;
fprintf('Relative colorimetric: max RGB second difference %.4f pp (L* 40-55: %.4f), channel reversals in L* 40-55: %d.\nReport: %s\n', ...
 s.secondDiffMax,s.secondDiffBandMax,s.reversalsBand,reportFile);
if ~options.ShowDialog,return;end
f=uifigure('Name','InkProf - Blue-sky gradient','Position',[150 100 1200 560],'WindowStyle','alwaysontop','Visible','off');
g=uigridlayout(f,[6 1]);g.RowHeight={30,40,'1x',52,52,36};g.Padding=[16 16 16 16];
uilabel(g,'Text','Blue-sky gradient | L* 38–70','FontSize',18,'FontWeight','bold');
uilabel(g,'Text',"Profile: "+profile+newline+"SHA-256: "+string(report.profileSHA256),'WordWrap','on','FontSize',11);
p=report.paths;rows=cell(numel(p),8);
for k=1:numel(p)
 a=p(k);ratio='—';
 if ~isempty(a.colourStepMaxOverMedian),ratio=sprintf('%.2f',a.colourStepMaxOverMedian);end
 rows(k,:)={a.intent,a.path,sprintf('%.4f',a.rgbSecondDifferencePercent.max), ...
  sprintf('%.4f',a.rgbSecondDifferencePercentBandWindow.max), ...
  sprintf('%d',a.channelReversalsBandWindow),ratio,sprintf('%d',a.longest8bitPlateau), ...
  sprintf('%.1f',a.worstSecondDifference.L)};
end
t=uitable(g,'Data',rows,'ColumnName',{'Rendering intent','Sky path','RGB curvature (pp)','Curvature 40–55 (pp)', ...
 'Reversals 40–55','ΔE00 max / median','8-bit plateau','Peak at L*'}, ...
 'ColumnWidth',{170,110,155,165,140,160,110,90},'RowName',{},'ColumnEditable',false,'FontSize',13);
addStyle(t,uistyle('HorizontalAlignment','right'),'column',3:8);
addStyle(t,uistyle('BackgroundColor',[0.94 0.96 0.98]),'row',2:2:numel(p));
uilabel(g,'Text',['Curvature = maximum absolute RGB second difference, in percentage points (pp). ' ...
 '40–55 = L* banding window. ΔE00 max / median = colour-step ratio. ' ...
 '8-bit plateau = longest run of samples with unchanged rounded RGB codes.'],'WordWrap','on','FontSize',12);
uilabel(g,'Text',string(report.caveat),'WordWrap','on','FontSize',12);
uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));f.Visible='on';drawnow;focus(f);
end
