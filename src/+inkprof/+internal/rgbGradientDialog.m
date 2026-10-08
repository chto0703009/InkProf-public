% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function f=rgbGradientDialog(jobFolder)
%RGBGRADIENTDIALOG Optional, nonblocking numerical gradient explorer.
f=uifigure('Name','InkProf - RGB gradient test','Tag','InkProfRGBGradient', ...
 'Position',[140 80 1120 780],'WindowStyle','alwaysontop','Visible','off');
g=uigridlayout(f,[6 2]);g.RowHeight={50,36,'1x','1x',70,36};g.ColumnWidth={'1x','1x'};
info=uilabel(g,'Text','Test the final regularized ICC along device RGB gradients. Run the check, then choose a path. Numerical smoothness does not prove absence of banding on paper.', ...
 'WordWrap','on');info.Layout.Column=[1 2];
path=uidropdown(g,'Items',{'Run the check first'},'Enable','off','Tag','RGBGradientPath','ValueChangedFcn',@drawPath);
intent=uidropdown(g,'Items',{'relative colorimetric','perceptual'},'Tag','RGBGradientIntent','ValueChangedFcn',@drawPath);
labAxes=uiaxes(g);title(labAxes,'Profile output Lab');xlabel(labAxes,'Position along RGB gradient');
stepAxes=uiaxes(g);title(stepAxes,'Adjacent colour steps (Delta E00)');xlabel(stepAxes,'Position along RGB gradient');
inputAxes=uiaxes(g);title(inputAxes,'Device RGB input');xlabel(inputAxes,'Position along RGB gradient');
curveAxes=uiaxes(g);title(curveAxes,'Lab second difference');xlabel(curveAxes,'Position along RGB gradient');
summary=uitextarea(g,'Editable','off','Value',{'Choose Run RGB check to evaluate nine RGB paths, including three blue gradients.'});summary.Layout.Column=[1 2];
buttons=uigridlayout(g,[1 4]);buttons.Layout.Column=[1 2];buttons.Padding=[0 0 0 0];
runButton=uibutton(buttons,'Text','Run RGB check','Tag','RunRGBGradientCheck','ButtonPushedFcn',@runCheck);
skyButton=uibutton(buttons,'Text','Check blue-sky inverse','ButtonPushedFcn',@runSky);
uibutton(buttons,'Text','Photographic gradients','Tag','RunPhotoGradientCheck','ButtonPushedFcn',@runPhoto);
uibutton(buttons,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
report=[];reportFile="";f.Visible='on';drawnow;focus(f);
 function runCheck(~,~)
  runButton.Enable='off';skyButton.Enable='off';summary.Value={'Evaluating RGB gradients...'};drawnow;
  try
   [report,reportFile]=inkprof.checkRGBGradients(jobFolder,ShowDialog=false);
   if ~isvalid(f),return;end
   path.Items=cellstr(unique(string({report.paths.path}),'stable'));path.Enable='on';drawPath();
  catch err
   if isvalid(f),summary.Value={err.message};uialert(f,err.message,'RGB gradient test');end
  end
  if isvalid(f),runButton.Enable='on';skyButton.Enable='on';end
 end
 function runPhoto(~,~)
  try,inkprof.checkPhotoGradients(jobFolder);catch err,if isvalid(f),uialert(f,err.message,'Photographic gradients');end,end
 end
 function runSky(~,~)
  skyButton.Enable='off';drawnow;
  try,inkprof.checkSkyRamp(jobFolder);catch err,if isvalid(f),uialert(f,err.message,'Blue-sky test');end,end
  if isvalid(f),skyButton.Enable='on';end
 end
 function drawPath(varargin)
  if isempty(report),return;end
  rows=report.paths;idx=find(string({rows.path})==string(path.Value)&string({rows.intent})==string(intent.Value),1);
  r=rows(idx);lab=double(r.lab);rgb=double(r.rgb);t=linspace(0,1,size(lab,1));
  plot(labAxes,t,lab);legend(labAxes,{'L*','a*','b*'},'Location','best');
  plot(inputAxes,t,rgb);legend(inputAxes,{'R','G','B'},'Location','best');ylim(inputAxes,[0 1]);
  de=double(r.colourSteps);plot(stepAxes,t(2:end),de);
  second=sqrt(sum(diff(lab,2,1).^2,2));plot(curveAxes,t(2:end-1),second);
  m=r.metrics;ratio="undefined";if ~isempty(m.colourStepMaxOverMedian),ratio=string(sprintf('%.3g',m.colourStepMaxOverMedian));end
  summary.Value=cellstr(["Max Lab second difference: "+string(sprintf('%.4g',m.labSecondDifference.max))+ ...
   " | Max / median colour step: "+ratio+" | Worst curvature at: "+string(sprintf('%.3f',m.worstAt)); ...
   "Report: "+reportFile;string(report.caveat)]);
 end
end
