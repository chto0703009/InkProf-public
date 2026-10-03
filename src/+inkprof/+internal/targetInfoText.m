% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function text=targetInfoText(info)
%TARGETINFOTEXT Single summary line; full precision/provenance stays in JSON.
source=string(info.source.fileName);if source=="",source="generated target";end
method=string(info.generation.method);
if method=="argyll",method="Argyll OFPS";elseif method=="mesh",method="InkProf mesh";end
if method=="unknown",method="imported "+upper(erase(string(info.source.format),"."));end
text="Source: "+source+" | "+method+" | "+info.patchCount+" patches / "+info.uniqueRGBCount+" unique";
if isfield(info.generation,'initialLevels')
    text=text+" | start "+info.generation.initialLevels+"^3, +"+info.generation.iterations;
end
if ~isempty(info.network.maxEdge)
    text=text+" | RGB edge max "+compose('%.4f',info.network.maxEdge);
else
    text=text+" | RGB dimension "+info.network.dimension;
end
end
