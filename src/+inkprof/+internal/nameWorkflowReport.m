% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function paths=nameWorkflowReport(w,folder)
% Keep canonical report assets and expose human-readable report filenames.
p=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
stem=inkprof.internal.certificateDeliveryName(inkprof.internal.projectDeliveryProfileName(p),w.State.cycle,w.State.iterationId);
paths=struct;
for pair=["pdf","pdf";"html","html";"text","txt"]'
 destination=fullfile(folder,stem+"."+pair(2));
 copyfile(fullfile(folder,"final-report."+pair(2)),destination);
 paths.(pair(1))=destination;
end
paths.json=fullfile(folder,'final-report.json');
end
