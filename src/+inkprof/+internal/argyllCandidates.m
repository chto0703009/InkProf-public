function candidates=argyllCandidates(architecture,searchPath,homebrewPrefix)
% Stable Homebrew prefixes also work when MATLAB was launched from Finder.
arguments
 architecture (1,1) string = string(computer('arch'))
 searchPath (1,1) string = string(getenv('PATH'))
 homebrewPrefix (1,1) string = string(getenv('HOMEBREW_PREFIX'))
end
prefixes=strings(1,0);
if architecture=="maca64",prefixes=["/opt/homebrew","/usr/local"];
elseif architecture=="maci64",prefixes=["/usr/local","/opt/homebrew"];
elseif startsWith(architecture,"glnx"),prefixes="/home/linuxbrew/.linuxbrew";
end
if homebrewPrefix~="",prefixes=[homebrewPrefix,prefixes];end
candidates=strings(1,0);
for prefix=prefixes
 candidates=[candidates,fullfile(prefix,'opt','argyll-cms','bin'),fullfile(prefix,'bin')]; %#ok<AGROW>
end
candidates=[candidates,reshape(split(searchPath,pathsep),1,[])];
candidates=unique(candidates(strlength(candidates)>0),'stable');
end
