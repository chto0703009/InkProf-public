% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function f=showGamut(profile,options)
arguments
 profile (1,1) string
 options.CloseAfterCreate (1,1) logical = false
 options.ForRefinement (1,1) logical = false
end
%SHOWGAMUT Display an ICC-derived surface or open the step 15 patch picker.
forRefinement=options.ForRefinement||options.CloseAfterCreate;
folder=string(tempname);mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
ref=inkprof.internal.reportGamut(profile,folder,forRefinement);
assert(string(ref.status)=="available",'inkprof:GamutUnavailable','Gamut unavailable: %s',getReason(ref));
data=jsondecode(fileread(fullfile(folder,ref.file)));
assert(string(data.profileSHA256)==inkprof.internal.sha256(profile),'inkprof:Integrity','ICC changed while calculating its gamut.');
windowTitle="InkProf | ICC gamut";
plotPosition=[.10 .23 .80 .68];
if forRefinement
 windowTitle="InkProf | Step 15: Add patches near the gamut boundary";
 plotPosition=[.06 .23 .59 .68];
end
f=figure('Name',windowTitle,'NumberTitle','off','Color','white','Position',[100 80 1350 800]);
ax=axes(f,'Position',plotPosition);lab=data.vertices;
surface=patch(ax,'Vertices',lab(:,[2 3 1]),'Faces',data.triangles+1,'FaceVertexCData',data.rgb,'FaceColor','interp','EdgeColor','none');
axis(ax,'equal');grid(ax,'on');view(ax,40,25);xlabel(ax,'a*');ylabel(ax,'b*');zlabel(ax,'L*');rotate3d(f,'on');
inkprof.internal.drawLabLightnessAxis(ax);
title(ax,'Predicted ICC gamut | CIELAB D50 | absolute colorimetric');
[~,name,ext]=fileparts(profile);
annotation(f,'textbox',[.04 .01 .61 .15],'String',string(name)+string(ext)+newline+ ...
 "ICC SHA-256: "+string(data.profileSHA256)+newline+ ...
 "A2B surface; sRGB preview colours. Not a measurement or a quality score.",'Interpreter','none','EdgeColor','none');
f.UserData=data;
if forRefinement
 inkprof.internal.gamutPicker(f,ax,surface,data,profile);
end
uicontrol(f,'Style','pushbutton','String','Close','Tag','closeGamut', ...
 'Units','normalized','Position',[.70 .002 .28 .026],'Callback',@(~,~)delete(f));
end
function reason=getReason(ref)
reason="";if isfield(ref,'reason'),reason=string(ref.reason);end
end
