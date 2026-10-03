% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function figureHandle=previewTarget(folder)
%PREVIEWTARGET Display package previews; never use these PNGs for printing.
arguments
    folder (1,1) string
end
manifest=jsondecode(fileread(fullfile(folder,'manifest.json')));
files=string({manifest.files.name});files=files(endsWith(files,'-preview.png'));
assert(~isempty(files),'inkprof:Preview','No previews found.');
figureHandle=figure('Name','InkProf target preview — not for printing');
tiledlayout('flow');
for file=reshape(files,1,[])
    nexttile;image(imread(fullfile(folder,file)));axis image off;title(file,'Interpreter','none');
end
end
