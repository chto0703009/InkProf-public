% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function drawLabLightnessAxis(ax)
%DRAWLABLIGHTNESSAXIS Visible neutral L* reference through a*=b*=0.
held=ishold(ax);hold(ax,'on');
% Draw over opaque surfaces so the neutral reference remains visible.
ax.SortMethod='childorder';ax.Layer='top';
xlabel(ax,'a*');ylabel(ax,'b*');zlabel(ax,'L*');
limits={ax.XLim,ax.YLim};
for dimension=1:2
 extent=limits{dimension};
 if dimension==1,x=extent;y=[0 0];label='a*';else,x=[0 0];y=extent;label='b*';end
 plot3(ax,x,y,[0 0],'w-','LineWidth',4,'HandleVisibility','off','HitTest','off');
 plot3(ax,x,y,[0 0],'k-','LineWidth',1.5,'HandleVisibility','off','HitTest','off');
 text(ax,x(2),y(2),0,label,'Color','k','BackgroundColor','w','Margin',2,'FontWeight','bold','HitTest','off');
end
plot3(ax,[0 0],[0 0],[0 100],'w-','LineWidth',4,'HandleVisibility','off','HitTest','off');
plot3(ax,[0 0],[0 0],[0 100],'k-','LineWidth',1.5,'Tag','InkProfNeutralLAxis','HandleVisibility','off','HitTest','off');
for level=0:20:100
 text(ax,0,0,level,sprintf('  %d',level),'Color','k','BackgroundColor','w','Margin',1,'FontSize',9,'HitTest','off');
end
text(ax,0,0,108,'L* (a*=b*=0)','Color','k','BackgroundColor','w','Margin',2,'FontWeight','bold','HitTest','off');
if ~held,hold(ax,'off');end
end
