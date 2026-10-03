% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testNumericalDecisionEvidence
tests=functiontests(localfunctions);
end
function testChangedFitIsDecisionOnly(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
root=string(tempname);mkdir(root);c=onCleanup(@()rmdir(root,'s'));
a=struct('summary',struct('count',10,'mean',1,'p95',2,'max',3));
b=struct('summary',struct('count',20,'mean',1.5,'p95',1.8,'max',4));
inkprof.internal.writeJson(fullfile(root,'old.json'),a);inkprof.internal.writeJson(fullfile(root,'new.json'),b);
check=struct('status',"completed",'outputs',struct('fit',"old.json"),'artifacts', ...
 struct('path',"old.json",'sha256',inkprof.internal.sha256(fullfile(root,'old.json'))));
h=struct('step',"cycle",'status',"archived",'cycle',1,'details',struct('checks',check));
w=struct('State',struct('cycle',2,'history',h),'resolve',@(p)fullfile(root,p), ...
 'output',@(~,~)fullfile(root,'new.json'),'valid',@(~)false);
out=fullfile(root,'out');mkdir(out);
r=inkprof.internal.numericalDecisionEvidence(w,out,"unused");
verifyEqual(tc,r.trainingFit.changeCurrentMinusPrevious.mean,.5);
verifyEqual(tc,r.trainingFit.changeCurrentMinusPrevious.p95,-.2,'AbsTol',1e-12);
verifyEqual(tc,r.printAccuracyImprovement,"not-assessed");
verifyTrue(tc,isfile(fullfile(out,'previous-fit.json')));
f=fopen(fullfile(root,'old.json'),'a');fprintf(f,' ');fclose(f);
r=inkprof.internal.numericalDecisionEvidence(w,out,"unused");
verifyFalse(tc,isfield(r.trainingFit,'previous'));
end
