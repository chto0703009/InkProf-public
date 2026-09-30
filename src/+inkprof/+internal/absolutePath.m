function path=absolutePath(path)
% MATLAB cd and the JVM's user.dir can differ after test/framework callbacks.
path=string(path);
if ~java.io.File(char(path)).isAbsolute(),path=fullfile(string(pwd),path);end
path=string(java.io.File(char(path)).getCanonicalPath());
end
