function [folder,source]=argyllBin(requested)
p=inkprof.paths();
[folder,source]=inkprof.internal.resolveArgyllBin(string(requested),p.Root,p.ArgyllBin, ...
 string(getenv('ARGYLL_BIN')),inkprof.internal.argyllCandidates(),p.ArgyllConfigLegacy);
end
