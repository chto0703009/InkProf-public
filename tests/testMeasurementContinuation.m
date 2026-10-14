% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testMeasurementContinuation
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testConfirmedPassOnly(tc)
t="Ready to read strip pass 7"+newline+"Strip read failed";
[p,o]=inkprof.internal.lastConfirmedPass(t,0);verifyTrue(tc,isnan(p));verifyEqual(tc,o,0);
t=t+newline+"Strip read OK"+newline+"Ready to read strip pass 12";
[p,o]=inkprof.internal.lastConfirmedPass(t,0);verifyEqual(tc,p,7);
[p,~]=inkprof.internal.lastConfirmedPass(t,o);verifyTrue(tc,isnan(p));
t=t+newline+"Ready to read strip pass 8"+newline+"Strip read OK";
[p,~]=inkprof.internal.lastConfirmedPass(t,o);verifyEqual(tc,p,8);
end
function testReuseChecks(tc)
root=string(tempname);mkdir(root);cleanup=onCleanup(@()rmdir(root,'s'));
a=fullfile(root,'old');b=fullfile(root,'new');mkdir(a);mkdir(b);
chart=struct('sourceSHA256',"target",'printControls',struct('sha256',"controls"));
for folder=[a,b],inkprof.internal.writeJson(fullfile(folder,'chart.json'),chart);end
check=struct('definitionSHA256',"controls",'complete',true,'status',"passed");
inkprof.internal.writeJson(fullfile(a,'print-control-check.json'),check);
inkprof.internal.reusePrintControls(a,b);
verifyEqual(tc,inkprof.internal.requirePrintControls(b),jsondecode(fileread(fullfile(a,'print-control-check.json'))));
chart.sourceSHA256="different";inkprof.internal.writeJson(fullfile(b,'chart.json'),chart);
verifyError(tc,@()inkprof.internal.reusePrintControls(a,b),'inkprof:PrintControlFailed');
chart.sourceSHA256="target";inkprof.internal.writeJson(fullfile(b,'chart.json'),chart);
check.status="review-required";inkprof.internal.writeJson(fullfile(a,'print-control-check.json'),check);
verifyError(tc,@()inkprof.internal.reusePrintControls(a,b),'inkprof:PrintControlFailed');
end
