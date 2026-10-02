function result=verifyProject(folder)
%VERIFYPROJECT Read-only SHA-256 inventory check, independent of the root path.
arguments
 folder (1,1) string
end
root=inkprof.internal.absolutePath(folder);file=fullfile(root,'inkprof-project.json');
assert(isfile(file),'inkprof:Project','Select a folder containing inkprof-project.json.');
r=jsondecode(fileread(file));
assert(r.schemaVersion==1&&string(r.documentType)=="inkprof.profiling-project",'inkprof:Project','Unsupported project manifest.');
issues=strings(0,1);checked=0;
for name=[".workflow.lock",".manifest.lock"]
 if isfile(fullfile(root,name)),issues(end+1)="Project is busy or was copied with an active lock: "+name;end
end
for entry=reshape(r.files,1,[])
 relative=string(entry.path);
 if inkprof.internal.isFinderMetadata(relative),continue;end
 path=inkprof.internal.absolutePath(fullfile(root,relative));
 if ~startsWith(path,root+filesep)
  issues(end+1)="Reference points outside the project: "+relative;
 elseif ~isfile(path)
  issues(end+1)="Missing file: "+relative;
 elseif inkprof.internal.sha256(path)~=string(entry.sha256)
  issues(end+1)="Changed file: "+relative;
 else
  checked=checked+1;
 end
end
result=struct('passed',isempty(issues),'projectId',string(r.projectId),'root',root, ...
 'checkedFiles',checked,'issues',issues);
end
