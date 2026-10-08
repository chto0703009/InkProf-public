% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function proposal=argyllRefinementCandidates(design,training,spacing)
% Preserve Argyll placement; remove existing/near-duplicate device RGB only.
rgb=double(design.rgb(1:design.fitCount,:))*100;
existing=double(training);candidates=struct('rgbPercent',{},'patchId',{});
for k=1:size(rgb,1)
 c=round(rgb(k,:)/100*65535)*100/65535;
 if ~isempty(existing)&&min(vecnorm(existing-c,2,2))<spacing,continue;end
 q=round(c/100*65535);
 candidates(end+1)=struct('rgbPercent',c,'patchId',string(sprintf('argyll-%05d-%05d-%05d',q))); %#ok<AGROW>
 existing(end+1,:)=c; %#ok<AGROW>
end
proposal=struct('candidates',candidates,'diagnostics',{{}},'stopReason',"Argyll placement complete; existing RGB excluded", ...
 'errorNorm',struct('type',"not assessed for Argyll target placement",'value',0,'target',0,'count',0,'excludedCount',0,'available',false));
end
