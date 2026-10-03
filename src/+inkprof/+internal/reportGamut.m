function ref=reportGamut(profile,folder)
% Surface generation is optional; failure never changes verification status.
ref=struct('status',"unavailable",'reason',"");
[guard,~]=inkprof.internal.calculationProgress("ICC gamut","Calculating the ICC gamut surface..."); %#ok<ASGLU>
try
 config=inkprof.paths();bin=inkprof.internal.argyllBin("");suffix="";if ispc,suffix=".exe";end
 inkprof.runPython(fullfile(config.Root,'analysis','gamut_surface.py'), ...
  [string(profile),string(folder),fullfile(bin,"iccgamut"+suffix)], ...
  RequiredModules=["numpy","colour"],WorkingDirectory=config.Root,TimeoutSeconds=220);
 ref=jsondecode(fileread(fullfile(folder,'gamut-reference.json')));
catch err
 ref.reason=string(err.message);
end
end
