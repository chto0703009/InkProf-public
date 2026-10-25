% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function yes=argyllUsable(folder)
%ARGYLLUSABLE Files must launch and report a version, not merely exist.
yes=false;suffix="";if ispc,suffix=".exe";end
for tool=["targen","printtarg"]
 executable=fullfile(folder,tool+suffix);if ~isfile(executable),return;end
 try
  result=inkprof.internal.runTool(executable,"-?",string(tempdir),15,true);
  if isempty(regexp(char(result.output),'Version\s+[0-9]+\.[0-9]+','once')),return;end
 catch
  return
 end
end
yes=true;
end
