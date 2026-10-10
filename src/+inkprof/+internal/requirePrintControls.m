% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function check=requirePrintControls(folder)
% No requirement for old prints. New prints must pass or approve a baseline.
chart=jsondecode(fileread(fullfile(folder,'chart.json')));check=struct;
if ~isfield(chart,'printControls'),return;end
file=fullfile(folder,'print-control-check.json');
assert(isfile(file),'inkprof:PrintControlFailed','Separate RGB print controls were not completed. Check the print before measuring the profiling rows.');
check=jsondecode(fileread(file));
assert(string(check.definitionSHA256)==string(chart.printControls.sha256),'inkprof:PrintControlFailed','RGB check belongs to a different printed target.');
if string(check.status)=="override-approved"
 assert(check.complete&&isfield(check,'override')&&strlength(strtrim(string(check.override.reason)))>0, ...
  'inkprof:PrintControlFailed','RGB override requires completed readings and a written reason.');
 evidence=fullfile(folder,check.override.decisionFile);
 assert(isfile(evidence)&&inkprof.internal.sha256(evidence)==string(check.override.decisionSHA256), ...
  'inkprof:PrintControlFailed','RGB override decision is missing or changed.');
 decision=jsondecode(fileread(evidence));current=rmfield(check,'override');current.status=check.override.previousStatus;
 assert(string(decision.documentType)=="inkprof.print-control-override"&& ...
  string(decision.reason)==string(check.override.reason)&&string(decision.decidedAt)==string(check.override.decidedAt)&& ...
  isequaln(current,decision.originalCheck)&&string(current.status)=="review-required"&& ...
  isfield(current,'readings')&&any([current.readings.flagged]), ...
  'inkprof:PrintControlFailed','RGB override does not match the measured check and decision.');
 return;
end
if isfield(check,'readings')&&~isempty(check.readings)
 flagged=check.readings([check.readings.flagged]);
 if ~isempty(flagged)
  details=strings(1,numel(flagged));
  for k=1:numel(flagged),details(k)=sprintf('page %d %s: %.2f dE00',flagged(k).page,string(flagged(k).label),flagged(k).deltaE00);end
  assert(false,'inkprof:PrintControlFailed','RGB print check FAILED: %s (review threshold %.2f dE00). Check print colour management and paper settings.',join(details,', '),check.thresholdDeltaE00);
 end
end
assert(check.complete&&any(string(check.status)==["passed","reference-approved"]),'inkprof:PrintControlFailed', ...
 'RGB print check failed or needs an approved reference (status: %s). Review the page/control results, print settings and paper.',string(check.status));
end
