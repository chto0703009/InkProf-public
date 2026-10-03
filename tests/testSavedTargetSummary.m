% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testSavedTargetSummary
tests=functiontests(localfunctions);
end
function testRefinementSummaryIsColumn(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
folder=string(tempname);mkdir(folder);clean=onCleanup(@()rmdir(folder,'s'));
inkprof.internal.writeJson(fullfile(folder,'target.json'),struct('ids',["1","2","3"]));
inkprof.internal.writeJson(fullfile(folder,'proposal.json'),struct('candidates',[1 2]));
f=fopen(fullfile(folder,'target.tif'),'w');fclose(f);
w=struct('State',struct('steps',struct('refine',struct('outputs', ...
    struct('target',fullfile(folder,'target.ti2'),'proposal',fullfile(folder,'proposal.json'))))), ...
    'resolve',@(p)p);
lines=inkprof.internal.savedTargetSummary(w,"refine");
verifySize(tc,lines,[4 1]);
verifyTrue(tc,contains(lines(1),'3 patches in 1 TIFF16'));
verifyTrue(tc,contains(lines(2),'New refinement patches: 2'));
end
