% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function design=serializableRGBDesign(design)
% Runtime UI references are never scientific generation settings.
if isfield(design,'options'),design.options=stripRuntime(design.options);end
if isfield(design,'targetInfo')&&isfield(design.targetInfo,'generation')&& ...
        isfield(design.targetInfo.generation,'settings')
    design.targetInfo.generation.settings=stripRuntime(design.targetInfo.generation.settings);
end
end
function settings=stripRuntime(settings)
fields=intersect(fieldnames(settings),{'Parent','Progress'});
if ~isempty(fields),settings=rmfield(settings,fields);end
end
