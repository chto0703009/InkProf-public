% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function r=certificatePatchOutliers(c3)
% Use a disclosed ISO-related reference, not an ISO compliance decision.
r=struct('threshold',5,'metric',"CIEDE2000",'isoCompliance',"not-assessed", ...
 'title',"Patches above the ISO-related comparison threshold", ...
 'basis',"Delta E00 > 5.000 between measured and desired D50 Lab. Reference to the maximum limit for all Fogra MediaWedge fields under ISO 12647-7:2016; selection before rounding, not ISO approval of the InkProf target. Other ISO criteria are not assessed here. Unique colour, grey and challenge patches are included; repeats and the paper-white FWA reference are excluded.", ...
 'sourceDescription',"Bundesverband Druck und Medien (bvdm), the German printing and media federation, publishes MediaStandard Print. ISO means International Organization for Standardization. The industry publication summarises requirements and does not replace the ISO standard.", ...
 'source',"https://www.medienverbaende.de/fileadmin/user_upload/01_Global/Downloads_PDF_DOC/Downloads_Technik/MediaStandard_Print_2018.pdf", ...
 'colourNote',"Swatches show desired, predicted and measured D50 Lab converted to sRGB using Bradford adaptation to D65. * indicates sRGB clipping. Colours are previews; Delta E00 is calculated from Lab, not sRGB.", ...
 'available',false,'evaluatedCount',0,'count',0,'patches',struct([]),'message',"Per-patch verification results unavailable; exceedances cannot be assessed.");
r.contextText="Reachability evidence unavailable.";
r.overviewText="No measured print results available.";
r.distribution=struct([]);
r.allPatches=struct([]);
if ~isfield(c3,'patches')||isempty(c3.patches),return;end
patches=c3.patches;if iscell(patches),patches=[patches{:}];end
context=["This target includes difficult colours and may include colours the ICC model cannot reproduce. Large desired-colour errors alone do not establish that the profile is poor."; ...
 "Model-reachable is a numerical inverse result, not proof of physical print reachability. Outside-or-inversion-unresolved means outside the model or an unresolved inversion; it is not confirmed outside the physical gamut."; ...
 "Convergence means the numerical stopping criterion was met. It does not prove printer-gamut coverage or print accuracy. Review measured print vs profile prediction and model-reachable colours separately."];
for category=["model-reachable","outside-or-inversion-unresolved","unknown"]
 values=[];
 for q=reshape(patches,1,[])
  if any(string(q.role)==["repeat","paperwhite"]),continue;end
  assessment="unknown";if isfield(q,'gamutAssessment'),assessment=string(q.gamutAssessment);end
  if assessment==category,values(end+1)=q.deltaE00;end
 end
 if ~isempty(values),v=sort(values);context(end+1)=sprintf('%s: %d unique patches; measured print vs desired colour mean %.1f, P95 %.1f dE00.',category,numel(v),mean(v),v(max(1,ceil(.95*numel(v)))));end
end
r.contextText=join(context,newline);
unique=patches(~ismember(string({patches.role}),["repeat","paperwhite"]));
values=[unique.deltaE00];
if ~isempty(values)
 edges=[0 1 2 5 Inf];labels=["0–1","Above 1–2","Above 2–5","Above 5"];
 overview=["Whole verification target: all unique colours, grays and challenge colours. Repeats and paper-white references excluded."; ...
 "Measured print vs desired colour: descriptive error ranges, not contractual acceptance limits. This deliberately demanding target is not a representative sample of everyday photographs."];
 for k=1:4
  if k==1,n=sum(values<=edges(k+1));else,n=sum(values>edges(k)&values<=edges(k+1));end
  entry=struct('range',labels(k),'count',n,'percent',100*n/numel(values));
  if isempty(r.distribution),r.distribution=entry;else,r.distribution(end+1)=entry;end
  overview(end+1)=sprintf('dE00 %s: %d of %d colours (%.1f%%).',labels(k),n,numel(values),entry.percent);
 end
 overview(end+1)="The diagnostic colour cards below show only errors above 5; they do not show the distribution of the whole result. Neither numerical convergence nor an attractive photograph establishes measured accuracy.";
 r.overviewText=join(overview,newline);
end
for p=reshape(patches,1,[])
 if any(string(p.role)==["repeat","paperwhite"]),continue;end
 assert(any(string(p.role)==["colour","gray","challenge"]),'inkprof:FinalReport','Unknown verification patch role.');
 assert(isscalar(p.deltaE00)&&isfinite(p.deltaE00)&&p.deltaE00>=0,'inkprof:FinalReport','Invalid patch error.');
 r.evaluatedCount=r.evaluatedCount+1;
 [rgb,clipped]=inkprof.internal.labD50ToSRGB(double(p.measuredLab(:)'));
 rgb8=round(255*rgb);hex=string(sprintf('#%02X%02X%02X',rgb8));
 entry=struct('sampleId',string(p.sampleId),'coordinate',string(p.coordinate),'page',p.page, ...
  'role',string(p.role),'deltaE00',p.deltaE00,'excess',p.deltaE00-r.threshold, ...
  'measuredLab',p.measuredLab,'sRGB8',rgb8,'hex',hex,'clipped',clipped);
 entry.referenceName="";if isfield(p,'referenceName')&&~isempty(p.referenceName),entry.referenceName=string(p.referenceName);end
 entry.gamutAssessment="unknown";if isfield(p,'gamutAssessment'),entry.gamutAssessment=string(p.gamutAssessment);end
 entry.reachabilityLabel="Reachability unknown";
 if entry.gamutAssessment=="model-reachable",entry.reachabilityLabel="Model-reachable (numerical)";end
 if entry.gamutAssessment=="outside-or-inversion-unresolved",entry.reachabilityLabel="Outside model or inversion unresolved";end
 if entry.role=="challenge",entry.reachabilityLabel="Challenge colour; "+entry.reachabilityLabel;end
 entry.predictedDeltaE00=[];if isfield(p,'predictedDeltaE00'),entry.predictedDeltaE00=p.predictedDeltaE00;end
 for key=["desired","predicted"]
  labKey=key+"Lab";entry.(labKey)=[];entry.(key+"Hex")="";entry.(key+"Clipped")=false;
  if isfield(p,labKey)&&~isempty(p.(labKey))
   entry.(labKey)=p.(labKey);
   [preview,clip]=inkprof.internal.labD50ToSRGB(double(p.(labKey)(:)'));
   entry.(key+"Hex")=string(sprintf('#%02X%02X%02X',round(255*preview)));entry.(key+"Clipped")=clip;
  end
 end
 if isempty(r.allPatches),r.allPatches=entry;else,r.allPatches(end+1)=entry;end
 if p.deltaE00<=r.threshold,continue;end
 if isempty(r.patches),r.patches=entry;else,r.patches(end+1)=entry;end
end
r.available=r.evaluatedCount>0;r.count=numel(r.patches);
if r.available
 r.message=sprintf('%d of %d unique verification patches above the threshold. Largest deviations first.',r.count,r.evaluatedCount);
 if r.count==0,r.message="No unique verification patches exceed the comparison threshold Delta E00 5.000. This alone does not establish ISO conformity.";end
end
if r.count>0,[~,order]=sort([r.patches.deltaE00],'descend');r.patches=r.patches(order);end
end
