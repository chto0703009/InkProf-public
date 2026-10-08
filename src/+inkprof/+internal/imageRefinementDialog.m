% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function settings=imageRefinementDialog(file,defaults,profileDescription)
% Base MATLAB image preview and editable pixel rectangle; no image toolbox.
calculation=inkprof.internal.calculationProgress("Opening image preview","Reading the image for region selection.");
[pixels,map]=imread(file);assert(isempty(map)&&ndims(pixels)==3&&size(pixels,3)==3,'inkprof:Image','Select an RGB image.');
[h,w,~]=size(pixels);settings=[];clear calculation;
f=uifigure('Name','InkProf - Select image colours','Position',[140 90 1050 720],'WindowStyle','modal');
cleanup=onCleanup(@()delete(f));f.CloseRequestFcn=@cancel;
g=uigridlayout(f,[3 2]);g.ColumnWidth={'1x',320};g.RowHeight={55,'1x',42};
label=uilabel(g,'Text',"Image profile: "+profileDescription+newline+"Select the whole image or enter a pixel rectangle. All colours are eligible.",'WordWrap','on');label.Layout.Column=[1 2];
ax=uiaxes(g);ax.Layout.Row=2;ax.Layout.Column=1;
stride=max(1,ceil(max(h,w)/1000));image(ax,'CData',pixels(1:stride:end,1:stride:end,:),'XData',[1 w],'YData',[1 h]);axis(ax,'image');ax.YDir='reverse';hold(ax,'on');
box=rectangle(ax,'Position',[1 1 max(w-1,1) max(h-1,1)],'EdgeColor','r','LineWidth',2);
panel=uigridlayout(g,[8 2]);panel.Layout.Row=2;panel.Layout.Column=2;panel.RowHeight={40,40,40,40,40,40,40,'1x'};panel.ColumnWidth={185,'1x'};
labels={'Left pixel (x)','Top pixel (y)','Width (pixels)','Height (pixels)','Maximum new patches','Min. RGB spacing (%)','Neighbor radius (%)'};
values=[1,1,w,h,defaults.MaxNewPatches,defaults.MinSpacingPercent,defaults.NeighborRadiusPercent];if ~isempty(defaults.ROI),values(1:4)=defaults.ROI;end
fields=gobjects(1,7);
for k=1:7
 uilabel(panel,'Text',labels{k});fields(k)=uieditfield(panel,'numeric','Value',values(k),'ValueChangedFcn',@preview);
end
help=uilabel(panel,'Text','Spacing excludes device RGB already measured or proposed. Radius 0 samples image colours only; a positive radius also permits nearby probes. Controls are added separately.','WordWrap','on');help.Layout.Column=[1 2];
uibutton(g,'Text','Cancel','ButtonPushedFcn',@cancel);uibutton(g,'Text','Propose patches','ButtonPushedFcn',@accept);
topGuard=inkprof.internal.lowerTopWindows(f); %#ok<NASGU> keep the dialog above always-on-top windows
preview([],[]);if isgraphics(f),uiwait(f);end
if isgraphics(f),delete(f);end
 function cancel(~,~)
  settings=[];if isgraphics(f),delete(f);end
 end
 function preview(~,~)
  v=arrayfun(@(x)x.Value,fields);box.Position=[v(1),v(2),max(1,v(3)-1),max(1,v(4)-1)];
 end
 function accept(~,~)
  v=arrayfun(@(x)x.Value,fields);
  if any(v(1:5)~=round(v(1:5)))||any(v(1:5)<1)||v(1)+v(3)-1>w||v(2)+v(4)-1>h||v(5)>500||v(6)<=0||v(6)>10||v(7)<0||v(7)>10
   uialert(f,'Use a rectangle within the image, 1–500 patches, spacing >0–10%, and radius 0–10%.','Image selection');return
  end
  settings=struct('ROI',v(1:4),'MaxNewPatches',v(5),'MinSpacingPercent',v(6),'NeighborRadiusPercent',v(7));delete(f);
 end
end
