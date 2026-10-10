% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function check=overridePrintControls(folder,reason)
% Record a reasoned exception without changing measurements or reference.
arguments
 folder (1,1) string
 reason (1,1) string
end
reason=strtrim(reason);
assert(strlength(reason)>0,'inkprof:OverrideReason','Enter the reason for overriding the RGB print check.');
chart=jsondecode(fileread(fullfile(folder,'chart.json')));
file=fullfile(folder,'print-control-check.json');original=jsondecode(fileread(file));
assert(isfield(chart,'printControls')&&string(original.definitionSHA256)==string(chart.printControls.sha256), ...
 'inkprof:PrintControlFailed','RGB check belongs to a different printed target.');
assert(original.complete&&string(original.status)=="review-required"&&isfield(original,'readings')&& ...
 any([original.readings.flagged]),'inkprof:PrintControlFailed','Only a completed RGB check with measured deviations can be overridden.');
date=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
decision=struct('schemaVersion',1,'documentType',"inkprof.print-control-override", ...
 'reason',reason,'decidedAt',date,'originalCheck',original,'originalCheckSHA256',inkprof.internal.sha256(file));
relative=fullfile('print-control-overrides',string(java.util.UUID.randomUUID())+".json");
mkdir(fullfile(folder,'print-control-overrides'));
inkprof.internal.writeJson(fullfile(folder,relative),decision);
check=original;check.status="override-approved";
check.override=struct('reason',reason,'decidedAt',date,'previousStatus',string(original.status), ...
 'decisionFile',relative,'decisionSHA256',inkprof.internal.sha256(fullfile(folder,relative)));
inkprof.internal.writeJson(file,check);
end
