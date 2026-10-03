% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function config=argyllLocalConfig(config,requested,source,legacy)
% Keep only an explicit per-checkout override, never an autodetected path.
if requested=="auto" || (requested==""&&legacy&&source~="config")
 for key=["argyllBin","argyllBinSource"]
  if isfield(config,key),config=rmfield(config,key);end
 end
elseif requested~=""
 config.argyllBin=requested;config.argyllBinSource="explicit";
end
end
