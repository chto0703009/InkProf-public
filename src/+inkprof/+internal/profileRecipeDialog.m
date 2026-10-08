% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [accepted,s]=profileRecipeDialog(s,input,hasSpectra,hasXYZ)
accepted=false;dismissed=false;
f=uifigure('Name','InkProf - Profiling recipe','Tag','InkProfProfileRecipe','Visible','off', ...
 'WindowStyle','alwaysontop','Position',[180 40 860 812]);
cleanup=onCleanup(@()closeFigure(f));g=uigridlayout(f,[24 2]);g.ColumnWidth={235,'1x'};g.RowSpacing=5;g.Scrollable='on';
g.RowHeight=[repmat({32},1,21),{70,'1x',36}];
name=field('Profile name',s.name,'RecipeName');description=field('Description',s.description,'RecipeDescription');
keys=["printer","paper","inkType","media","quality","driver","printPath","colorManagement","dryingHours","printerCoating","coatingSettings"];
labels=["Printer","Paper product","Ink type","Driver media setting","Print quality","Driver / version","Printing application / path","Print colour management","Drying time (hours)","Printer coating","Coating settings"];
if ~isfield(s.printing,'dryingHours'),s.printing.dryingHours="unknown";end
for key=["inkType","printerCoating","coatingSettings"],if ~isfield(s.printing,key),s.printing.(key)="unknown";end;end
controls=cell(1,numel(keys));
for k=1:numel(keys),controls{k}=field(labels(k),string(s.printing.(keys(k))),char(keys(k)));end
uilabel(g,'Text','Paper surface');surface=uidropdown(g,'Items',{'unknown','Glossy','Matte','Other'},'Value','unknown','Tag','RecipeSurface');
if any(string(s.printing.paperSurface)==["unknown","Glossy","Matte","Other"]),surface.Value=char(s.printing.paperSurface);end
if isfield(s,'projectPrinting')&&s.projectPrinting
 for j=1:numel(controls),controls{j}.Editable='off';controls{j}.Tooltip='Managed in Project details';end
 surface.Enable='off';surface.Tooltip='Managed in Project details';
end
uilabel(g,'Text','Colour data');mode=uidropdown(g,'Items',{'Spectra (D50 / 2 degrees)','Stored XYZ'}, ...
 'ItemsData',{'spectral','storedXYZ'},'Value',char(s.dataMode),'Tag','RecipeMode');
uilabel(g,'Text','FWA / OBA');
fwa=uicheckbox(g,'Text','Compensate to D50 (also updates Project details)', ...
 'Value',isfield(s.printing,'fwaCompensation')&&isequal(s.printing.fwaCompensation,true),'Tag','RecipeFWA');
if ~isfield(s,'b2aQuality'),s.b2aQuality="high";end
uilabel(g,'Text','Inverse table (B2A)');b2a=uidropdown(g,'Items',{'High (denser)','Medium (baseline)'}, ...
 'ItemsData',{'high','medium'},'Value',char(s.b2aQuality),'Tag','RecipeB2AQuality');
if ~isfield(s,'perceptualCompression'),s.perceptualCompression=20;end
uilabel(g,'Text','Perceptual compression (%)');
compression=uieditfield(g,'numeric','Value',s.perceptualCompression,'Limits',[0 Inf],'LowerLimitInclusive','off','ValueDisplayFormat','%.1f','Tag','RecipePerceptualCompression', ...
 'Tooltip','Generic perceptual gamut compression (colprof -s). 20% is a starting value, not a measured optimum. Relative and absolute colorimetric remain available.');
if ~isfield(s,'smoothing'),s.smoothing=NaN;end
smoothingText="";if ~isnan(s.smoothing),smoothingText=string(sprintf('%.1f',s.smoothing));end
smoothing=field('Smoothing at ICC build',smoothingText,'RecipeSmoothing');
smoothing.UserData=s.smoothing;smoothing.ValueChangedFcn=@formatSmoothing;
smoothing.Placeholder='Empty = 0.5% (default)';
smoothing.Tooltip='Stage 2: colprof -r (%) for the final ICC profile. Empty uses 0.5%. This is separate from measurement data smoothing in stage 1.';
if ~isfield(s,'preRegularization'),s.preRegularization="off";end
if ~isfield(s,'preRegularizationAvgDev'),s.preRegularizationAvgDev=0.5;end
[methodIds,methodLabels]=inkprof.internal.preRegularizationMethods();
if ~ismember(string(s.preRegularization),methodIds)
 s.preRegularization="off";
 uialert(f,'InkProf grid regularization (axial/Hessian) has been removed. Review and save an Argyll recipe; the previous ICC and measurements are preserved.','Profiling method changed');
end
uilabel(g,'Text','Measurement data smoothing');
pg=uigridlayout(g,[1 3]);pg.ColumnWidth={'1x',165,90};pg.Padding=[0 0 0 0];pg.ColumnSpacing=8;
preMethod=uidropdown(pg,'Items',cellstr(methodLabels),'ItemsData',cellstr(methodIds), ...
 'Value',char(s.preRegularization),'Tag','RecipePreRegularization','ValueChangedFcn',@(~,~)updatePre(), ...
 'Tooltip','Smooth the measured data with a separate model before the ICC build. Raw measurements are kept unchanged.');
preLabel=uilabel(pg,'Text','Assumed noise (%)','HorizontalAlignment','right');
preAvg=uieditfield(pg,'numeric','ValueDisplayFormat','%.1f','Value',s.preRegularizationAvgDev,'Limits',[0 100],'LowerLimitInclusive','off', ...
 'Tag','RecipePreRegularizationAvgDev','Tooltip','Stage 1: assumed average deviation from printing and the instrument, in percent (colprof -r). Smooths measurement data before the ICC build. Default 0.5%.');
pg.RowHeight={'1x'}; % components added to a full grid append rows; keep one row
if ~isfield(s,'gradientPreview'),s.gradientPreview=false;end
uilabel(g,'Text','Gradient test');
gradientPreview=uicheckbox(g,'Text','Open RGB gradient test after profile build', ...
 'Value',s.gradientPreview,'Tag','RecipeGradientPreview', ...
 'Tooltip','Optional numerical check in a separate window after a successful regularized profile build.');
updatePre();
if isfield(s,'projectPrinting')&&s.projectPrinting
 name.Editable='off';description.Editable='off';mode.Enable='off';b2a.Enable='off';
 for control={name,description,mode,b2a},control{1}.Tooltip='Managed in Project details > Profiling';end
end
info=uitextarea(g,'Editable','off','Value',splitlines(sprintf('Locked patches: %d | Spectra: %d | XYZ: %d\nM0/M1/M2 is the measurement condition, not the integration illuminant.\nStored XYZ is used unchanged; its reference must be reviewed before building.\nUnknown printing settings remain unknown. No ICC is generated here.',input.patchCount,hasSpectra,hasXYZ)));info.Layout.Column=[1 2];
shadow=inkprof.internal.shadowSettings(s.printing);
if shadow.enabled
 info.Value=[string(info.Value);sprintf('Matte shadows: patch emphasis %.2g; grid emphasis %.2g; up to %d extra iteration patches. Managed in Project details > Profiling.',shadow.patchEmphasis,shadow.gridEmphasis,shadow.extraPatches)];
end
condition=uitextarea(g,'Editable','off','Value',splitlines(string(jsonencode(input.measurementCondition,PrettyPrint=true))));condition.Layout.Column=[1 2];
uibutton(g,'Text','Save recipe','Tag','SaveProfileRecipe','ButtonPushedFcn',@saveRecipe);
uibutton(g,'Text','Cancel','Tag','CancelProfileRecipe','ButtonPushedFcn',@cancel);
f.CloseRequestFcn=@cancel;f.Visible='on';drawnow;focus(f);topGuard=inkprof.internal.lowerTopWindows(f); %#ok<NASGU>
if ~dismissed,uiwait(f);end
closeFigure(f);
 function e=field(label,value,tag)
  uilabel(g,'Text',label);e=uieditfield(g,'text','Value',char(value),'Tag',tag);
 end
 function saveRecipe(~,~)
  if strlength(strtrim(string(name.Value)))==0||strlength(strtrim(string(description.Value)))==0
   uialert(f,'Enter a profile name and description.','Recipe');return
  end
  if (strcmp(mode.Value,'spectral')&&~hasSpectra)||(strcmp(mode.Value,'storedXYZ')&&~hasXYZ)
   uialert(f,'The selected data type is unavailable in this measurement.','Recipe');return
  end
  if fwa.Value && (~hasSpectra||~strcmp(mode.Value,'spectral'))
   uialert(f,'FWA/OBA requires spectral data. Select Spectra or disable compensation.','FWA / OBA');return
  end
  s.preRegularization=string(preMethod.Value);s.preRegularizationAvgDev=preAvg.Value;
  value=strtrim(string(smoothing.Value));r=NaN;
  if value~=""
   r=str2double(value);
   if ~isnan(smoothing.UserData)&&value==string(sprintf('%.1f',smoothing.UserData)),r=smoothing.UserData;end
   if ~isfinite(r)||r<=0
    uialert(f,'Enter a positive number for final colprof -r, or leave it empty for the engine default.','Smoothing');return
   end
  end
  s.smoothing=r;s.perceptualCompression=compression.Value;
  s.gradientPreview=gradientPreview.Value&&~strcmp(preMethod.Value,'off');
  s.printing.fwaCompensation=logical(fwa.Value);
  s.b2aQuality=string(b2a.Value);
  s.name=string(name.Value);s.description=string(description.Value);s.dataMode=string(mode.Value);
  for j=1:numel(keys)
   value=strtrim(string(controls{j}.Value));if value=="",value="unknown";end;s.printing.(keys(j))=value;
  end
  s.printing.paperSurface=string(surface.Value);accepted=true;dismissed=true;uiresume(f);
 end
 function formatSmoothing(~,~)
  value=strtrim(string(smoothing.Value));
  if value=="",smoothing.UserData=NaN;return;end
  r=str2double(value);
  if isfinite(r)&&r>0,smoothing.UserData=r;smoothing.Value=sprintf('%.1f',r);end
 end
 function updatePre()
  if strcmp(preMethod.Value,'off'),gradientPreview.Enable='off';else,gradientPreview.Enable='on';end
  if strcmp(preMethod.Value,'argyll-colprof'),preAvg.Enable='on';else,preAvg.Enable='off';end
 end
 function cancel(~,~),dismissed=true;uiresume(f);end
end
function closeFigure(f)
if isvalid(f),delete(f);end
end
