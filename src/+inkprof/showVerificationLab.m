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
% CIELAB D50 -> XYZ D50 -> Bradford D65 -> display sRGB.
f=(lab(:,1)+16)/116;
q=[f+lab(:,2)/500,f,f-lab(:,3)/200];delta=6/29;
x=q.^3;low=q<=delta;x(low)=3*delta^2*(q(low)-4/29);
white50=[0.9642956764;1;0.8251046025];white65=[0.9504559271;1;1.0890577508];
xyz=x.*white50';
B=[0.8951 0.2664 -0.1614;-0.7502 1.7135 0.0367;0.0389 -0.0685 1.0296];
A=B\(diag((B*white65)./(B*white50))*B);
xyz=xyz*A';
M=[3.2406 -1.5372 -0.4986;-0.9689 1.8758 0.0415;0.0557 -0.2040 1.0570];
linear=xyz*M';rgb=12.92*linear;high=linear>0.0031308;
rgb(high)=1.055*linear(high).^(1/2.4)-0.055;
clipped=any(rgb<0 | rgb>1,2);rgb=max(0,min(1,rgb));
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
