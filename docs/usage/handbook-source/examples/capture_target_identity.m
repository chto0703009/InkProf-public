% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Synthetic documentation fixture; no instrument measurement.
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(fileparts(fileparts(here))));
addpath(fullfile(root,'src'));
f=fullfile(string(tempdir),"InkProf-documentation-example");assert(~isfolder(f));mkdir(f);cleanup=onCleanup(@()rmdir(f,'s'));
pkg=fullfile(f,'Example printer paper','targets','C2-review');mkdir(pkg);
source=fullfile(pkg,'target.ti2');writelines('Documentation fixture - no measurement',source);
inkprof.internal.writeJson(fullfile(pkg,'target.json'),struct('ids',string(1:141),'targetInfo',struct('generation',struct('method','C2 profile test'))));
inkprof.internal.writeJson(fullfile(pkg,'manifest.json'),struct('createdUTC','2026-10-16T11:16:55Z','pageCount',1));
session=fullfile(f,'session');mkdir(session);inkprof.internal.writeJson(fullfile(session,'chart.json'),struct('sourcePath',source));
d=inkprof.MeasurementDialog(session);guard=onCleanup(@()delete(d));
text=string(findobj(d.Figure,'Tag','targetSummary').Value);assert(any(contains(text,'Patches: 141')));
output=fullfile(here,'measurement-target-identity.png');exportapp(d.Figure,output);
im=imread(output);imwrite(im(1:min(380,size(im,1)),:,:),output);
