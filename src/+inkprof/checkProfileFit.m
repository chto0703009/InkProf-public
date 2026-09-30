function [report,reportFile]=checkProfileFit(jobFolder,options)
%CHECKPROFILEFIT Compare ICC predictions to its measured training patches.
arguments
 jobFolder (1,1) string = ""
 options.ShowDialog (1,1) logical = true
end
report=[];reportFile="";
if jobFolder==""
 p=uigetdir(pwd,'Select the successful ICC job folder');if isequal(p,0),return;end;jobFolder=string(p);
end
jobFolder=inkprof.internal.absolutePath(jobFolder);ti3=fullfile(jobFolder,'engine.ti3');
v=inkprof.cgatsData(inkprof.importCgats(ti3),RGBScale=100);
assert(~isempty(v.locations),'inkprof:ProfileCheck','This fit report requires patch locations.');
expected=struct('ids',v.ids,'locations',v.locations,'rgb',v.rgb,'ti3SHA256',inkprof.internal.sha256(ti3));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));inkprof.internal.writeJson(fullfile(w,'expected.json'),expected);
paths=inkprof.paths();bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'profcheck');if ispc,exe=exe+".exe";end
assert(isfile(exe),'inkprof:Argyll','profcheck not found.');
inkprof.runPython(fullfile(paths.Root,'analysis','profile_fit.py'), ...
 [jobFolder,fullfile(w,'expected.json'),exe,fullfile(w,'report')],RequiredModules=["numpy","colour"],TimeoutSeconds=150);
report=jsondecode(fileread(fullfile(w,'report','profile-fit.json')));
parent=fullfile(jobFolder,'checks');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,string(java.util.UUID.randomUUID()));[ok,msg]=movefile(fullfile(w,'report'),folder);assert(ok,'inkprof:IO','%s',msg);
reportFile=fullfile(folder,'profile-fit.json');inkprof.internal.recordProjectStep(folder,"ICC forward training-fit check with per-patch deltaE00");
fprintf('InkProf: %d patches; mean dE00 %.4f, max %.4f.\nReport: %s\n',report.summary.count,report.summary.mean,report.summary.max,reportFile);
if ~options.ShowDialog,return;end
f=uifigure('Name','InkProf - ICC training fit','Position',[120 100 1100 730],'WindowStyle','alwaysontop','Visible','off');
g=uigridlayout(f,[5 1]);g.RowHeight={65,45,'1x',50,35};
s=report.summary;uilabel(g,'Text',sprintf('Training fit: %d patches | mean %.4f | median %.4f | p95 %.4f | max %.4f dE00\nAbsolute colorimetric. Not independent print validation or proof of convergence.',s.count,s.mean,s.median,s.p95,s.max),'WordWrap','on');
drop=uidropdown(g,'Items',{'All patches','Gray RGB','Dark','High chroma','RGB boundary'},'ValueChangedFcn',@(~,~)fill());
table=uitable(g,'ColumnName',{'Coordinate','ID','dE00','RGB %','Predicted Lab','Measured Lab'},'ColumnWidth',{85,60,80,220,250,250},'RowName',{});
uilabel(g,'Text',reportFile,'WordWrap','on');uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
fill();f.Visible='on';drawnow;focus(f);
 function fill()
  p=report.patches;[~,order]=sort([p.deltaE00],'descend');p=p(order);
  switch drop.Value
   case 'Gray RGB',p=p([p.gray]);case 'Dark',p=p([p.dark]);case 'High chroma',p=p([p.highChroma]);case 'RGB boundary',p=p([p.rgbBoundary]);
  end
  rows=cell(numel(p),6);
  for k=1:numel(p),a=p(k);rows(k,:)={a.coordinate,a.sampleId,a.deltaE00,sprintf('%.3f  %.3f  %.3f',a.rgbPercent),sprintf('%.4f  %.4f  %.4f',a.predictedLab),sprintf('%.4f  %.4f  %.4f',a.measuredLab)};end
  table.Data=rows;
 end
end
