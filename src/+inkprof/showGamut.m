% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function f=showGamut(profile)
%SHOWGAMUT Display an ICC-derived surface, independently of measured patches.
folder=string(tempname);mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
ref=inkprof.internal.reportGamut(profile,folder);
assert(string(ref.status)=="available",'inkprof:GamutUnavailable','Gamut unavailable: %s',getReason(ref));
data=jsondecode(fileread(fullfile(folder,ref.file)));
assert(string(data.profileSHA256)==inkprof.internal.sha256(profile),'inkprof:Integrity','ICC changed while calculating its gamut.');
f=figure('Name','InkProf | ICC gamut','NumberTitle','off','Color','white');
ax=axes(f,'Position',[.1 .19 .8 .72]);lab=data.vertices;
patch(ax,'Vertices',lab(:,[2 3 1]),'Faces',data.triangles+1,'FaceVertexCData',data.rgb,'FaceColor','interp','EdgeColor','none');
axis(ax,'equal');grid(ax,'on');view(ax,40,25);xlabel(ax,'a*');ylabel(ax,'b*');zlabel(ax,'L*');rotate3d(f,'on');
title(ax,'Predicted ICC gamut | CIELAB D50 | absolute colorimetric');
[~,name,ext]=fileparts(profile);
annotation(f,'textbox',[.05 .01 .9 .15],'String',string(name)+string(ext)+newline+ ...
 "ICC SHA-256: "+string(data.profileSHA256)+newline+ ...
 "A2B surface; sRGB preview colours. Not a measurement or a quality score.",'Interpreter','none','EdgeColor','none');
f.UserData=data;
end
function reason=getReason(ref)
reason="";if isfield(ref,'reason'),reason=string(ref.reason);end
end
