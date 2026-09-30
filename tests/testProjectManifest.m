function tests=testProjectManifest
tests=functiontests(localfunctions);
end
function testLifecycle(tc)
w=string(tempname);cleanup=onCleanup(@()remove(w));
p=inkprof.createProject(w,Name="Test");
a=jsondecode(fileread(fullfile(p,'inkprof-project.json')));verifyEqual(tc,a.revision,1);
file=fullfile(p,'sources','example.json');inkprof.internal.writeJson(file,struct('value',42));
b=inkprof.updateProject(file,Step="source-added");verifyEqual(tc,b.revision,2);
verifyEqual(tc,numel(b.files),1);verifyEqual(tc,string(b.files.path),"sources/example.json");
verifyEqual(tc,string(b.files.sha256),inkprof.internal.sha256(file));
previous=fileread(fullfile(p,'.manifest-history','000001.json'));
inkprof.internal.writeJson(file,struct('value',43));c=inkprof.updateProject(file,Step="source-changed");
verifyEqual(tc,string(c.history(end).changedPaths),"sources/example.json");
verifyEqual(tc,fileread(fullfile(p,'.manifest-history','000001.json')),previous);
delete(file);d=inkprof.updateProject(p,Step="source-removed");
verifyEqual(tc,string(d.history(end).removedPaths),"sources/example.json");verifyEmpty(tc,d.files);
verifyEqual(tc,inkprof.internal.findProject(fullfile(p,'measurements','future','chart.json')),p);
end
function testLock(tc)
w=string(tempname);cleanup=onCleanup(@()remove(w));inkprof.createProject(w);
f=fopen(fullfile(w,'.manifest.lock'),'w');fclose(f);
verifyError(tc,@()inkprof.updateProject(w),'inkprof:ProjectBusy');
end
function remove(w)
if isfolder(w),rmdir(w,'s');end
end
function testAutomaticDefinitionAndPrint(tc)
w=string(tempname);cleanup=onCleanup(@()remove(w));inkprof.createProject(w);
d=inkprof.designRGBTarget(Levels=2,GraySteps=3,MaxPoints=24,ControlCount=3,RepeatCount=2);
s=inkprof.saveRGBDefinition(d,fullfile(w,'targets','mesh.ti1'));
a=jsondecode(fileread(fullfile(w,'inkprof-project.json')));
verifyEqual(tc,string(a.history(end).step),"definition-saved");
inkprof.createTarget(fullfile(w,'targets','print'),Source=s.ti1,Paper="A4-landscape",DPI=100);
a=jsondecode(fileread(fullfile(w,'inkprof-project.json')));
verifyEqual(tc,string(a.history(end).step),"print-package-saved");
inkprof.prepareChart(fullfile(w,'targets','print','target.ti2'),fullfile(w,'measurements','test'));
a=jsondecode(fileread(fullfile(w,'inkprof-project.json')));
verifyEqual(tc,string(a.history(end).step),"chart-prepared");
verifyTrue(tc,any(string({a.files.path})=="measurements/test/chart.json"));
verifyTrue(tc,any(arrayfun(@(x)~isempty(x.matches),a.links)));
end
