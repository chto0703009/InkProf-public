% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function gamutPicker(f,ax,surface,data,profile)
% Add explicit selection/rotation modes to the existing gamut figure.
anchors=struct('vertexIndex',{},'lab',{},'rgbPercent',{},'mappedLab',{},'distanceDeltaE76',{},'profileSHA256',{});
marker=line(ax,NaN,NaN,NaN,'LineStyle','none','Marker','o','MarkerSize',9, ...
 'MarkerEdgeColor','k','MarkerFaceColor','w','HitTest','off','PickableParts','none');
panel=uipanel(f,'Units','normalized','Position',[.69 .03 .30 .93],'Title','Add measurements in a gamut area','BackgroundColor','white');
control('text','Click Select area, then click the surface. Select several points to cover an indentation.',[.04 .86 .92 .10]);
select=control('pushbutton','Select area',[.04 .81 .44 .045]);select.Tag='gamutSelectMode';select.Callback=@(~,~)mode(false);
rotate=control('pushbutton','Rotate view',[.52 .81 .44 .045]);rotate.Callback=@(~,~)mode(true);
t=uitable(panel,'Units','normalized','Position',[.04 .46 .92 .33],'Data',cell(0,5), ...
 'ColumnName',{'Area','R %','G %','B %','ΔE76 offset'},'ColumnWidth',{45,65,65,65,95},'RowName',{},'Tag','gamutAnchorTable');
clearButton=control('pushbutton','Clear selection',[.04 .40 .92 .045]);clearButton.Callback=@clearSelection;
control('text','Neighbour radius (RGB percentage points)',[.04 .34 .72 .04]);
radius=control('edit','3',[.78 .34 .18 .04]);radius.Tag='gamutRadius';
control('text','Minimum spacing (RGB percentage points)',[.04 .29 .72 .04]);
spacing=control('edit','1',[.78 .29 .18 .04]);
control('text','Maximum new patches',[.04 .24 .72 .04]);
budget=control('edit','100',[.78 .24 .18 .04]);
create=control('pushbutton','Review patches / create TIFF16',[.04 .17 .92 .055]);create.Enable='off';create.Tag='gamutCreatePatches';create.Callback=@createTarget;
info=control('text','RGB comes from the nearest sampled forward ICC colour. ΔE76 offset shows its distance from the selected surface vertex. This is approximate, not a measured print error.',[.04 .02 .92 .13]);
job=fileparts(fileparts(string(profile)));jobFile=fullfile(job,'status.json');
canCreate=isfile(jobFile)&&isfile(fullfile(job,'engine.ti3'))&&isfile(fullfile(job,'result','profile.icc')) ...
 &&inkprof.internal.sha256(fullfile(job,'result','profile.icc'))==string(data.profileSHA256);
if ~canCreate,info.String='Read-only ICC: creating patches requires a successful profile job in an InkProf project.';end
surface.ButtonDownFcn=@pick;surface.PickableParts='visible';mode(true);
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
 end
 function createTarget(~,~)
  create.Enable='off';drawnow;
  try
   [proposal,folder]=inkprof.refineFromGamut(jobFile,anchors(:),RadiusPercent=str2double(radius.String), ...
    MinSpacingPercent=str2double(spacing.String),MaxNewPatches=str2double(budget.String));
   if ~isempty(proposal)&&isgraphics(f)
    info.String=char("Saved: "+folder+newline+"In the app: step 15 → From gamut selection → select proposal.json here. Then measure in step 16 and build in step 17.");
    fprintf('Gamut selection and TIFF16: %s\n',folder);
   end
  catch err
   if isgraphics(f),errordlg(err.message,'Gamut patches','modal');end
  end
  if isgraphics(f)&&~isempty(anchors)&&canCreate,create.Enable='on';end
 end
end
