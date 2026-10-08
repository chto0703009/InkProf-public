% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function text=targetInfoText(info)
%TARGETINFOTEXT Single summary line; full precision/provenance stays in JSON.
source=string(info.source.fileName);if source=="",source="generated target";end
method=string(info.generation.method);
catalogue=inkprof.internal.targetMethods();known=[catalogue.id]==method;
if any(known),method=catalogue(known).short;end
if isfield(info.generation,'preconditioning')&&isstruct(info.generation.preconditioning)&&isfield(info.generation.preconditioning,'fileName')
    method=method+" (pre-cond. "+string(info.generation.preconditioning.fileName)+")";
end
if method=="unknown",method="imported "+upper(erase(string(info.source.format),"."));end
text="Source: "+source+" | "+method+" | "+info.patchCount+" patches / "+info.uniqueRGBCount+" unique";
if isfield(info.generation,'initialLevels')
    text=text+" | start "+info.generation.initialLevels+"^3, +"+info.generation.iterations;
end
if isfield(info,'verification')&&isstruct(info.verification)&&isfield(info.verification,'profileName')
    % Profile test / verification print: state what the pixels already contain.
    v=info.verification;name=string(v.profileName);if strlength(name)>36,name=extractBefore(name,34)+"...";end
    hash=string(v.profileSHA256);if strlength(hash)>8,hash=extractBefore(hash,9);end
    if v.profileApplied
        text=text+" | ICC "+name+" ("+hash+") applied, abs., no BPC - print CM OFF";
    else
        text=text+" | device RGB, ICC "+name+" ("+hash+") not applied - print CM OFF";
    end
    if isfield(v,'referenceSet')
        ref=string(v.referenceSet);if strlength(ref)>32,ref=extractBefore(ref,30)+"...";end
        text=text+" | ref. "+ref;
    end
    return
end
if ~isempty(info.network.maxEdge)
    text=text+" | RGB edge max "+compose('%.4f',info.network.maxEdge);
else
    text=text+" | RGB dimension "+info.network.dimension;
end
end
