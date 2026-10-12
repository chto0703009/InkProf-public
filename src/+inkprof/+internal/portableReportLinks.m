% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function text=portableReportLinks(text,prefix)
% Redirect local evidence links for either HTML attribute quote style.
text=regexprep(string(text),"(href|src)='(?![A-Za-z][A-Za-z0-9+.-]*:|//|#)","$1='"+prefix+"/");
text=regexprep(text,"(href|src)=""(?![A-Za-z][A-Za-z0-9+.-]*:|//|#)","$1="""+prefix+"/");
end
