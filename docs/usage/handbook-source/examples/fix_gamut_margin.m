% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function fix_gamut_margin
exampleDir=fileparts(mfilename('fullpath'));root=fileparts(fileparts(fileparts(fileparts(exampleDir))));addpath(root);addpath(fullfile(root,'src'));base=fullfile(tempdir,'InkProf-handbook-examples');
setupInkProf(CheckPython=true,SaveLocalConfig=false);
f=inkprof.showGamut(fullfile(base,'example-sRGB.icc'));f.Position=[100 100 980 720];
ax=findall(f,'Type','axes');delete(findall(ax,'Type','line'));delete(findall(ax,'Type','text'));ax.SortMethod='depth';ax.Layer='bottom';ax.Toolbar.Visible='off';ax.Position=[.12 .14 .76 .74];
data=f.UserData;v=data.vertices;axis(ax,'equal');xlim(ax,[min(v(:,2))-8 max(v(:,2))+8]);ylim(ax,[min(v(:,3))-8 max(v(:,3))+8]);zlim(ax,[0 105]);view(ax,38,22);
xlabel(ax,'a*');ylabel(ax,'b*');zlabel(ax,'L*');title(ax,'ICC gamut example | CIELAB D50','FontSize',15);
ax.FontSize=12;ax.GridAlpha=.12;ax.Box='on';
delete(findall(f,'Type','textboxshape'));annotation(f,'textbox',[.1 .01 .8 .06],'String','Example sRGB ICC v2 | Profile prediction, not a printer measurement','EdgeColor','none','FontSize',11,'HorizontalAlignment','center');
drawnow;set(f,'PaperPositionMode','auto');print(f,fullfile(base,'gamut-window.png'),'-dpng','-r180');delete(f);
end
