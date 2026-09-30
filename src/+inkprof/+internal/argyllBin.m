function folder=argyllBin(requested)
folder=string(requested);
if folder=="", folder=string(getenv('ARGYLL_BIN')); end
if folder=="",config=inkprof.paths();folder=config.ArgyllBin;end
suffix="";if ispc,suffix=".exe";end
if folder==""
    candidates=reshape(split(string(getenv('PATH')),pathsep),1,[]);
    if isunix,candidates=[candidates,"/usr/local/bin","/opt/homebrew/bin"];end
    for candidate=candidates(strlength(candidates)>0)
        if isfile(fullfile(candidate,"targen"+suffix))&&isfile(fullfile(candidate,"printtarg"+suffix)),folder=candidate;break;end
    end
end
assert(folder~="",'inkprof:Argyll','Set ArgyllBin or ARGYLL_BIN to the Argyll bin directory.');
folder=inkprof.internal.absolutePath(folder);
for name=["targen","printtarg"]
    assert(isfile(fullfile(folder,name+suffix)),'inkprof:Argyll','Missing tool %s in %s',name,folder);
end
end
