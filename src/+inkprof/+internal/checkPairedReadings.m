function check=checkPairedReadings(result,threshold)
% Keep analysis failures separate from successful measurement saving.
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
input=fullfile(w,'input.json');output=fullfile(w,'result.json');
inkprof.internal.writeJson(input,result);paths=inkprof.paths();
try
 inkprof.runPython(fullfile(paths.Root,'analysis','paired_check.py'), ...
  [input,output,"--threshold",string(threshold)],RequiredModules=["numpy","colour"]);
 check=jsondecode(fileread(output));check.available=true;
catch err
 check=struct('available',false,'threshold',threshold,'reason',string(err.message));
end
end
