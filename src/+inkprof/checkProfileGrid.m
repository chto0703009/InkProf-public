function [report,reportFile]=checkProfileGrid(jobFolder,options)
%CHECKPROFILEGRID Sample ICC forward/backward tables and compare CMMs.
arguments
 jobFolder (1,1) string = ""
 options.GridLevels (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.GridLevels,3),mustBeLessThanOrEqual(options.GridLevels,25)} = 9
 options.ShowDialog (1,1) logical = true
end
report=[];reportFile="";
if jobFolder=="",p=uigetdir(pwd,'Select ICC job folder');if isequal(p,0),return;end;jobFolder=string(p);end
jobFolder=inkprof.internal.absolutePath(jobFolder);paths=inkprof.paths();bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'xicclu');if ispc,exe=exe+".exe";end
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
fprintf('InkProf: checking RGB grid, inverse, ramps and LittleCMS...\n');
inkprof.runPython(fullfile(paths.Root,'analysis','profile_grid.py'),[jobFolder,exe,fullfile(w,'report'),"--levels",string(options.GridLevels)],RequiredModules=["numpy","colour","PIL"],TimeoutSeconds=300);
report=jsondecode(fileread(fullfile(w,'report','grid-check.json')));
parent=fullfile(jobFolder,'checks');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,string(java.util.UUID.randomUUID()));[ok,msg]=movefile(fullfile(w,'report'),folder);assert(ok,'inkprof:IO','%s',msg);
reportFile=fullfile(folder,'grid-check.json');inkprof.internal.recordProjectStep(folder,"ICC synthetic grid/inverse/ramp and quantized CMM checks");
fprintf('InkProf: %d grid points; roundtrip dE00 mean %.4f, max %.4f.\nReport: %s\n',report.settings.gridCount,report.roundtripDeltaE00.mean,report.roundtripDeltaE00.max,reportFile);
if ~options.ShowDialog,return;end
f=uifigure('Name','InkProf - ICC numerical checks','Position',[150 100 1000 740],'WindowStyle','alwaysontop','Visible','off');
g=uigridlayout(f,[3 2]);g.RowHeight={140,'1x',40};
t=uitextarea(g,'Editable','off','Value',splitlines(string(fileread(fullfile(folder,'grid-check.md')))));t.Layout.Column=[1 2];
a=uiaxes(g);plot(a,report.gray.rgb(:,1),report.gray.lab);title(a,'Equal RGB ramp: predicted Lab');xlabel(a,'RGB (0–1)');legend(a,{'L*','a*','b*'});
b=uiaxes(g);plot(b,report.neutral.targetLab(:,1),report.neutral.rgb);title(b,'Neutral Lab to stored B2A RGB');xlabel(b,'Target L*');legend(b,{'R','G','B'});
uilabel(g,'Text',reportFile,'WordWrap','on');uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
f.Visible='on';drawnow;focus(f);
end
