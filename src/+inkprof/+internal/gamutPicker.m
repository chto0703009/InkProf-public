% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function gamutPicker(f,ax,surface,data,profile,closeAfterCreate)
if nargin<6,closeAfterCreate=false;end
% Add explicit selection/rotation modes to the existing gamut figure.
anchors=struct('vertexIndex',{},'lab',{},'rgbPercent',{},'mappedLab',{},'distanceDeltaE76',{},'profileSHA256',{});
marker=line(ax,NaN,NaN,NaN,'LineStyle','none','Marker','o','MarkerSize',9, ...
 'MarkerEdgeColor','k','MarkerFaceColor','w','HitTest','off','PickableParts','none');
panel=uipanel(f,'Units','normalized','Position',[.69 .03 .30 .93],'Title','Add measurements in a gamut area','BackgroundColor','white');
control('text','Whole inner gamut shell adds patches across the surface. Set thickness from the depth of the RGB features you want to investigate.',[.04 .86 .92 .10]);
select=control('pushbutton','Select area',[.04 .81 .44 .045]);select.Tag='gamutSelectMode';select.Callback=@(~,~)mode(false);
rotate=control('pushbutton','Rotate view',[.52 .81 .44 .045]);rotate.Callback=@(~,~)mode(true);
t=uitable(panel,'Units','normalized','Position',[.04 .46 .92 .33],'Data',cell(0,5), ...
 'ColumnName',{'Area','R %','G %','B %','ΔE76 offset'},'ColumnWidth',{45,65,65,65,95},'RowName',{},'Tag','gamutAnchorTable');
clearButton=control('pushbutton','Clear selection',[.04 .40 .92 .045]);clearButton.Callback=@clearSelection;
sampling=control('popupmenu',{'Selected RGB neighbourhoods','Selected inner shell areas','Whole inner gamut shell'},[.04 .35 .92 .04]);
sampling.Value=3;sampling.Tag='gamutSamplingMode';sampling.Callback=@(~,~)update();
radiusLabel=control('text','Shell thickness (ΔE76)',[.04 .30 .72 .04]);
radius=control('edit','3',[.78 .30 .18 .04]);radius.Tag='gamutRadius';
control('text','Minimum spacing (RGB percentage points)',[.04 .25 .72 .04]);
spacing=control('edit','1',[.78 .25 .18 .04]);
control('text','Maximum new patches',[.04 .20 .72 .04]);
budget=control('edit','100',[.78 .20 .18 .04]);
control('text','Selected shell area radius (ΔE76)',[.04 .15 .72 .04]);
region=control('edit','15',[.78 .15 .18 .04]);region.Tag='gamutShellRegionRadius';
create=control('pushbutton','Review patches / create TIFF16',[.04 .09 .92 .055]);create.Enable='off';create.Tag='gamutCreatePatches';create.Callback=@createTarget;
info=control('text','Shell thickness is Lab distance inward from the ICC surface. Suggested RGB patches use forward ICC predictions.',[.04 .005 .92 .08]);
job=fileparts(fileparts(string(profile)));jobFile=fullfile(job,'status.json');
canCreate=isfile(jobFile)&&isfile(fullfile(job,'engine.ti3'))&&isfile(fullfile(job,'result','profile.icc')) ...
 &&inkprof.internal.sha256(fullfile(job,'result','profile.icc'))==string(data.profileSHA256);
if ~canCreate,info.String='Read-only ICC: creating patches requires a successful profile job in an InkProf project.';end
surface.ButtonDownFcn=@pick;surface.PickableParts='visible';mode(true);update();
 function h=control(style,label,position)
  h=uicontrol(panel,'Style',style,'String',label,'Units','normalized','Position',position,'FontSize',11,'BackgroundColor','white');
  if strcmp(style,'text'),h.HorizontalAlignment='left';end
 end
 function mode(rotation)
  if rotation,enableDefaultInteractivity(ax);rotate3d(f,'on');select.FontWeight='normal';rotate.FontWeight='bold';
  else,rotate3d(f,'off');disableDefaultInteractivity(ax);select.FontWeight='bold';rotate.FontWeight='normal';end
 end
 function pick(~,event)
  if strcmp(select.FontWeight,'normal'),return;end
  point=event.IntersectionPoint;lab=point([3 1 2]);
  [~,index]=min(sum((data.vertices-lab).^2,2));
  if ~isempty(anchors)&&any([anchors.vertexIndex]==index),return;end
  m=data.deviceMapping;
  anchors(end+1)=struct('vertexIndex',index,'lab',data.vertices(index,:), ...
   'rgbPercent',m.rgb(index,:)*100,'mappedLab',m.lab(index,:), ...
   'distanceDeltaE76',m.distanceDeltaE76(index),'profileSHA256',string(data.profileSHA256));
  update();
 end
 function clearSelection(~,~)
  anchors=anchors([]);update();
 end
 function update()
  if sampling.Value==1,radiusLabel.String='Neighbour radius (RGB percentage points)';
  else,radiusLabel.String='Shell thickness (ΔE76)';end
  region.Enable='off';if sampling.Value==2,region.Enable='on';end
  rows=cell(numel(anchors),5);
  for k=1:numel(anchors)
   a=anchors(k);rows(k,:)={sprintf('%d',k),sprintf('%.2f',a.rgbPercent(1)), ...
    sprintf('%.2f',a.rgbPercent(2)),sprintf('%.2f',a.rgbPercent(3)),sprintf('%.2f',a.distanceDeltaE76)};
  end
  t.Data=rows;f.UserData.selectedGamutAnchors=anchors;
  if isempty(anchors),marker.XData=NaN;marker.YData=NaN;marker.ZData=NaN;create.Enable='off';
  else
   points=reshape([anchors.lab],3,[])';marker.XData=points(:,2);marker.YData=points(:,3);marker.ZData=points(:,1);
   if canCreate,create.Enable='on';end
  end
  if sampling.Value==3&&canCreate,create.Enable='on';end
 end
 function createTarget(~,~)
  create.Enable='off';create.String='Working — please wait';
  activity=inkprof.internal.gamutActivity(f,info);
  activityCleanup=onCleanup(@()activity.close()); %#ok<NASGU>
  drawnow;
  try
   samplingMode="neighbour";if sampling.Value==2,samplingMode="shell-region";elseif sampling.Value==3,samplingMode="shell";end
   neighbourRadius=3;shellThickness=3;
   if samplingMode=="neighbour",neighbourRadius=str2double(radius.String);else,shellThickness=str2double(radius.String);end
   [proposal,folder]=inkprof.refineFromGamut(jobFile,anchors(:),RadiusPercent=neighbourRadius, ...
    MinSpacingPercent=str2double(spacing.String),MaxNewPatches=str2double(budget.String), ...
    SamplingMode=samplingMode,ShellThicknessDeltaE76=shellThickness,Surface=data,RegionRadiusDeltaE76=str2double(region.String),Activity=activity.stage);
   if ~isempty(proposal)&&isgraphics(f)
    info.String=char("Saved: "+folder+newline+"Registered in step 15. Continue with step 16 to measure this exact package, then step 17 to build. Refresh the project view if needed.");
    fprintf('Gamut selection and TIFF16: %s\n',folder);
    if closeAfterCreate
     clear activityCleanup;delete(f);return
    end
   end
  catch err
   clear activityCleanup;
   if isgraphics(f),errordlg(err.message,'Gamut patches','modal');end
  end
  clear activityCleanup;
  if isgraphics(f),create.String='Review patches / create TIFF16';update();end
 end
end
