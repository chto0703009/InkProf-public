% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function fig=showVerificationLab(referenceFile,options)
%SHOWVERIFICATIONLAB Rotatable Lab scatter of a C2 target's ICC predictions.
% MATLAB Base only. Point colours are clipped sRGB previews, not measurements.
arguments
 referenceFile (1,1) string = ""
 options.Visible (1,1) logical = true
 options.FitReport (1,1) string = ""
end
fig=[];
if referenceFile==""
 [n,p]=uigetfile('*.json','Select verification.json');
 if isequal(n,0),return;end
 referenceFile=fullfile(p,n);
end
ref=jsondecode(fileread(referenceFile));
assert(isfield(ref,'documentType') && string(ref.documentType)=="inkprof.verification-target", ...
 'inkprof:Input','Select a C2 verification.json, not a measurement or report.');
n=numel(ref.patches);lab=zeros(n,3);coords=strings(n,1);ids=coords;
for k=1:n
 if iscell(ref.patches),p=ref.patches{k};else,p=ref.patches(k);end
 lab(k,:)=double(p.predictedLabD50Absolute(:)');
 coords(k)=string(p.placement.coordinate);ids(k)=string(p.id);
end
assert(n>0 && all(isfinite(lab),'all'),'inkprof:Input','Finite predicted Lab required.');
[rgb,clipped]=inkprof.internal.labD50ToSRGB(lab);
worst=[];
if options.FitReport~=""
 fit=jsondecode(fileread(options.FitReport));
 assert(string(fit.documentType)=="inkprof.profile-fit",'inkprof:Input','Select profile-fit.json.');
 assert(string(fit.profileSHA256)==string(ref.printerProfile.sha256),'inkprof:Identity','Fit report belongs to another ICC profile.');
 [~,index]=max([fit.patches.deltaE00]);worst=fit.patches(index);
end
vis='off';if options.Visible,vis='on';end
fig=figure('Name','InkProf - predicted Lab 3D','NumberTitle','off', ...
 'Color','w','Position',[100 100 1100 780],'Visible',vis,'ToolBar','figure');
ax=axes(fig,'Position',[.1 .15 .8 .74]);
h=scatter3(ax,lab(:,2),lab(:,3),lab(:,1),65,rgb,'filled','MarkerEdgeColor',[.2 .2 .2]);
xlabel(ax,'a* (green - red)');ylabel(ax,'b* (blue - yellow)');zlabel(ax,'L* (lightness)');
name="ICC predicted colours";if isfield(ref,'name'),name=string(ref.name);end
title(ax,{name;sprintf('%d target patches - predicted absolute D50 Lab, not measured',n)},'Interpreter','none');
grid(ax,'on');axis(ax,'equal');axis(ax,'vis3d');view(ax,40,25);
h.DataTipTemplate.DataTipRows=[ ...
 dataTipTextRow('Patch',coords),dataTipTextRow('ID',ids), ...
 dataTipTextRow('L*',lab(:,1),'%.3f'), ...
 dataTipTextRow('a*',lab(:,2),'%.3f'), ...
 dataTipTextRow('b*',lab(:,3),'%.3f')];
annotation(fig,'textbox',[.07 .025 .86 .075], ...
 'String',sprintf('Drag to rotate; scroll to zoom. Select Data Tips in the toolbar to inspect a patch.\nColours are sRGB previews (%d clipped); this point cloud is not the full printer gamut.',sum(clipped)), ...
 'EdgeColor','none','Interpreter','none','FontSize',11);
fig.UserData=struct('referenceFile',referenceFile,'lab',lab,'coordinates',coords, ...
 'ids',ids,'previewRGB',rgb,'sRGBClipped',clipped,'measurement',false);
if ~isempty(worst)
 w=double(worst.predictedLab(:)');m=double(worst.measuredLab(:)');
 hold(ax,'on');
 scatter3(ax,w(2),w(3),w(1),260,'k','o','LineWidth',3);
 scatter3(ax,w(2),w(3),w(1),360,[1 .65 0],'o','LineWidth',2);
 plot3(ax,[w(2) m(2)],[w(3) m(3)],[w(1) m(1)],'k-','LineWidth',2);
 scatter3(ax,m(2),m(3),m(1),130,'k','x','LineWidth',2);
 loc=regexprep(string(worst.sampleLoc),'^.*-','');
 loc=regexprep(loc,'^(\d+)([A-Z]+)$','$2$1');
 text(ax,w(2),w(3),w(1),sprintf('  %s: %.2f dE00 (training)',loc,worst.deltaE00), ...
  'FontWeight','bold','Color','k','BackgroundColor','w','Margin',3,'Interpreter','none');
 subtitle(ax,'Rings: worst training prediction. Cross: measured Lab. Line is Lab displacement, not dE00 distance.');
 fig.UserData.worstTrainingPatch=worst;
 hold(ax,'off');
end
rotate3d(fig,'on');
end
