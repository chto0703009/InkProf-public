function paths=writeWorkflowFinalReport(w,profile,folder,options)
arguments
 w
 profile (1,1) string
 folder (1,1) string
 options.User (1,1) string = string(java.lang.System.getProperty('user.name'))
end
% Save a portable human report and structured evidence after the ICC is saved.
assert(isfile(profile),'inkprof:FinalReport','Spara ICC-profilen innan slutrapporten skapas.');
assert(strlength(strtrim(options.User))>0&&strlength(options.User)<=120,'inkprof:FinalReport','Ange rapportens användare (1-120 tecken).');
project=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
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
% Copy the referenced reports alongside the ICC; links survive moving exports.
pairs={'checks','fit';'checks','grid';'checks','c1';'c3','report';'feedback','feedback'; ...
 'approve','approval';'measurement','measurement';'c2measurement','measurement';'profile','job'};
for k=1:size(pairs,1)
 step=pairs{k,1};key=pairs{k,2};original=w.output(step,key);
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
 assert(string(ref.printerProfile.sha256)==digest,'inkprof:FinalReport','3D-underlaget hör till en annan ICC.');
 f=inkprof.showVerificationLab(reference,Visible=false);
 cleanFigure=onCleanup(@()delete(f));
 exportgraphics(f,fullfile(folder,'profile-lab-3d.png'),'Resolution',160);clear cleanFigure
 copyfile(reference,fullfile(folder,'verification.json'));
 r.visualization=struct('file',"profile-lab-3d.png",'kind',"Predicted C2 patch Lab D50; not measured or full gamut", ...
  'reference',"verification.json",'referenceSHA256',inkprof.internal.sha256(reference));
end
inkprof.internal.writeJson(paths.json,r);
lines=["INKPROF – SLUTRAPPORT";"Projekt: "+string(project.name);"Projekt-ID: "+string(project.projectId);"Datum: "+r.reportDate;"Användare: "+r.reportUser; ...
 "Iteration: "+w.State.cycle;"Iterations-ID: "+w.State.iterationId;"Tid UTC: "+r.createdUTC; ...
 "";"SPARAD ICC";"Fil: profile.icc";"SHA-256: "+digest;"Byte-identisk med vald kandidat."; ...
 "";"SLUTLIG BEDÖMNING";string(approval.notes);""; ...
 "MÄTRESULTAT – ΔE00";"Grupp | Antal | Medel | Median | P95 | Maximum"];
rows=cell(0,6);
c3=r.results.c3_report;fit=r.results.checks_fit;
if isfield(c3,'summary'),addStats("C3: unika kontrollpatchar",c3.summary);end
if isfield(c3,'groups')
 for pair={'gray','C3: gråskala';'colour','C3: färgprov';'challenge','C3: challenge'}'
  if isfield(c3.groups,pair{1}),addStats(string(pair{2}),c3.groups.(pair{1}));end
 end
end
if isfield(c3,'repeatedPrintedPatches')&&isfield(c3.repeatedPrintedPatches,'summary')
 addStats("Separata upprepade utskriftsfält",c3.repeatedPrintedPatches.summary);
end
if isfield(fit,'summary'),addStats("Träningsdata (inte oberoende kontroll)",fit.summary);end
for k=1:size(rows,1),lines(end+1)=strjoin(string(rows(k,:))," | ");end
lines=[lines;"";"UTSKRIFT OCH MÄTNING"; ...
 "Appen sparar TIFF16. Användaren skriver ut separat; appen genomför instrumentmätningen."; ...
 "Utskriftskedjan har inte verifierats av appen. Ej dokumenterade villkor förblir okända."; ...
 "Projektets rapporterade utskriftsvillkor: "+string(jsonencode(project.printing)); ...
 "Profileringsmätning: "+string(jsonencode(r.results.measurement_measurement)); ...
 "Kontrollmätning: "+string(jsonencode(r.results.c2measurement_measurement)); ...
 "";"NUMERISKA KONTROLLER OCH ÅTERKOPPLING"; ...
 "Grid: "+string(jsonencode(r.results.checks_grid));"C1: "+string(jsonencode(r.results.checks_c1)); ...
 "Återkoppling: "+string(jsonencode(r.results.feedback_feedback)); ...
 "";"ITERATIONSHISTORIK (UTC)"];
h=w.State.history;if isstruct(h),h=num2cell(h);end
for k=1:numel(h)
 e=h{k};lines(end+1)=string(e.utc)+" | iteration "+e.cycle+" | "+string(e.step)+" | "+string(e.status);
end
lines=[lines;r.createdUTC+" | iteration "+w.State.cycle+" | ICC sparad och slutrapport skapad"; ...
 "";"UNDERLAG OCH SPÅRBARHET"];
for key=string(fieldnames(r.sources))'
 a=r.sources.(key);lines=[lines;string(a.file);"  Projekt: "+a.projectPath;"  SHA-256: "+a.sha256]; %#ok<AGROW>
end
lines=[lines;"";"Resultaten beskriver det sparade underlaget. Användarens godkännande är inte ISO-certifiering."; ...
 "Kompletta rådata och äldre kandidater bevaras i projektet. Rapportens JSON innehåller strukturerade resultat och historik."];
writeText(paths.text,strjoin(lines,newline));
html="<!doctype html><html lang='sv'><meta charset='utf-8'><meta name='viewport' content='width=device-width'><title>InkProf – slutrapport</title>"+ ...
 "<style>body{font:16px/1.5 system-ui,sans-serif;color:#19303c;max-width:1050px;margin:40px auto;padding:0 24px}h1{font-size:32px}h2{margin-top:32px}table{border-collapse:collapse;width:100%}th,td{border-bottom:1px solid #ccd8de;padding:9px;text-align:left}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f3f6f7;padding:20px}a{color:#146078}code{overflow-wrap:anywhere}@media print{body{margin:0;font-size:11px}tr{break-inside:avoid}}</style>"+ ...
 "<h1>InkProf – slutrapport</h1><p>"+esc(string(project.name))+" · Iteration "+w.State.cycle+" · "+esc(r.createdUTC)+"</p>"+ ...
 "<h2>Sparad ICC-profil</h2><p><a href='profile.icc'>profile.icc</a></p><p>SHA-256: <code>"+digest+"</code></p>"+ ...
 "<h2>Slutlig bedömning</h2><p>"+esc(string(approval.notes))+"</p><h2>Mätresultat – ΔE00</h2>"+ ...
 "<table><tr><th>Grupp</th><th>Antal</th><th>Medel</th><th>Median</th><th>P95</th><th>Maximum</th></tr>";
for k=1:size(rows,1)
 html=html+"<tr>";for j=1:6,html=html+"<td>"+esc(string(rows{k,j}))+"</td>";end;html=html+"</tr>";
end
html=html+"</table><p>Träningsfel är inte oberoende verifiering. Utskrift sker separat; appen intygar inte utskriftskedjan.</p>"+ ...
 "<h2>Underlag</h2><ul><li><a href='final-report.json'>Strukturerad slutrapport (JSON)</a></li><li><a href='final-report.txt'>Slutrapport som text</a></li>";
for key=string(fieldnames(r.sources))'
 name=r.sources.(key).file;html=html+"<li><a href='"+esc(name)+"'>"+esc(name)+"</a></li>";
end
html=html+"<li><a href='final-report.pdf'>Slutrapport som PDF</a></li></ul>";
if isfield(r,'visualization')
 html=html+"<section><h2>Profilens beräknade kontrollfärger i 3D</h2><p>Kontrollpatchar i Lab D50; inte mätningar eller hela skrivarens färgomfång.</p><img src='profile-lab-3d.png' alt='Profilens beräknade kontrollpatchar i Lab 3D' style='width:100%;height:auto'></section>";
end
html=html+"<h2>Fullständig redovisning och historik</h2><pre>"+esc(strjoin(lines,newline))+"</pre></html>";
config=inkprof.paths();
furniture=struct('header',r.pageHeader,'date',r.reportDate,'user',r.reportUser);
pages=string(fileread(fullfile(config.Root,'resources','workflow-report-pages.html')));
metadata=string(jsonencode(furniture));metadata=replace(metadata,"<",string(char(92))+"u003c");
pages=replace(pages,"__REPORT_FURNITURE__",metadata);
html=replace(html,"</html>",pages+"</html>");
writeText(paths.html,html);
inkprof.runPython(fullfile(config.Root,'analysis','workflow_final_pdf.py'),string(folder),RequiredModules="reportlab",WorkingDirectory=config.Root);
    function addStats(label,s)
        row=cell(1,6);row{1}=char(label);fields=["count","mean","median","p95","max"];
        for n=1:5
            value="Ej redovisat";
            if isfield(s,fields(n))&&isscalar(s.(fields(n)))&&isfinite(s.(fields(n)))
                if n==1,value=string(s.(fields(n)));else,value=compose('%.3f',s.(fields(n)));end
            end
            row{n+1}=char(value);
        end
        rows(end+1,:)=row;
    end
end
function text=esc(text)
text=replace(string(text),["&","<",">",string(char(34)),"'"],["&amp;","&lt;","&gt;","&quot;","&#39;"]);
end
function writeText(file,text)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0,'inkprof:IO','Kan inte spara slutrapporten.');
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',text);
end
