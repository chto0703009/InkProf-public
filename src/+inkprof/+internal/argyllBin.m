% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [folder,source]=argyllBin(requested)
%ARGYLLBIN Prefer the shipped native tools; validate any machine-local fallback.
p=inkprof.paths();requested=string(requested);hardware=inkprof.internal.nativeArchitecture();
if ismac
 bundled=fullfile(p.Root,'third_party','argyll',hardware.Physical,'Argyll_V3.5.0','bin');
 if (requested=="" || requested=="auto") && inkprof.internal.argyllUsable(bundled)
  folder=inkprof.internal.absolutePath(bundled);source="auto";return
 end
end
if requested~="" && requested~="auto"
 folder=requested;if ~java.io.File(char(folder)).isAbsolute(),folder=fullfile(p.Root,folder);end
 assert(inkprof.internal.argyllUsable(folder),'inkprof:ArgyllUnavailable', ...
  'ArgyllCMS cannot run on this computer: %s. Use setupInkProf(ArgyllBin="auto") from the updated InkProf folder.',folder);
 folder=inkprof.internal.absolutePath(folder);source="explicit";return
end
configured=p.ArgyllBin;environment=string(getenv('ARGYLL_BIN'));
if configured~="" && ~inkprof.internal.argyllUsable(configured),configured="";end
if environment~="" && ~inkprof.internal.argyllUsable(environment),environment="";end
candidates=inkprof.internal.argyllCandidates();usable=false(size(candidates));native=false(size(candidates));
for k=1:numel(candidates)
 usable(k)=inkprof.internal.argyllUsable(candidates(k));
 if usable(k),info=inkprof.internal.nativeArchitecture(fullfile(candidates(k),'targen'));native(k)=info.Native;end
end
if hardware.Physical=="arm64" && any(native & usable)
 if configured~="",info=inkprof.internal.nativeArchitecture(fullfile(configured,'targen'));if ~info.Native,configured="";end,end
 if environment~="",info=inkprof.internal.nativeArchitecture(fullfile(environment,'targen'));if ~info.Native,environment="";end,end
end
candidates=[candidates(usable & native),candidates(usable & ~native)];
[folder,source]=inkprof.internal.resolveArgyllBin(requested,p.Root,configured,environment,candidates,p.ArgyllConfigLegacy);
end
