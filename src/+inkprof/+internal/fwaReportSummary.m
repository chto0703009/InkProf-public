function r=fwaReportSummary(fit,verification,printing,profileHash)
% Report actual processing evidence, never infer application from a UI choice.
r=struct('applied',[],'status',"Ej dokumenterat",'projectChoice',false, ...
 'illuminant',"Ej dokumenterat",'profileSHA256',string(profileHash), ...
 'trainingResult',struct,'verificationResult',struct, ...
 'effectComparedWithUncompensated',"Ej utvärderad. Ingen kontrollerad jämförelse med en motsvarande profil utan FWA redovisas. Dessa resultat visar inte i sig om FWA förbättrade återgivningen.");
r.projectChoice=isfield(printing,'fwaCompensation')&&isequal(printing.fwaCompensation,true);
if isfield(fit,'colorimetry')&&isfield(fit.colorimetry,'fwaCompensation')
 r.applied=logical(fit.colorimetry.fwaCompensation);
 if r.applied
  r.status="Ja - FWA/OBA-kompensation användes";
  if isfield(fit.colorimetry,'fwaIlluminant'),r.illuminant=string(fit.colorimetry.fwaIlluminant);end
 else
  r.status="Nej - ingen FWA/OBA-kompensation användes";r.illuminant="Ej tillämpligt";
 end
end
if ~isempty(r.applied)&&isfield(verification,'colorimetry')&&isfield(verification.colorimetry,'fwaCompensation')
 assert(r.applied==logical(verification.colorimetry.fwaCompensation),'inkprof:FinalReport', ...
  'Profile and verification use different FWA settings. Repeat verification before exporting.');
end
if isfield(fit,'summary'),r.trainingResult=fit.summary;end
if isfield(verification,'summary'),r.verificationResult=verification.summary;end
choice="Nej";if r.projectChoice,choice="Ja";end
r.summaryText="Använd i den levererade profilen: "+r.status+newline+ ...
 "Projektets sparade FWA-val: "+choice+newline+ ...
 "Simulerad belysning: "+r.illuminant+newline+ ...
 "Resultat för profilen med ovanstående inställning:"+newline+ ...
 describe("Träningsanpassning (inte oberoende verifiering)",r.trainingResult)+newline+ ...
 describe("Kontrollutskrift",r.verificationResult)+newline+ ...
 "FWA-effekt jämfört med utan kompensation: "+r.effectComparedWithUncompensated;
if ~isempty(r.applied)&&r.applied
 r.summaryText=r.summaryText+newline+"Kompensationen är en beräkning av simulerad D50-respons; råmätningen ometiketteras inte till uppmätt M1.";
end
end
function text=describe(label,s)
text=label+": Ej redovisat";
if ~all(isfield(s,{'count','mean','p95','max'})),return;end
v=[s.count,s.mean,s.p95,s.max];if numel(v)~=4||any(~isfinite(v)),return;end
text=label+sprintf(': %d patchar; ΔE00 medel %.3f, P95 %.3f, maximum %.3f.',v);
end
