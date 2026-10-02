function tests=testArgyllDiscovery
tests=functiontests(localfunctions);
end
function testNativeHomebrewOrder(tc)
a=inkprof.internal.argyllCandidates("maca64","","");
verifyEqual(tc,a(1),"/opt/homebrew/opt/argyll-cms/bin");
b=inkprof.internal.argyllCandidates("maci64","","");
verifyEqual(tc,b(1),"/usr/local/opt/argyll-cms/bin");
verifyTrue(tc,any(a=="/opt/homebrew/bin"));
end
function testResolution(tc)
root=string(tempname);mkdir(root);cleanup=onCleanup(@()rmdir(root,'s'));
a=fullfile(root,'first bin');b=fullfile(root,'second');mkdir(a);mkdir(b);
suffix="";if ispc,suffix=".exe";end
for folder=[a,b]
 for name=["targen","printtarg"]
  fid=fopen(fullfile(folder,name+suffix),'w');fclose(fid);
 end
end
resolve=@(request,configured,env,legacy)inkprof.internal.resolveArgyllBin(request,root,configured,env,[b,a],legacy);
verifyEqual(tc,resolve("first bin",b,b,false),inkprof.internal.absolutePath(a));
verifyEqual(tc,resolve("",a,b,false),inkprof.internal.absolutePath(a));
verifyEqual(tc,resolve("","",a,false),inkprof.internal.absolutePath(a));
verifyEqual(tc,resolve("","","",false),inkprof.internal.absolutePath(b));
verifyEqual(tc,resolve("auto","missing","",false),inkprof.internal.absolutePath(b));
verifyError(tc,@()resolve("missing",a,b,false),'inkprof:Argyll');
verifyError(tc,@()resolve("","missing",b,false),'inkprof:Argyll');
verifyWarning(tc,@()resolve("","missing","",true),'inkprof:ArgyllLegacyPath');
warning('off','inkprof:ArgyllLegacyPath');c=onCleanup(@()warning('on','inkprof:ArgyllLegacyPath'));
verifyEqual(tc,resolve("","missing","",true),inkprof.internal.absolutePath(b));
end
function testOnlyExplicitPathsAreSaved(tc)
c=struct('schemaVersion',1,'pythonExecutable',".venv/bin/python");
a=inkprof.internal.argyllLocalConfig(c,"","auto",false);verifyFalse(tc,isfield(a,'argyllBin'));
a=inkprof.internal.argyllLocalConfig(c,"tools/argyll/bin","explicit",false);
verifyEqual(tc,a.argyllBin,"tools/argyll/bin");verifyEqual(tc,a.argyllBinSource,"explicit");
a=inkprof.internal.argyllLocalConfig(a,"auto","auto",false);verifyFalse(tc,isfield(a,'argyllBin'));
verifyEqual(tc,a.pythonExecutable,c.pythonExecutable);
c.argyllBin="old-computer/bin";
a=inkprof.internal.argyllLocalConfig(c,"","auto",true);verifyFalse(tc,isfield(a,'argyllBin'));
end
