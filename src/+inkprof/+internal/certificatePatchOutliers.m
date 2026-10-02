function r=certificatePatchOutliers(c3)
% Use a disclosed ISO-related reference, not an ISO compliance decision.
r=struct('threshold',5,'metric',"CIEDE2000",'isoCompliance',"not-assessed", ...
 'title',"Patchar över ISO-relaterad jämförelsegräns", ...
 'basis',"ΔE00 > 5,000 mellan uppmätt och önskat D50-Lab. Jämförelse med maxgränsen för samtliga fält i Fogra MediaWedge enligt ISO 12647-7:2016, urval före avrundning; inte ett ISO-godkännande av InkProfs kontrollmål. Övriga ISO-kriterier bedöms inte här. Unika färg-, grå- och challenge-patchar ingår; upprepningar och pappersvit FWA-referens utesluts.", ...
 'sourceDescription',"Bundesverband Druck und Medien (bvdm), Tysklands tryck- och medieförbund, är utgivare av MediaStandard Print. ISO står för International Organization for Standardization (Internationella standardiseringsorganisationen). Branschpublikationen sammanfattar standardkrav och ersätter inte ISO-standarden.", ...
 'source',"https://www.medienverbaende.de/fileadmin/user_upload/01_Global/Downloads_PDF_DOC/Downloads_Technik/MediaStandard_Print_2018.pdf", ...
 'colourNote',"Färgprovet visar uppmätt D50-Lab omräknat till sRGB med Bradford-anpassning till D65. * anger klippning till sRGB. Färgen är en visuell förhandsvisning; ΔE00 beräknas från Lab, inte från sRGB.", ...
 'available',false,'evaluatedCount',0,'count',0,'patches',struct([]),'message',"Patchvisa kontrollresultat saknas; överskridanden kan inte bedömas.");
if ~isfield(c3,'patches')||isempty(c3.patches),return;end
patches=c3.patches;if iscell(patches),patches=[patches{:}];end
for p=reshape(patches,1,[])
 if any(string(p.role)==["repeat","paperwhite"]),continue;end
 assert(any(string(p.role)==["colour","gray","challenge"]),'inkprof:FinalReport','Unknown verification patch role.');
 assert(isscalar(p.deltaE00)&&isfinite(p.deltaE00)&&p.deltaE00>=0,'inkprof:FinalReport','Invalid patch error.');
 r.evaluatedCount=r.evaluatedCount+1;
 if p.deltaE00<=r.threshold,continue;end
 [rgb,clipped]=inkprof.internal.labD50ToSRGB(double(p.measuredLab(:)'));
 rgb8=round(255*rgb);hex=string(sprintf('#%02X%02X%02X',rgb8));
 entry=struct('sampleId',string(p.sampleId),'coordinate',string(p.coordinate),'page',p.page, ...
  'role',string(p.role),'deltaE00',p.deltaE00,'excess',p.deltaE00-r.threshold, ...
  'measuredLab',p.measuredLab,'sRGB8',rgb8,'hex',hex,'clipped',clipped);
 if isempty(r.patches),r.patches=entry;else,r.patches(end+1)=entry;end
end
r.available=r.evaluatedCount>0;r.count=numel(r.patches);
if r.available
 r.message=sprintf('%d av %d unika kontrollpatchar över gränsen. Största avvikelsen först.',r.count,r.evaluatedCount);
 if r.count==0,r.message="Inga unika kontrollpatchar överskrider jämförelsegränsen ΔE00 5,000. Detta innebär inte i sig ISO-överensstämmelse.";end
end
if r.count>0,[~,order]=sort([r.patches.deltaE00],'descend');r.patches=r.patches(order);end
end
