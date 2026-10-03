function paths=writeNumericalReport(w,profile,folder,notes)
% Separate evidence scope: never borrow C3 or approval from an older cycle.
assert(w.valid('checks'),'inkprof:WorkflowBlocked','Current numerical checks are required.');
project=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
digest=inkprof.internal.sha256(profile);
assert(digest==inkprof.internal.sha256(w.output('profile','profile')),'inkprof:Integrity','ICC copy changed.');
user=string(java.lang.System.getProperty('user.name'));if isfield(project,'user'),user=string(project.user);end
r=struct('schemaVersion',1,'documentType',"inkprof.numerical-report", ...
 'status',"numerically-checked-not-separately-print-verified", ...
 'scopeStatement',"Numeriskt kontrollerad; denna iteration är inte verifierad genom separat utskrift och mätning.", ...
 'createdUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
 'reportDate',string(datetime('now','Format','yyyy-MM-dd')),'reportUser',user, ...
 'pageHeader',"InkProf Quality Profiling RGB printer",'project',struct('id',project.projectId,'name',project.name), ...
 'iteration',w.State.cycle,'iterationId',w.State.iterationId,'printing',project.printing, ...
 'profile',struct('file',"profile.icc",'sha256',digest), ...
 'verification',struct('separatePrintVerified',false,'isoCertification',false), ...
 'decision',struct('confirmed',true,'notes',notes,'user',user,'meaning',"Use current ICC without claiming separate print verification"),'sources',struct);
r.shadow=inkprof.internal.shadowReportSummary(w);
r.documentTitle="InkProf - mätcertifikat";
r.certificateId=string(java.util.UUID.randomUUID());
r.certificateScope="Mätcertifikatet dokumenterar profilunderlag, numeriska kontroller och användarens beslut. Omfattningen för aktuell iteration anges nedan. Dokumentet är inte en ackrediterad certifiering eller ett intyg om ISO-överensstämmelse.";
r.signature=struct('status',"unsigned",'method',"handwritten on printed PDF");
r.historicalCertificate=inkprof.internal.previousCertificate(w,folder);
fit=jsondecode(fileread(w.output('checks','fit')));
r.fwa=inkprof.internal.fwaReportSummary(fit,struct,project.printing,digest);
r.legalAppendix=inkprof.internal.reportLegalText();
r.standardsReference=inkprof.internal.certificateStandards();
for key=["fit","grid","c1"]
 src=w.output('checks',key);check=jsondecode(fileread(src));
 if isfield(check,'profileSHA256')
  assert(string(check.profileSHA256)==digest,'inkprof:Integrity','Numerical check refers to another ICC.');
 end
 name="checks-"+key+".json";copyfile(src,fullfile(folder,name));
 r.sources.(key)=struct('file',name,'sha256',inkprof.internal.sha256(src));
end
if w.valid('compare')
 src=w.output('compare','comparison');copyfile(src,fullfile(folder,'comparison.json'));
 r.sources.comparison=struct('file',"comparison.json",'sha256',inkprof.internal.sha256(src));
 r.visualization=struct('source',"comparison.json",'defaultView',"2d",'defaultLightness',50,'halfWidth',5, ...
  'pdfView',"3d",'scope',"Predicted shared RGB samples in CIELAB D50, not measured gamut boundaries");
end
r.decisionEvidence=inkprof.internal.numericalDecisionEvidence(w,folder,digest);
copyfile(fullfile(w.Root,'workflow.json'),fullfile(folder,'workflow-snapshot.json'));
copyfile(fullfile(w.Root,'inkprof-project.json'),fullfile(folder,'project-snapshot.json'));
paths=struct('json',fullfile(folder,'final-report.json'),'html',fullfile(folder,'final-report.html'), ...
 'pdf',fullfile(folder,'final-report.pdf'),'text',fullfile(folder,'final-report.txt'));
r.gamut=inkprof.internal.reportGamut(profile,folder);
inkprof.internal.writeJson(paths.json,r);
config=inkprof.paths();inkprof.runPython(fullfile(config.Root,'analysis','numerical_report.py'),string(folder),RequiredModules="reportlab",WorkingDirectory=config.Root);
end
