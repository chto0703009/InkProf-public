% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function file=latestGamutProposal(project,profile)
% Offer only saved selections for the exact current ICC, newest first.
file="";sha=inkprof.internal.sha256(profile);
entries=dir(fullfile(project,'refinements','*','proposal.json'));
[~,order]=sort([entries.datenum],'descend');
for k=order
 candidate=string(fullfile(entries(k).folder,entries(k).name));
 try
  p=jsondecode(fileread(candidate));
  if string(p.documentType)=="inkprof.gamut-refinement"&&string(p.sourceProfileSHA256)==sha&&~isempty(p.candidates)
   file=candidate;return;
  end
 catch
  % Unrelated/incomplete folders are not offered as a saved selection.
 end
end
end
