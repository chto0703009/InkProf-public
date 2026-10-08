% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function info=inspectPreconditionProfile(file)
%INSPECTPRECONDITIONPROFILE Validate an existing RGB output ICC for targen -c.
% Structural check only (profiles/read_icc.py); the profile's accuracy is not
% evaluated. It only steers patch placement; it is never used as measured data.
file=inkprof.internal.absolutePath(file);
assert(isfile(file),'inkprof:Precondition','Pre-conditioning profile not found: %s',file);
paths=inkprof.paths();w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
inkprof.runPython(fullfile(paths.Root,'profiles','read_icc.py'),[file,fullfile(w,'inspection.json')]);
r=jsondecode(fileread(fullfile(w,'inspection.json')));
assert(r.capabilities.rgbOutputCandidate,'inkprof:Precondition', ...
    'Pre-conditioning needs an RGB printer (output) ICC profile with a Lab or XYZ PCS.');
assert(inkprof.internal.sha256(file)==string(r.source.sha256),'inkprof:Integrity','Profile changed during inspection.');
[~,stem,ext]=fileparts(file);
description="";
if isfield(r,'descriptions')&&~isempty(r.descriptions)
    d=r.descriptions;if iscell(d),d=d{1};end
    description=string(d(1).text);
end
info=struct('path',file,'fileName',stem+ext,'sha256',string(r.source.sha256),'description',description, ...
    'profileClass',string(r.header.profileClass),'pcs',string(r.header.pcs),'iccVersion',string(r.header.version), ...
    'role',"targen -c pre-conditioning: perceptual distances for patch placement only; not measurement data");
end
