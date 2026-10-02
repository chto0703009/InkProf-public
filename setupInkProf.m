function paths=setupInkProf(options)
%SETUPINKPROF Add this checkout to MATLAB and configure external Argyll tools.
% Run once per MATLAB session from the checkout root. No savepath is required.
% setupInkProf(ArgyllBin="C:\Tools\Argyll\bin") on a new Windows machine, etc.
arguments
    options.ArgyllBin (1,1) string = ""
    options.PythonExecutable (1,1) string = ""
    options.CheckPython (1,1) logical = false
    options.SaveLocalConfig (1,1) logical = true
    options.VerifyTools (1,1) logical = true
end
root=string(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src'));
paths=inkprof.paths();
[paths.ArgyllBin,paths.ArgyllSource]=inkprof.internal.argyllBin(options.ArgyllBin);
if options.VerifyTools
    suffix="";if ispc,suffix=".exe";end
    temp=string(tempname);mkdir(temp);cleanup=onCleanup(@()rmdir(temp,'s'));
    for tool=["targen","printtarg"]
        result=inkprof.internal.runTool(fullfile(paths.ArgyllBin,tool+suffix),"-?",temp,30,true);
        assert(~isempty(regexp(char(result.output),'Version\s+[0-9]+\.[0-9]+','once')), ...
            'inkprof:Version','Cannot verify %s.',tool);
    end
end
if options.PythonExecutable~=""
    paths.PythonConfigured=options.PythonExecutable;
    paths.PythonExecutable=inkprof.internal.pythonExecutable(options.PythonExecutable,paths.Root,"");
end
if options.CheckPython || options.PythonExecutable~=""
    inkprof.checkPython(PythonExecutable=paths.PythonExecutable);
end
if options.SaveLocalConfig
    directory=fileparts(paths.LocalConfig);if ~isfolder(directory),mkdir(directory);end
    config=struct('schemaVersion',1);
    if isfile(paths.LocalConfig),config=jsondecode(fileread(paths.LocalConfig));end
    config=inkprof.internal.argyllLocalConfig(config,options.ArgyllBin,paths.ArgyllSource,paths.ArgyllConfigLegacy);
    % An auto-discovered .venv is never saved as an absolute machine path.
    if paths.PythonConfigured~="",config.pythonExecutable=paths.PythonConfigured;end
    inkprof.internal.writeJson(paths.LocalConfig,config);
end
fprintf('InkProf: %s\nArgyllCMS: %s\nProject data: %s\n',paths.Root,paths.ArgyllBin,paths.Projects);
end
