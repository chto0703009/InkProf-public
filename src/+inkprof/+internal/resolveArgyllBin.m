% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [folder,source]=resolveArgyllBin(requested,root,configured,environment,candidates,legacy)
% Explicit choice > local config > environment > machine-local discovery.
arguments
 requested (1,1) string
 root (1,1) string
 configured (1,1) string
 environment (1,1) string
 candidates string
 legacy (1,1) logical = false
end
folder="";source="auto";
if requested=="auto",configured="";requested="";end
if requested~="",folder=requested;source="explicit";
elseif configured~="",folder=configured;source="config";
elseif environment~="",folder=environment;source="environment";
end
if folder~=""
 folder=resolve(folder);
 if source=="config"&&legacy&&~available(folder)
  warning('inkprof:ArgyllLegacyPath','Saved ArgyllCMS path is unavailable (%s). Discovering this computer''s installation.',folder);
  folder="";source="auto";
  if environment~="",folder=resolve(environment);source="environment";end
 end
 if folder~=""
  assert(available(folder),'inkprof:Argyll','ArgyllCMS tools missing in %s. Set setupInkProf(ArgyllBin="/path/to/bin") or reset with ArgyllBin="auto".',folder);
  return
 end
end
for candidate=reshape(candidates,1,[])
 candidate=resolve(candidate);
 if available(candidate),folder=candidate;return;end
end
error('inkprof:Argyll','ArgyllCMS was not found. Install it (on macOS: brew install argyll-cms), or set setupInkProf(ArgyllBin="/path/to/bin").');
 function p=resolve(p)
  if ~java.io.File(char(p)).isAbsolute(),p=fullfile(root,p);end
  p=inkprof.internal.absolutePath(p);
 end
 function yes=available(p)
  suffix="";if ispc,suffix=".exe";end
  yes=isfile(fullfile(p,"targen"+suffix))&&isfile(fullfile(p,"printtarg"+suffix));
 end
end
