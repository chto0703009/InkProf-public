% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function next=recommendWorkflowStep(state,assessment,mode)
% Recommend navigation from valid evidence, never complete or execute a step.
if nargin<3,mode="profiling";end
defs=inkprof.internal.workflowSteps(mode);
next=struct('id',"",'label',"",'reason',"All required work is complete. Choose verification or refinement if needed.",'ready',false);
if valid('export'),return;end
% An older numerical-only delivery must not hide a newly approved print.
if valid('approve')&&ready('export')
 choose('export',"Your print assessment is saved. Save the ICC and measurement certificate, then choose where to save delivery copies.");return;
end
if valid('numericalExport'),return;end
% Failed numerical builds need review, not an identical automatic retry.
if isfield(state,'steps')&&isfield(state.steps,'continue')&& ...
 string(state.steps.continue.status)=="failed"&&contains(lower(string(state.steps.continue.message)),"numerical")
 choose('continue',"The new candidate failed numerical checks. Open the latest failed iteration's C1 and Grid reports before retrying. Your saved measurements are retained.");
 next.label="17. Review stopped profile build";return;
end
% An existing reviewed print should lead directly to its measurement.
if valid('refine')
 if ~valid('refinemeasurement'),choose('refinemeasurement',"Print the registered TIFF16 package, allow it to dry, then measure its matching TI2.");return;end
 if ~valid('continue'),choose('continue',"The refinement measurement is saved. Build the next profile from it.");return;end
end
% After building an iteration, compare it once before checking its new ICC.
if string(state.currentStep)=="continue"&&ready('compare')&&~valid('compare')
 choose('compare',"Compare the new profile with the previous iteration; this does not replace C1 checks.");return;
end
if valid('profile')&&~valid('checks')&&mode~="verification"
 choose('checks',"The current ICC needs up-to-date Fit, Grid and C1 checks before verification or refinement.");return;
end
order=["definition","render","measurement","review","input","recipe","profile","checks","c2","c2measurement","c3","feedback","approve","export"];
for id=order
 index=find(string({defs.id})==id,1);
 if isempty(index)||~defs(index).enabled||valid(id),continue;end
 if ready(id)
  explanation="Complete this step to continue the current workflow.";
  if id=="recipe",explanation="Review and save the profile recipe before building the ICC in B3.";end
  if id=="c2",explanation="Verify the current ICC with a new print. Alternatively choose step 19 for numerical-only delivery or Refinement tools for more measurements.";end
  if id=="measurement"||id=="c2measurement",explanation="Print the saved target, allow drying, then measure the matching TI2. Creating a TIFF does not confirm that it was physically printed.";end
  if id=="approve",explanation="Review the measured result and decide whether it is suitable for the intended use.";end
  choose(id,explanation);return;
 end
end
 function yes=valid(id)
  yes=isfield(assessment,id)&&assessment.(id).valid;
 end
 function yes=ready(id)
  yes=isfield(assessment,id)&&assessment.(id).ready;
 end
 function choose(id,reason)
  index=find(string({defs.id})==string(id),1);
  number=sum([defs(1:index).enabled]);
  next.id=string(id);next.label=string(number)+". "+regexprep(string(defs(index).label),'^\d+\.\s*','');next.reason=reason;next.ready=ready(id);
 end
end
