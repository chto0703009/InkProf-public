function yes=isFinderMetadata(path)
% Finder view preferences are not profiling evidence, including legacy entries.
path=replace(string(path),"\","/");
yes=path==".DS_Store"|endsWith(path,"/.DS_Store");
end
