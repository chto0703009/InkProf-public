% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function message=profileJobProgressMessage(log,elapsed)
% Argyll stages are activity indicators, not completion percentages.
phase="Argyll is fitting the ICC profile.";
lines=splitlines(replace(string(log),char(13),newline));
for line=reshape(lines,1,[])
 if contains(line,'adjust a and b output curves','IgnoreCase',true)
  phase="Argyll is adjusting the white-point output curves.";
 elseif contains(line,'grid position input curves','IgnoreCase',true)
  phase="Argyll is creating the grid input curves.";
 elseif contains(line,'final clut','IgnoreCase',true)
  phase="Argyll is creating the final colour lookup table (CLUT). This can take several minutes.";
 end
end
seconds=max(0,floor(elapsed));
message=phase+newline+sprintf('Working — elapsed %d min %02d sec. Please wait.',floor(seconds/60),mod(seconds,60));
end
