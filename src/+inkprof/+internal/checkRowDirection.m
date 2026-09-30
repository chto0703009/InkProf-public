function check=checkRowDirection(folder,result)
% Diagnostic failure must not prevent saving the measured data.
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
try
 input=fullfile(w,'measurement.json');output=fullfile(w,'check.json');
 inkprof.internal.writeJson(input,result);paths=inkprof.paths();
 inkprof.runPython(fullfile(paths.Root,'analysis','row_direction_check.py'), ...
  [fullfile(folder,'chart.json'),input,output],RequiredModules=["numpy","colour"]);
 check=jsondecode(fileread(output));
catch err
 check=struct('available',false,'reason',string(err.message));
end
end
