% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function text=dialogText(value)
%DIALOGTEXT Preserve multiline inputdlg responses as one scalar string.
% MATLAB may return a padded character matrix rather than a character row.
lines=strip(string(value),'right');
if isempty(lines),text="";else,text=strjoin(lines(:),newline);end
end
