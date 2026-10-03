% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Render any RGB patch list using the InkProf page template.
paths=setupInkProf();
source=fullfile(paths.Projects,'mitt-target.ti1');
output=fullfile(paths.Projects,'mitt-target.tif');
info=inkprof.createTiff16(source,output,DPI=300,Randomize=true,Seed=42);
disp(info.tiffs);
% For CGATS input, also specify RGBScale=255 (or the actual source scale).
% To preserve the original 575 reference order, use the legacy three-path call.
