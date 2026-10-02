function [accepted,s]=profileRecipeDialog(s,input,hasSpectra,hasXYZ)
accepted=false;dismissed=false;
f=uifigure('Name','InkProf - Profiling recipe','Tag','InkProfProfileRecipe','Visible','off', ...
 'WindowStyle','alwaysontop','Position',[180 80 860 780]);
cleanup=onCleanup(@()closeFigure(f));g=uigridlayout(f,[16 2]);g.ColumnWidth={200,'1x'};
g.RowHeight=[repmat({32},1,13),{90,'1x',36}];
name=field('Profile name',s.name,'RecipeName');description=field('Description',s.description,'RecipeDescription');
keys=["printer","paper","media","quality","driver","printPath","colorManagement"];
labels=["Printer","Paper product","Driver media setting","Print quality","Driver / version","Printing application / path","Print colour management"];
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
fwaText="OFF";if isfield(s.printing,'fwaCompensation')&&isequal(s.printing.fwaCompensation,true),fwaText="ON (simulated D50)";end
uilabel(g,'Text','Profile calculation');uilabel(g,'Text',"Argyll Lab cLUT; FWA/OBA "+fwaText+". Set in Project details.",'WordWrap','on');
if ~isfield(s,'b2aQuality'),s.b2aQuality="high";end
uilabel(g,'Text','Inverse table (B2A)');b2a=uidropdown(g,'Items',{'High (denser)','Medium (baseline)'}, ...
 'ItemsData',{'high','medium'},'Value',char(s.b2aQuality),'Tag','RecipeB2AQuality');
info=uitextarea(g,'Editable','off','Value',splitlines(sprintf('Locked patches: %d | Spectra: %d | XYZ: %d\nM0/M1/M2 is the measurement condition, not the integration illuminant.\nStored XYZ is used unchanged; its reference must be reviewed before building.\nUnknown printing settings remain unknown. No ICC is generated here.',input.patchCount,hasSpectra,hasXYZ)));info.Layout.Column=[1 2];
condition=uitextarea(g,'Editable','off','Value',splitlines(string(jsonencode(input.measurementCondition,PrettyPrint=true))));condition.Layout.Column=[1 2];
uibutton(g,'Text','Save recipe','Tag','SaveProfileRecipe','ButtonPushedFcn',@saveRecipe);
uibutton(g,'Text','Cancel','Tag','CancelProfileRecipe','ButtonPushedFcn',@cancel);
f.CloseRequestFcn=@cancel;f.Visible='on';drawnow;focus(f);if ~dismissed,uiwait(f);end
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
  s.b2aQuality=string(b2a.Value);
  s.name=string(name.Value);s.description=string(description.Value);s.dataMode=string(mode.Value);
  for j=1:numel(keys)
   value=strtrim(string(controls{j}.Value));if value=="",value="unknown";end;s.printing.(keys(j))=value;
  end
  s.printing.paperSurface=string(surface.Value);accepted=true;dismissed=true;uiresume(f);
 end
 function cancel(~,~),dismissed=true;uiresume(f);end
end
function closeFigure(f)
if isvalid(f),delete(f);end
end
