% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Run setupInkProf from the checkout first. Creates new files; no overwrite.
paths=setupInkProf();
source=fullfile(paths.Root,'tests','fixtures','i1profiler', ...
    'ui-verification-3.8.5','InkProf-2040-spectral-M0_M0.txt');
doc=inkprof.importCgats(source);
data=inkprof.cgatsData(doc,RGBScale=255,SpectralScale=1);
disp(size(data.spectralFraction)); % 2040 patches x 36 wavelength bands
folder=fullfile(paths.Projects,"cgats-"+string(datetime('now','Format','yyyyMMdd-HHmmss')));
assert(~isfolder(folder),'Example output already exists.');mkdir(folder);
copyfile(source,fullfile(folder,'original.txt'));
inkprof.exportCgats(fullfile(folder,'measurement.txt'),doc);
