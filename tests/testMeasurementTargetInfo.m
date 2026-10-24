% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testMeasurementTargetInfo
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testPreparedTargetReadableAndStillLocked(tc)
folder=string(tempname);mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s'));
source=fullfile(folder,'target.ti2');writelines('Synthetic TI2 identity fixture',source);
inkprof.internal.writeJson(fullfile(folder,'target.json'),struct('ids',{{'1','2'}}, ...
 'targetInfo',struct('generation',struct('method','C2 profile test'))));
inkprof.internal.writeJson(fullfile(folder,'manifest.json'),struct('createdUTC','2026-10-16T11:16:55Z','pageCount',1));
inkprof.internal.writeJson(fullfile(folder,'chart.json'),struct('sourcePath',source));
before=inkprof.internal.sha256(fullfile(folder,'chart.json'));
d=inkprof.MeasurementDialog(folder);guard=onCleanup(@()delete(d));
text=string(findobj(d.Figure,'Tag','targetSummary').Value);
verifyTrue(tc,any(contains(text,'C2 profile test')));verifyTrue(tc,any(contains(text,'Patches: 2')));
verifyTrue(tc,any(contains(text,'Printed pages: 1')));verifyTrue(tc,any(contains(text,'2026-10-16T11:16:55Z')));
verifyEqual(tc,string(findobj(d.Figure,'Tag','browse').Enable),"off");
verifyEqual(tc,string(findobj(d.Figure,'Tag','browse').Text),"Target locked");
verifyEqual(tc,string(findobj(d.Figure,'Tag','targetFile').Tooltip),source);
b=findobj(d.Figure,'Tag','targetDetails');b.ButtonPushedFcn(b,[]);
details=findall(groot,'Tag','InkProfMeasurementTargetDetails');closeDetails=onCleanup(@()delete(details));
verifyEqual(tc,numel(details),1);verifyEqual(tc,string(details.WindowStyle),"modal");
verifyEqual(tc,inkprof.internal.sha256(fullfile(folder,'chart.json')),before);
end
function testUnboundAndMissingMetadata(tc)
d=inkprof.MeasurementDialog();guard=onCleanup(@()delete(d));
verifyEqual(tc,string(findobj(d.Figure,'Tag','browse').Enable),"on");
verifyEqual(tc,string(findobj(d.Figure,'Tag','targetSummary').Value),"No target selected.");
lines=inkprof.internal.measurementTargetInfo("missing-file.ti2");verifyTrue(tc,any(contains(lines,'TI2: missing-file.ti2')));
end
