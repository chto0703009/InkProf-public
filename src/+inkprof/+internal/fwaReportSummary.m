% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function r=fwaReportSummary(fit,verification,printing,profileHash)
% Report actual processing evidence, never infer application from a UI choice.
r=struct('applied',[],'status',"Not documented",'projectChoice',false, ...
 'illuminant',"Not documented",'profileSHA256',string(profileHash), ...
 'trainingResult',struct,'verificationResult',struct, ...
 'effectComparedWithUncompensated',"Not assessed. No controlled comparison with an equivalent uncompensated profile is reported. These results alone do not show whether FWA compensation improved reproduction.");
r.projectChoice=isfield(printing,'fwaCompensation')&&isequal(printing.fwaCompensation,true);
if isfield(fit,'colorimetry')&&isfield(fit.colorimetry,'fwaCompensation')
 r.applied=logical(fit.colorimetry.fwaCompensation);
 if r.applied
  r.status="Yes - FWA/OBA compensation used";
  if isfield(fit.colorimetry,'fwaIlluminant'),r.illuminant=string(fit.colorimetry.fwaIlluminant);end
 else
  r.status="No - FWA/OBA compensation not used";r.illuminant="Not applicable";
 end
end
if ~isempty(r.applied)&&isfield(verification,'colorimetry')&&isfield(verification.colorimetry,'fwaCompensation')
 assert(r.applied==logical(verification.colorimetry.fwaCompensation),'inkprof:FinalReport', ...
  'Profile and verification use different FWA settings. Repeat verification before exporting.');
end
if isfield(fit,'summary'),r.trainingResult=fit.summary;end
if isfield(verification,'summary'),r.verificationResult=verification.summary;end
choice="No";if r.projectChoice,choice="Yes";end
r.summaryText="Applied in the delivered profile: "+r.status+newline+ ...
 "Saved project FWA choice: "+choice+newline+ ...
 "Simulated illuminant: "+r.illuminant+newline+ ...
 "Profile results with the above setting:"+newline+ ...
 describe("Training fit (not independent verification)",r.trainingResult)+newline+ ...
 describe("Verification print",r.verificationResult)+newline+ ...
 "FWA effect compared with no compensation: "+r.effectComparedWithUncompensated;
if ~isempty(r.applied)&&r.applied
 r.summaryText=r.summaryText+newline+"Compensation calculates a simulated D50 response from native M0 spectra; this is not a direct UV excitation measurement or measured M1. White-spectrum averaging reduces random variation but cannot recover missing UV excitation. A weak fluorescence signal may remain uncertain.";
 if isfield(fit,'fwaPreparation')&&isstruct(fit.fwaPreparation)&&isfield(fit.fwaPreparation,'white')
  r.preparation=fit.fwaPreparation;
  r.summaryText=r.summaryText+newline+"Training white reference: "+string(fit.fwaPreparation.white.source)+"; readings: "+string(fit.fwaPreparation.white.count)+". Compensation applied once before fitting/smoothing.";
 end
 if isfield(verification,'fwaPreparation')&&isstruct(verification.fwaPreparation)&&isfield(verification.fwaPreparation,'white')
  r.verificationPreparation=verification.fwaPreparation;
  r.summaryText=r.summaryText+newline+"Verification white reference: "+string(verification.fwaPreparation.white.source)+"; readings: "+string(verification.fwaPreparation.white.count)+".";
 end
end
end
function text=describe(label,s)
text=label+": Not reported";
if ~all(isfield(s,{'count','mean','p95','max'})),return;end
v=[s.count,s.mean,s.p95,s.max];if numel(v)~=4||any(~isfinite(v)),return;end
text=label+sprintf(': %d patches; ΔE00 mean %.3f, P95 %.3f, maximum %.3f.',v);
end
