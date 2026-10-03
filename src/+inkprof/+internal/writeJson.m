% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function writeJson(path,value)
text=jsonencode(value,PrettyPrint=true);
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0,'inkprof:IO','Cannot write %s',path);
c=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',text);
end
