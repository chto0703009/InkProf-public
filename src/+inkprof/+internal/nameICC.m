function receipt=nameICC(source,destination,name)
% Name a delivery copy; the scientific candidate remains unchanged.
config=inkprof.paths();file=string(tempname)+".json";clean=onCleanup(@()remove(file));
inkprof.runPython(fullfile(config.Root,'analysis','rename_icc.py'), ...
 [string(source),string(destination),string(name),file]);
receipt=jsondecode(fileread(file));
assert(inkprof.internal.sha256(source)==string(receipt.sourceSHA256)&& ...
 inkprof.internal.sha256(destination)==string(receipt.sha256),'inkprof:Integrity','ICC changed during naming.');
end
function remove(file)
if isfile(file),delete(file);end
end
