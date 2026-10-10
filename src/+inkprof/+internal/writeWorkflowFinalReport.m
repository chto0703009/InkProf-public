% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function paths=writeWorkflowFinalReport(w,profile,folder,options)
arguments
 w
 profile (1,1) string
 folder (1,1) string
 options.User (1,1) string = string(java.lang.System.getProperty('user.name'))
end
% Save a portable human report and structured evidence after the ICC is saved.
assert(isfile(profile),'inkprof:FinalReport','Spara ICC-profilen innan mätcertifikatet skapas.');
assert(strlength(strtrim(options.User))>0&&strlength(options.User)<=120,'inkprof:FinalReport','Ange rapportens användare (1-120 tecken).');
project=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
external=w.mode()=="verification";
source=w.output('profile','profile');digest=inkprof.internal.sha256(profile);
assert(digest==inkprof.internal.sha256(source),'inkprof:Integrity','Sparad ICC skiljer sig från vald kandidat.');
approval=jsondecode(fileread(w.output('approve','approval')));
assert(string(approval.profileSHA256)==digest&&string(approval.reportSHA256)==inkprof.internal.sha256(w.output('c3','report')), ...
 'inkprof:FinalReport','Godkännandet gäller en annan ICC eller C3-rapport.');
r=struct('schemaVersion',1,'documentType',"inkprof.final-report",'status',"icc-saved", ...
 'createdUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
 'pageHeader',"InkProf Quality Profiling RGB printer",'reportDate',string(datetime('now','Format','yyyy-MM-dd')),'reportUser',options.User, ...
 'project',struct('id',project.projectId,'name',project.name),'iteration',w.State.cycle, ...
 'iterationId',w.State.iterationId,'parentIterationId',w.State.parentIterationId, ...
 'profile',struct('file',"profile.icc",'projectPath',w.relative(profile),'sha256',digest,'byteIdentical',true), ...
 'printing',struct('performedOutsideApp',true,'verifiedByApp',false,'reportedSettings',project.printing), ...
 'approval',approval,'sources',struct,'results',struct,'history',{w.State.history});
r.language="en";
r.documentTitle="InkProf - Measurement certificate";
if external
 r.workflowMode="verification";
 r.results.checks_fit=struct('status',"Not assessed: original training data unavailable");
 r.results.checks_grid=struct('status',"Not performed in existing-profile verification");
 r.results.checks_c1=struct('status',"Not performed in existing-profile verification");
 r.results.measurement_measurement=struct('status',"Original training measurements unavailable");
end
r.standardsReference=inkprof.internal.certificateStandards();
r.certificateId=string(java.util.UUID.randomUUID());
r.certificateScope="This measurement certificate records saved measurement results and the user assessment for the specified ICC profile and project configuration. It is not accredited certification or a declaration of ISO conformity.";
r.certificateScope=r.certificateScope+inkprof.internal.certificateAcceptanceContext();
if external
 r.certificateScope="Verification of an imported ICC profile against a new verification print. The original profile has not been rebuilt. Original training data are unavailable, so independence of the verification patches from those data cannot be established. Results apply to the documented print and measurement; no automatic ISO certification.";
end
r.resultInterpretation="Here, model means the ICC profile's mathematical description of the relationship between printer device RGB and expected printed colour in Lab. It is built from profiling measurements using fitted curves and lookup tables, with interpolation and smoothing. Its forward direction predicts colour from RGB; its inverse direction selects RGB for a desired colour, subject to the profile and printer limitations. A model prediction is a calculation, not a new physical measurement. An imported profile may have been built by another tool, and its original training data may be unavailable. The primary result, Measured print vs desired colour, compares the measured C2 print with its desired absolute D50 Lab colours. The selected ICC was applied once when generating the target; printing must preserve those device RGB values. This assesses the documented combination of ICC profile, printer, ink, paper and print settings, rather than the profile alone. B3 profile fit compares profile predictions with profiling measurements and answers how well the model describes those data; a small fit error does not establish accuracy of a new print. Measured print vs current profile prediction is a separate diagnostic. The whole-target overview includes all unique measured colours, with larger deviations shown separately for investigation. Results represent this target, which can include deliberately difficult colours, and are not a universal score for photographs. Desired colours beyond the printer's reproducible gamut cannot be matched exactly. Model-based reachability is an estimate, not proof of the physical gamut; where evidence is unavailable, the cause of an error remains unclassified. With numerical checks only, no measured-print accuracy is established for the current profile.";
r.reproductionLimits="ICC results depend on the physical capabilities of the printer, paper and ink combination. Paper white, surface and optical brighteners, ink properties and printer/driver settings limit gamut, black level, contrast and tonal reproduction. An ICC profile describes this combination; it cannot create colours or contrast beyond the capabilities of the materials and equipment. Out-of-gamut colours require mapping. More measurements or further iterations do not guarantee improvement. Print stability, drying time, measurement conditions and viewing light also affect deviations. Results apply to the documented conditions; changes may require new profiling and verification.";
legal=inkprof.internal.reportLegalText("en");
r.reproductionLiability=legal.reproductionLiability;
r.clientPrintResponsibility=legal.clientPrintResponsibility;
r.licensingNotice=legal.licensingNotice;
r.signature=struct('status',"unsigned",'method',"handwritten on printed PDF", ...
 'statement',"By signing, I confirm that I have reviewed this measurement certificate and its stated conditions, results, limitations and allocation of responsibilities.");
r.projectDetails=struct('label',{},'value',{});
addDetail("Project",project.name);addDetail("Project ID",project.projectId);
addDetail("Document date",r.reportDate);addDetail("Prepared by",r.reportUser);
if isfield(project,'user'),addDetail("Project owner",project.user);end
if isfield(project,'createdUTC'),addDetail("Project created (UTC)",project.createdUTC);end
labels={"printer","Printer";"paper","Paper";"paperSurface","Paper surface";"ink","Ink / ink set";"inkType","Ink type (dye / pigment)"; ...
 "shadowMode","Shadow mode (auto-matte applies only to matte paper)";"shadowPatchEmphasis","Dark patch weighting";"shadowGridEmphasis","Model shadow emphasis";"shadowExtraPatches","Extra shadow patches per iteration (requested count)"; ...
 "printerCoating","Printer coating";"coatingSettings","Coating - product and settings"; ...
 "media","Driver media selection";"driver","Driver / RIP";"quality","Print quality"; ...
 "printPath","Printing application";"colorManagement","Print colour management";"dryingHours","Drying time (hours)";"settings","Other printer settings"};
for k=1:size(labels,1)
 value="Not specified";if isfield(project.printing,labels{k,1}),value=project.printing.(labels{k,1});end
 addDetail(labels{k,2},value);
end
if external
 r.importedProfile=jsondecode(fileread(w.output('profile','job')));
 addDetail("Imported ICC - original filename",string(r.importedProfile.originalName));
 addDetail("Verification mode","External ICC; no new profile built");
end
r.shadow=inkprof.internal.shadowReportSummary(w);
r.regularization=inkprof.internal.regularizationReportSummary(w);
addDetail("Shadow setting in saved profile recipe",r.shadow.summaryText);
r.warrantyNotice=inkprof.internal.warrantyNotice("en");
% Copy the referenced reports alongside the ICC; links survive moving exports.
pairs={'checks','fit';'checks','grid';'checks','c1';'c3','report';'feedback','feedback'; ...
 'approve','approval';'measurement','measurement';'c2measurement','measurement';'profile','job'};
for k=1:size(pairs,1)
 step=pairs{k,1};key=pairs{k,2};
 if external&&any(string(step)==["checks","measurement"]),continue;end
 original=w.output(step,key);
 name=string(step)+"-"+key+".json";copyfile(original,fullfile(folder,name));
 id=matlab.lang.makeValidName(step+"_"+key);
 r.sources.(id)=struct('file',name,'projectPath',w.relative(original),'sha256',inkprof.internal.sha256(original));
 data=jsondecode(fileread(original));
 keep=["summary","groups","grayBalance","repeatedPrintedPatches","pairedScanQuality","roundtripDeltaE00", ...
  "grossFailureAlerts","allNegativeControlsDetected","recommendation","priorities","status","measurementCondition","measuredSourcePatches","colorimetry","limitations"];
 reduced=struct;
 for field=keep,if isfield(data,field),reduced.(field)=data.(field);end,end
 r.results.(id)=reduced;
end
% Keep profiling and verification instruments distinct, including legacy measurements.
r.instruments=struct;
stages=["measurement","c2measurement"];if external,stages="c2measurement";end
for stage=stages
 source=w.output(stage,'measurement');measurement=jsondecode(fileread(source));condition=struct;
 if isfield(measurement,'measurementCondition'),condition=measurement.measurementCondition;end
 identity=inkprof.internal.instrumentIdentity(fileparts(source),condition);
 identity.measurementSHA256=inkprof.internal.sha256(source);
 r.instruments.(stage)=identity;
 if stage=="measurement",label="Profiling measurement";else,label="Verification measurement";end
 addDetail(label+" – instrument",identity.model);
 addDetail(label+" - serial number",identity.serialNumber);
end
if isfield(w.State.steps.profile.outputs,'iteration')
 src=w.output('profile','iteration');copyfile(src,fullfile(folder,'iteration.json'));
 r.sources.iteration=struct('file',"iteration.json",'projectPath',w.relative(src),'sha256',inkprof.internal.sha256(src));
 iteration=jsondecode(fileread(src));
 for key=["selection","roles","parameters"]
  if isfield(iteration,key),r.results.iteration.(key)=iteration.(key);end
 end
end
paths=struct('pdf',fullfile(folder,'final-report.pdf'),'html',fullfile(folder,'final-report.html'),'json',fullfile(folder,'final-report.json'),'text',fullfile(folder,'final-report.txt'));
if isfield(w.State.steps.c2.outputs,'reference')
 reference=w.output('c2','reference');
 ref=jsondecode(fileread(reference));
 if isfield(ref,'referenceSet'),r.referenceTarget=ref.referenceSet;end
 if external,addDetail("Verification patch count including repeats",string(numel(ref.patches)));end
 assert(string(ref.printerProfile.sha256)==digest,'inkprof:FinalReport','3D-underlaget hör till en annan ICC.');
 f=inkprof.showVerificationLab(reference,Visible=false);
 cleanFigure=onCleanup(@()delete(f));
 exportgraphics(f,fullfile(folder,'profile-lab-3d.png'),'Resolution',160);
 animationData=struct('lab',f.UserData.lab,'rgb',f.UserData.previewRGB);clear cleanFigure
 copyfile(reference,fullfile(folder,'verification.json'));
 r.visualization=struct('file',"profile-lab-3d.png",'kind',"Predicted C2 patch Lab D50; not measured or full gamut", ...
  'reference',"verification.json",'referenceSHA256',inkprof.internal.sha256(reference));
end
c3=jsondecode(fileread(w.output('c3','report')));
r.patchOutliers=inkprof.internal.certificatePatchOutliers(c3);
if isfield(c3,'patches')&&~isempty(c3.patches)&&isfield(c3.patches,'measuredLab')
 measured=c3.patches(~ismember(string({c3.patches.role}),["repeat","paperwhite"]));
 lab=zeros(numel(measured),3);for k=1:numel(measured),lab(k,:)=double(measured(k).measuredLab(:)');end
 [rgb,~]=inkprof.internal.labD50ToSRGB(lab);
 r.measuredColours=struct('lab',lab,'rgb',rgb,'kind',"actual C3 measured colours",'sourceSHA256',inkprof.internal.sha256(w.output('c3','report')));
end

if isfield(c3,'patches')&&~isempty(c3.patches)&&isfield(c3.patches,'predictedDeltaE00')
unique=c3.patches(~ismember(string({c3.patches.role}),["repeat","paperwhite"]));
v=sort([unique.predictedDeltaE00]);
position=1+.95*(numel(v)-1);p95=v(floor(position))+(position-floor(position))*(v(ceil(position))-v(floor(position)));
r.metricLabels=struct('measuredDesired',"Measured print vs desired colour",'measuredPredicted',"Measured print vs current profile prediction");
r.verificationSummary=struct('desired',c3.summary,'predicted',struct('count',numel(v), ...
 'mean',mean(v),'median',median(v),'p95',p95,'max',max(v)));
end

r.fwa=inkprof.internal.fwaReportSummary(r.results.checks_fit,r.results.c3_report,project.printing,digest);
r.gamut=inkprof.internal.reportGamut(profile,folder);
inkprof.internal.writeJson(paths.json,r);
config=inkprof.paths();
inkprof.runPython(fullfile(config.Root,'analysis','lab_views.py'),string(folder),RequiredModules="reportlab",WorkingDirectory=config.Root);
lines=["INKPROF - MEASUREMENT CERTIFICATE";"Project: "+string(project.name);"Project ID: "+string(project.projectId);"Date: "+r.reportDate;"User: "+r.reportUser; ...
 "Iteration: "+w.State.cycle;"Iteration ID: "+w.State.iterationId;"Time UTC: "+r.createdUTC; ...
 "Certificate ID: "+r.certificateId;"";r.certificateScope;"";"How to interpret these results";r.resultInterpretation;"";"PROJECT AND PRINTING CONDITIONS"; ...
 string({r.projectDetails.label})'+": "+string({r.projectDetails.value})'; ...
 "";"Regularization - method, inputs and results";r.regularization.summaryText; ...
 "";"FWA/OBA - SETTINGS AND RESULTS";r.fwa.summaryText; ...
 "";"SAVED ICC";"File: profile.icc";"SHA-256: "+digest;"Byte-identical to the selected candidate."; ...
 "";"FINAL ASSESSMENT";string(approval.notes);""; ...
 "Whole-target result overview";r.patchOutliers.overviewText;"";"Technical diagnostic colours: deviations above 5 dE00";"Desired colour, profile prediction and measured colour are shown as sRGB previews. Delta E00 compares measurement with desired colour (above 5). See Appendix A.";r.patchOutliers.message;r.patchOutliers.contextText];
if isfield(r,'referenceTarget')
 lines=[lines;"";"REFERENCE TARGET: "+string(r.referenceTarget.name);"Measured print vs desired reference colour (Delta E00); unique patches, excluding repeats and paper white."];
 for patch=reshape(r.patchOutliers.allPatches,1,[])
  lines(end+1)=patch.referenceName+" | "+patch.sampleId+sprintf(' | Delta E00 %.4f',patch.deltaE00);
 end
end
fit=r.results.checks_fit;
if isfield(r,'verificationSummary')
for key=["desired","predicted"]
 label="Measured print vs desired colour";if key=="predicted",label="Measured print vs current profile prediction";end
 v=r.verificationSummary.(key);
 lines(end+1)=sprintf('%s: mean %.3f, median %.3f, P95 %.3f, max %.3f ΔE00 (%d unique patches).',label,v.mean,v.median,v.p95,v.max,v.count);
end
end
for patch=reshape(r.patchOutliers.patches,1,[])
 lines(end+1)=sprintf('Page %d / %s | ID %s | %s | sRGB %s | ΔE00 %.4f | above threshold %.4f',patch.page,patch.coordinate,patch.sampleId,patch.role+" | "+patch.reachabilityLabel,patch.hex,patch.deltaE00,patch.excess);
end
lines=[lines;"";string(r.standardsReference.en.title);string(r.standardsReference.en.caption)];
for k=1:size(r.standardsReference.en.rows,1)
 row=string(r.standardsReference.en.rows{k});lines(end+1)=row(1)+": "+row(2);
end
profileColorimetry=struct;if isfield(fit,'colorimetry'),profileColorimetry=fit.colorimetry;end
lines=[lines;"";"PRINTING AND MEASUREMENT"; ...
 "The app saves TIFF16. The user prints separately; the app runs instrument measurement."; ...
 "The print path has not been verified by the app. Undocumented conditions remain unknown."; ...
 "Reported project printing conditions: "+string(jsonencode(project.printing)); ...
 "FWA/OBA and profile computation conditions: "+string(jsonencode(profileColorimetry)); ...
 "Profiling measurement: "+string(jsonencode(r.results.measurement_measurement)); ...
 "Verification measurement: "+string(jsonencode(r.results.c2measurement_measurement)); ...
 "";"NUMERICAL CHECKS AND FEEDBACK"; ...
 "Grid: "+string(jsonencode(r.results.checks_grid));"C1: "+string(jsonencode(r.results.checks_c1)); ...
 "Feedback: "+string(jsonencode(r.results.feedback_feedback)); ...
 "";"ITERATION HISTORY (UTC)"];
h=w.State.history;if isstruct(h),h=num2cell(h);end
for k=1:numel(h)
 e=h{k};lines(end+1)=string(e.utc)+" | iteration "+e.cycle+" | "+string(e.step)+" | "+string(e.status);
end
lines=[lines;r.createdUTC+" | iteration "+w.State.cycle+" | ICC saved and measurement certificate created"; ...
 "";"EVIDENCE AND TRACEABILITY"];
for key=string(fieldnames(r.sources))'
 a=r.sources.(key);lines=[lines;string(a.file);"  Project: "+a.projectPath;"  SHA-256: "+a.sha256]; %#ok<AGROW>
end
lines=[lines;"";"Results describe the saved evidence. User approval is not ISO certification."; ...
 "Complete raw data and previous candidates remain in the project. The report JSON contains structured results and history."];
lines=[lines;"";"SIGNATURE";r.signature.statement;"Certificate ID: "+r.certificateId; ...
 "Place and date: __________________________________________"; ...
 "Signature: _____________________________________________"; ...
 "Printed name: _______________________________________"; ...
 "Organisation / role: ______________________________________"];
lines=[lines;"";string(r.standardsReference.en.appendixTitle);string(r.standardsReference.en.paragraphs);string(r.standardsReference.sourceURL);r.patchOutliers.basis;r.patchOutliers.colourNote;"";"PHYSICAL REPRODUCTION CAPABILITY AND RESULT LIMITATIONS";r.reproductionLimits];
lines=[lines;"";"APPENDIX B - LEGAL TERMS"; ...
 "RESPONSIBILITY FOR EQUIPMENT AND MATERIAL LIMITATIONS";r.reproductionLiability; ...
 "";"CLIENT PRINTS AND INFORMATION";r.clientPrintResponsibility; ...
 "";"WARRANTY AND LIABILITY";r.warrantyNotice;"";"LICENCES AND THIRD-PARTY RIGHTS";r.licensingNotice];
writeText(paths.text,strjoin(lines,newline));
projectHTML="<h2>Project and printing conditions</h2>";
for detail=r.projectDetails
 projectHTML=projectHTML+"<p><strong>"+esc(detail.label)+":</strong> "+esc(detail.value)+"</p>";
end
html="<!doctype html><html lang='en'><meta charset='utf-8'><meta name='viewport' content='width=device-width'><title>InkProf - Measurement certificate</title>"+ ...
 "<style>body{font:16px/1.5 system-ui,sans-serif;color:#19303c;max-width:1050px;margin:40px auto;padding:0 24px}h1{font-size:32px}h2{margin-top:32px}table{border-collapse:collapse;width:100%}th,td{border-bottom:1px solid #ccd8de;padding:9px;text-align:left}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f3f6f7;padding:20px}a{color:#146078}code{overflow-wrap:anywhere}@media print{body{margin:0;font-size:11px}tr{break-inside:avoid}}</style>"+ ...
 "<h1>InkProf - Measurement certificate</h1><p>"+esc(string(project.name))+" · Iteration "+w.State.cycle+" · "+esc(r.createdUTC)+"</p>"+ ...
 "<p>Iteration UUID: "+esc(string(r.iterationId))+"</p><p>Certificate ID: "+esc(r.certificateId)+"</p><p>"+esc(r.certificateScope)+"</p><h2>How to interpret these results</h2><p>"+esc(r.resultInterpretation)+"</p>"+projectHTML+ ...
 "<h2>Saved ICC profile</h2><p><a href='profile.icc'>profile.icc</a></p><p>SHA-256: <code>"+digest+"</code></p>"+ ...
 "<h2>Final assessment</h2><p>"+esc(string(approval.notes))+"</p><h2>Whole-target result overview</h2><p>"+replace(esc(r.patchOutliers.overviewText),newline,"<br>")+"</p><h2>Technical diagnostic colours: deviations above 5 dE00</h2>"+ ...
 "<p>Desired colour, profile prediction and measured colour are shown as sRGB previews. Delta E00 compares measurement with desired colour (above 5). See Appendix A.</p><p>"+esc(r.patchOutliers.message)+"</p>";
mosaic="<!--REFERENCE-TARGET--><h3>Every unique measured colour</h3><p>Target order; labels show patch ID and measured print vs desired colour dE00. Screen colours are sRGB previews.</p><div style='display:grid;grid-template-columns:repeat(8,1fr);gap:5px'>";
for patch=reshape(r.patchOutliers.allPatches,1,[])
 mosaic=mosaic+"<div><div style='height:25px;background:"+patch.hex+"'></div>"+esc(patch.sampleId)+sprintf(' · %.1f</div>',patch.deltaE00);
end
mosaic=mosaic+"</div>";
html=replace(html,"<h2>Technical diagnostic colours: deviations above 5 dE00</h2>",mosaic+"<h2>Technical diagnostic colours: deviations above 5 dE00</h2>");
html=html+"<h2>Regularization - method, inputs and results</h2><p>"+replace(esc(r.regularization.summaryText),newline,"<br>")+"</p>";
html=html+"<p>"+replace(esc(r.patchOutliers.contextText),newline,"<br>")+"</p>";
html=html+"<h3>Two separate comparisons (Delta E00)</h3>";
if isfield(r,'verificationSummary')
for key=["desired","predicted"]
 label="Measured print vs desired colour";if key=="predicted",label="Measured print vs current profile prediction";end
 v=r.verificationSummary.(key);
 html=html+"<p>"+esc(label)+sprintf(': mean %.3f · median %.3f · P95 %.3f · max %.3f (%d unique patches)</p>',v.mean,v.median,v.p95,v.max,v.count);
end
end
for k=1:3:r.patchOutliers.count
 html=html+"<div class='patch-row' style='display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-bottom:8px;font-size:9pt'>";
 for j=k:min(k+2,r.patchOutliers.count)
  patch=r.patchOutliers.patches(j);mark="";if patch.clipped,mark="*";end
  chips="<div style='display:flex;gap:3px'>";
  for field=["desiredHex","predictedHex","hex"]
   label="Measured";if field=="desiredHex",label="Desired";elseif field=="predictedHex",label="Predicted";end
   color=string(patch.(field));if color=="",color="transparent";label=label+" (unavailable)";end
   chips=chips+"<div style='flex:1'><span style='display:block;height:40px;border:1px solid #777;background:"+color+";print-color-adjust:exact;-webkit-print-color-adjust:exact'></span>"+label+"</div>";
  end
  html=html+"<div style='border:1px solid #ccd8de;padding:6px;overflow-wrap:anywhere'>"+chips+"</div>"+ ...
   "<br><strong>"+esc("ID "+patch.sampleId)+"</strong> · "+esc("page "+patch.page+" / "+patch.coordinate)+ ...
   "<br>"+esc(patch.role)+"<br>"+esc(patch.reachabilityLabel)+"<br>Measured print vs desired colour · ΔE00 <strong>"+compose('%.4f',patch.deltaE00)+"</strong></div>";
 end
 html=html+"</div>";
end
html=html+inkprof.internal.certificateStandardsHTML(r.standardsReference,"table")+ ...
 "<h2>FWA/OBA - settings and results</h2><p>"+replace(esc(r.fwa.summaryText),newline,"<br>")+"</p>"+ ...
 "<h2>Evidence</h2><ul><li><a href='final-report.json'>Structured measurement certificate (JSON)</a></li><li><a href='final-report.txt'>Measurement certificate as text</a></li>";
for key=string(fieldnames(r.sources))'
 name=r.sources.(key).file;html=html+"<li><a href='"+esc(name)+"'>"+esc(name)+"</a></li>";
end
html=html+"<li><a href='final-report.pdf'>Measurement certificate as PDF</a></li></ul>";
html=html+string(fileread(fullfile(folder,'measured-colours.html')));
if string(r.gamut.status)=="available"
 html=html+string(fileread(fullfile(folder,'gamut-view.html')));
else
 html=html+"<section><h2>ICC gamut</h2><p>Gamut unavailable: "+esc(string(r.gamut.reason))+"</p></section>";
end
signatureStart=find(lines=="SIGNATURE",1,'last');
% The visual results already appear above; keep their text equivalent in TXT only.
resultStart=find(lines=="Whole-target result overview",1);
resultEnd=find(lines=="PRINTING AND MEASUREMENT",1);
appendixLines=[lines(1:resultStart-1);lines(resultEnd:signatureStart-1)];
html=html+"<h2>Complete results and history</h2><pre>"+esc(strjoin(appendixLines,newline))+"</pre>"+ ...
 "<section class='certificate-signature' style='height:225mm;display:flex;flex-direction:column;break-inside:avoid'><h2>Measurement certificate signature</h2>"+ ...
 "<p>Project: "+esc(string(project.name))+"</p><p>Certificate ID: "+esc(r.certificateId)+"</p><p>Document date: "+esc(r.reportDate)+"</p>"+ ...
 "<p>ICC SHA-256: "+digest+"</p><div style='margin-top:auto'><p>"+esc(r.signature.statement)+"</p>"+ ...
 "<p style='margin-top:15mm'>Place and date: __________________________________________</p>"+ ...
 "<p style='margin-top:15mm'>Signature: _____________________________________________</p>"+ ...
 "<p style='margin-top:15mm'>Printed name: _______________________________________</p>"+ ...
 "<p style='margin-top:15mm'>Organisation / role: ______________________________________</p></div></section>"+ ...
 replace(inkprof.internal.certificateStandardsHTML(r.standardsReference,"appendix"),"</section>","<p>"+esc(r.patchOutliers.basis)+"</p><p>"+esc(r.patchOutliers.colourNote)+"</p><h3>Physical reproduction capability and result limitations</h3><p>"+esc(r.reproductionLimits)+"</p></section>")+ ...
 "<section class='legal-appendix' style='break-before:page'><h2>Appendix B - Legal terms</h2>"+ ...
 "<h3>Responsibility for equipment and material limitations</h3><p>"+esc(r.reproductionLiability)+"</p>"+ ...
 "<h3>Client prints and information</h3><p>"+esc(r.clientPrintResponsibility)+"</p>"+ ...
 "<h3>Warranty and liability</h3><p>"+esc(r.warrantyNotice)+"</p><h3>Licences and third-party rights</h3><p>"+esc(r.licensingNotice)+"</p></section></html>";
config=inkprof.paths();
furniture=struct('header',r.pageHeader,'date',r.reportDate,'user',r.reportUser);
pages=string(fileread(fullfile(config.Root,'resources','workflow-report-pages.html')));
metadata=string(jsonencode(furniture));metadata=replace(metadata,"<",string(char(92))+"u003c");
pages=replace(pages,"__REPORT_FURNITURE__",metadata);
animation=string(fileread(fullfile(config.Root,'resources','workflow-report-3d.html')));
html=replace(html,"</html>",pages+animation+"</html>");
writeText(paths.html,html);
inkprof.runPython(fullfile(config.Root,'analysis','workflow_final_pdf.py'),string(folder),RequiredModules="reportlab",WorkingDirectory=config.Root);
    function addDetail(label,value)
        value=strtrim(string(value));if isempty(value)||strlength(value)==0||value=="unknown",value="Not specified";end
        r.projectDetails(end+1)=struct('label',string(label),'value',value);
    end

end
function text=esc(text)
text=replace(string(text),["&","<",">",string(char(34)),"'"],["&amp;","&lt;","&gt;","&quot;","&#39;"]);
end
function writeText(file,text)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0,'inkprof:IO','Kan inte spara mätcertifikatet.');
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',text);
end
