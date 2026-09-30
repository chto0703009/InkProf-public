function root=findProject(path)
% Locate the owning profiling project without changing global configuration.
root="";path=inkprof.internal.absolutePath(path);
if ~isfolder(path),path=fileparts(path);end
while strlength(path)>0
 if isfile(fullfile(path,'inkprof-project.json')),root=path;return;end
 parent=fileparts(path);if parent==path,return;end;path=parent;
end
end
