function recordProjectStep(path,step)
% Existing standalone workflows remain supported; project members register work.
root=inkprof.internal.findProject(path);
if root=="",return;end
try,inkprof.updateProject(root,Step=step);
catch err
 warning('inkprof:ManifestUpdate','Artifacts were saved, but manifest update failed: %s. Run inkprof.updateProject("%s").',err.message,root);
end
end
