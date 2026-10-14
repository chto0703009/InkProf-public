% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function reusePrintControls(previous,folder)
% Reuse only after the user confirms the SAME physical print.
a=jsondecode(fileread(fullfile(previous,'chart.json')));
b=jsondecode(fileread(fullfile(folder,'chart.json')));
assert(string(a.sourceSHA256)==string(b.sourceSHA256)&& ...
 string(a.printControls.sha256)==string(b.printControls.sha256), ...
 'inkprof:PrintControlFailed','Previous RGB controls belong to another target.');
check=inkprof.internal.requirePrintControls(previous);
if isfield(check,'override')
 name=string(check.override.decisionFile);
 assert(~contains(name,'..')&&~startsWith(name,["/","\"]),'inkprof:Integrity','Invalid RGB evidence path.');
 destination=fullfile(folder,name);parent=fileparts(destination);if ~isfolder(parent),mkdir(parent);end
 copyfile(fullfile(previous,name),destination);
end
copyfile(fullfile(previous,'print-control-check.json'),fullfile(folder,'print-control-check.json'));
inkprof.internal.requirePrintControls(folder);
inkprof.internal.writeJson(fullfile(folder,'print-control-reuse.json'),struct( ...
 'documentType',"inkprof.print-control-reuse",'samePhysicalPrintConfirmed',true, ...
 'previousFolder',string(previous),'sourceSHA256',string(a.sourceSHA256), ...
 'controlCheckSHA256',inkprof.internal.sha256(fullfile(previous,'print-control-check.json'))));
end
