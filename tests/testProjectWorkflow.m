function tests=testProjectWorkflow
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));tc.TestData.root=string(root);
end
function setup(tc)
p=string(tempname);inkprof.createProject(p);tc.TestData.project=p;
tc.TestData.w=inkprof.ProjectWorkflow(p);
end
function teardown(tc)
close all force
rmdir(tc.TestData.project,'s');
end
function testGuardAndPersistence(tc)
w=tc.TestData.w;verifyTrue(tc,w.ready('definition'));verifyFalse(tc,w.ready('profile'));
verifyError(tc,@()w.run('profile'),'inkprof:WorkflowBlocked');
verifyFalse(tc,isfile(fullfile(w.Root,'.workflow.lock')));
saveDefinition(tc);verifyTrue(tc,w.valid('definition'));verifyTrue(tc,w.ready('render'));
v=inkprof.ProjectWorkflow(w.Root);verifyEqual(tc,v.State.currentStep,'definition');verifyTrue(tc,v.valid('definition'));
a=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));verifyFalse(tc,any(string({a.files.path})==".workflow.lock"));
log=fileread(fullfile(w.Root,'result-log.txt'));verifyTrue(tc,contains(log,'completed'));verifyTrue(tc,contains(log,'Iteration 1'));
lines=splitlines(strtrim(string(fileread(fullfile(w.Root,'result-log.jsonl')))));
for k=1:numel(lines),e=jsondecode(lines(k));verifyEqual(tc,e.cycle,1);end
end
function testHashAndScopeGuards(tc)
w=tc.TestData.w;saveDefinition(tc);
f=w.output('definition','definition');fid=fopen(f,'a');fprintf(fid,'\n# modified\n');fclose(fid);
verifyFalse(tc,w.valid('definition'));verifyError(tc,@()w.run('render'),'inkprof:WorkflowBlocked');
verifyError(tc,@()w.resolve('../outside.json'),'inkprof:WorkflowPath');
end
function testPrintAndWrongMeasurement(tc)
w=tc.TestData.w;saveDefinition(tc);
folder=fullfile(w.Root,'targets','printed');inkprof.createTarget(folder,Source=w.output('definition','definition'),DPI=100,Paper="A4-landscape");
w.run('render',struct('Source',folder));verifyTrue(tc,w.ready('measurement'));
verifyTrue(tc,isfile(w.output('render','TIFF16_sida_1')));
wrong=fullfile(w.Root,'sources','wrong.json');inkprof.internal.writeJson(wrong,struct('documentType','inkprof.verification'));
verifyError(tc,@()w.run('measurement',struct('Source',wrong)),'inkprof:WorkflowMeasurement');
verifyEqual(tc,string(w.State.steps.measurement.status),"failed");verifyFalse(tc,w.ready('review'));
% Replacing the selected definition invalidates its saved target.
saveDefinition(tc);verifyEqual(tc,string(w.State.steps.render.status),"stale");verifyFalse(tc,w.ready('measurement'));
end
function testConcurrentLock(tc)
w=tc.TestData.w;f=fullfile(w.Root,'.workflow.lock');fid=fopen(f,'w');fclose(fid);
verifyError(tc,@()w.run('definition'),'inkprof:WorkflowBusy');delete(f);
end
function testUIResume(tc)
w=tc.TestData.w;saveDefinition(tc);f=inkprof.app(w.Root);cleanup=onCleanup(@()delete(f));drawnow;
t=findobj(f,'Tag','workflowSteps');verifySize(tc,t.Data,[17 2]);
verifyEqual(tc,t.Data{1,2},'Complete');verifyEqual(tc,t.Data{2,2},'Ready');verifyEqual(tc,t.Data{8,2},'Locked');
verifyNotEmpty(tc,findobj(f,'Tag','openResultLog'));verifyNotEmpty(tc,findobj(f,'Tag','iterationHistory'));verifyNotEmpty(tc,findobj(f,'Tag','openFinalReport'));
end
function saveDefinition(tc)
f=fullfile(tc.TestData.project,'sources','test.ti1');
if ~isfile(f)
 d=inkprof.designRGBTarget(Levels=2,GraySteps=3,MaxPoints=24,ControlCount=3,RepeatCount=2);
 inkprof.saveRGBDefinition(d,f);
end
tc.TestData.w.run('definition',struct('Source',f));
end

function testIterationTransition(tc)
s=tc.TestData.w.State;old=s.iterationId;
for key=string(fieldnames(s.steps))',s.steps.(key).status="completed";end
s.steps.refine.outputs=struct('proposal',"profiles/refine/proposal.json");
s.steps.refinemeasurement.outputs=struct('measurement',"measurements/new/measurement.json");
o=struct('profile',"profiles/new/result/profile.icc",'job',"profiles/new/status.json");
s=inkprof.internal.advanceWorkflowCycle(s,o,struct([]));
verifyEqual(tc,s.cycle,2);verifyEqual(tc,s.parentIterationId,old);verifyNotEqual(tc,s.iterationId,old);
verifyEqual(tc,s.steps.profile.outputs,o);verifyEqual(tc,s.steps.profile.status,"completed");
for key=["checks","c2","c2measurement","c3","approve","export","refine","continue"]
 verifyEqual(tc,s.steps.(key).status,"stale");
end
verifyEqual(tc,s.activeContinuation.measurement,"measurements/new/measurement.json");
verifyEqual(tc,s.currentStep,"checks");
end

function testMatchingMeasurementAndTamper(tc)
w=tc.TestData.w;saveDefinition(tc);
pkg=fullfile(w.Root,'targets','printed');inkprof.createTarget(pkg,Source=w.output('definition','definition'),DPI=100);
w.run('render',struct('Source',pkg));
folder=fullfile(w.Root,'measurements','fixture');chart=inkprof.prepareChart(fullfile(pkg,'target.ti2'),folder);
p=chart.patches;p=p(~[p.isPadding]);file=fullfile(folder,'synthetic.ti3');fid=fopen(file,'w');
fprintf(fid,'CTI3\nCOLOR_REP "RGB_XYZ"\nNUMBER_OF_FIELDS 7\nBEGIN_DATA_FORMAT\nSAMPLE_ID RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z\nEND_DATA_FORMAT\nNUMBER_OF_SETS %d\nBEGIN_DATA\n',numel(p));
for k=1:numel(p),fprintf(fid,'%s %.12g %.12g %.12g 10 20 30\n',p(k).sampleId,p(k).rgbPercent);end
fprintf(fid,'END_DATA\n');fclose(fid);
inkprof.importChartMeasurement(folder,file);f=dir(fullfile(folder,'measurement-*.json'));source=fullfile(f(1).folder,f(1).name);
w.run('measurement',struct('Source',source));verifyTrue(tc,w.valid('measurement'));verifyTrue(tc,w.ready('review'));
w.run('review',struct('Confirmed',true,'Notes','Synthetic data only'));verifyTrue(tc,w.ready('input'));
[~,stem]=fileparts(source);fid=fopen(fullfile(folder,string(stem)+".ti3"),'a');fprintf(fid,'# altered');fclose(fid);
verifyFalse(tc,w.ready('input'));
end
function testProjectBoundDesignerAndRenderer(tc)
file=fullfile(tc.TestData.project,'targets','designed.ti1');
f=inkprof.designTarget(OutputFile=file);
for setting={'levels',2;'maxPoints',24;'graySteps',3;'controls',3;'repeats',2}'
 set(findobj(f,'Tag',setting{1}),'Value',setting{2});
end
b=findobj(f,'Tag','previewBase');b.ButtonPushedFcn(b,[]);
b=findobj(f,'Tag','saveDesign');b.ButtonPushedFcn(b,[]);
verifyTrue(tc,isfile(file));verifyFalse(tc,isvalid(f));
folder=fullfile(tc.TestData.project,'targets','rendered');
f=inkprof.renderTarget(file,OutputFolder=folder);
verifyEqual(tc,string(findobj(f,'Tag','renderSource').Editable),"off");
set(findobj(f,'Tag','renderDPI'),'Value',100);
b=findobj(f,'Tag','renderSave');b.ButtonPushedFcn(b,[]);
verifyFalse(tc,isvalid(f));verifyTrue(tc,isfile(fullfile(folder,'target.ti2')));
r=inkprof.verifyPackage(folder);verifyNotEmpty(tc,r);
end

function testRemovedPrintStagesAndMigration(tc)
defs=inkprof.internal.workflowSteps();ids=string({defs.id});
verifyFalse(tc,any(ismember(["print","c2print","refineprint"],ids)));
for pair={'measurement','render';'c2measurement','c2';'refinemeasurement','refine'}'
 d=defs(ids==string(pair{1}));verifyEqual(tc,string(d.requires),string(pair{2}));
end
s=tc.TestData.w.State;s=rmfield(s,'workflowRevision');s.currentStep="c2print";
s.steps.c2print=struct('status',"completed",'outputs',struct('confirmation',"legacy.json"));
s.steps.export.status="completed";s.steps.export.outputs=struct('profile',"old.icc");
u=inkprof.internal.upgradeWorkflowState(s);
verifyEqual(tc,u.currentStep,'c2measurement');verifyEqual(tc,u.steps.c2print,s.steps.c2print);
verifyEqual(tc,u.steps.export.status,"stale");verifyEqual(tc,u.steps.export.outputs.profile,"old.icc");
end
function testFinalReportSavedWithICC(tc)
w=finalReportFixture(tc);inkprof.updateProject(w.Root,Printing=struct('printer',"Certificate printer <demo>"));w.run('export',struct('ReportUser',"Christer Törnkvist"));
verifyTrue(tc,w.valid('export'));
for key=["profile","finalReport","reportJSON","reportText","reportPDF"],verifyTrue(tc,isfile(w.output('export',key)));end
r=jsondecode(fileread(w.output('export','reportJSON')));
verifyEqual(tc,string(r.profile.sha256),inkprof.internal.sha256(w.output('export','profile')));
verifyEqual(tc,string(r.iterationId),string(w.State.iterationId));verifyEqual(tc,r.iteration,1);
verifyEqual(tc,string(r.reportUser),"Christer Törnkvist");verifyEqual(tc,string(r.pageHeader),"InkProf Quality Profiling RGB printer");
verifyEqual(tc,r.results.c3_report.summary.mean,1.25);verifyFalse(tc,r.printing.verifiedByApp);
verifyTrue(tc,isfield(r,'fwa'));verifyTrue(tc,contains(r.fwa.summaryText,'FWA-effekt'));
verifyEqual(tc,string(r.documentTitle),"InkProf - mätcertifikat");verifyNotEmpty(tc,r.certificateId);
verifyTrue(tc,contains(r.reproductionLiability,'enbart beror'));verifyTrue(tc,contains(r.reproductionLiability,'tvingande lag'));
verifyTrue(tc,contains(r.clientPrintResponsibility,'Om beställaren'));verifyTrue(tc,contains(r.clientPrintResponsibility,'tvingande lag'));
verifyEqual(tc,string(r.signature.status),"unsigned");verifyTrue(tc,contains(r.reproductionLimits,'skrivare, papper och bläck'));
verifyEqual(tc,string(r.projectDetails(string({r.projectDetails.label})=="Skrivare").value),"Certificate printer <demo>");
verifyTrue(tc,contains(fileread(w.output('export','reportText')),'Ort och datum:'));

h=fileread(w.output('export','finalReport'));verifyTrue(tc,contains(h,'1.250'));
verifyTrue(tc,contains(h,'Underskrift av mätcertifikat'));verifyTrue(tc,contains(h,'Certificate printer &lt;demo&gt;'));
verifyTrue(tc,contains(h,"class='lab-canvas'"));verifyTrue(tc,contains(h,'requestAnimationFrame'));
plot=regexp(h,"<script type='application/json' class='lab-data'>(.*?)</script>",'tokens','once');
points=jsondecode(plot{1});verifyEqual(tc,size(points.lab),[12 3]);verifyEqual(tc,size(points.rgb),[12 3]);
verifyTrue(tc,contains(h,'report-page'));verifyTrue(tc,contains(h,'Christer Törnkvist'));verifyTrue(tc,contains(h,'&lt;test&gt;'));verifyFalse(tc,contains(h,'Synthetic <test>'));
verifyTrue(tc,contains(fileread(fullfile(w.Root,'result-log.txt')),'finalReport'));
f=inkprof.app(w.Root);verifyEqual(tc,string(findobj(f,'Tag','openFinalReport').Enable),"on");delete(f);
% A report belongs to its saved ICC bytes, not only to the output path.
fid=fopen(w.output('export','profile'),'a');fprintf(fid,'altered');fclose(fid);verifyFalse(tc,w.valid('export'));
end
function testFinalReportRejectsDifferentApproval(tc)
w=finalReportFixture(tc);a=w.output('approve','approval');r=jsondecode(fileread(a));r.profileSHA256='wrong';inkprof.internal.writeJson(a,r);
verifyError(tc,@()w.run('export'),'inkprof:FinalReport');verifyEqual(tc,string(w.State.steps.export.status),"failed");
verifyFalse(tc,w.valid('export'));
end
function w=finalReportFixture(tc)
% Synthetic records isolate export/report orchestration from physical devices.
w=tc.TestData.w;s=w.State;
for key=string(fieldnames(s.steps))',s.steps.(key).status="completed";end
folder=fullfile(w.Root,'reports','synthetic');mkdir(folder);
summary=struct('count',3,'mean',1.25,'median',1,'p95',2,'max',2.5);
pairs={'checks','fit';'checks','grid';'checks','c1';'c3','report';'feedback','feedback';'measurement','measurement';'c2measurement','measurement';'profile','job'};
for k=1:size(pairs,1)
 key=string(pairs{k,1});name=string(pairs{k,2});file=fullfile(folder,key+"-"+name+".json");
 inkprof.internal.writeJson(file,struct('summary',summary,'status','synthetic-test-only'));
 s.steps.(key).outputs.(name)=w.relative(file);
end
profile=fullfile(folder,'test.icc');f=fopen(profile,'w','ieee-be');
fwrite(f,zeros(160,1),'uint8');fseek(f,0,'bof');fwrite(f,160,'uint32');
fseek(f,8,'bof');fwrite(f,[4 32],'uint8');fseek(f,12,'bof');fwrite(f,'prtrRGB Lab ','char');
fseek(f,24,'bof');fwrite(f,[2026 9 27 12 0 0],'uint16');fseek(f,36,'bof');fwrite(f,'acsp','char');
fseek(f,128,'bof');fwrite(f,1,'uint32');fwrite(f,'cprt','char');fwrite(f,[144 13],'uint32');
fseek(f,144,'bof');fwrite(f,'text','char');fwrite(f,0,'uint32');fwrite(f,[double('test') 0],'uint8');fclose(f);
s.steps.profile.outputs.profile=w.relative(profile);
patches=struct('predictedLabD50Absolute',{},'placement',{},'id',{});
for i=1:12,patches(i)=struct('predictedLabD50Absolute',[10+6*i 30*cos(i) 25*sin(i)],'placement',struct('coordinate',"A"+i),'id',string(i));end
reference=fullfile(folder,'verification.json');inkprof.internal.writeJson(reference,struct('documentType',"inkprof.verification-target", ...
 'name',"Syntetiskt test - inte en uppmätt profil",'patches',patches,'printerProfile',struct('sha256',inkprof.internal.sha256(profile))));
s.steps.c2.outputs.reference=w.relative(reference);
file=fullfile(folder,'approval.json');inkprof.internal.writeJson(file,struct('notes','Synthetic <test> & fixture only', ...
 'profileSHA256',inkprof.internal.sha256(profile),'reportSHA256',inkprof.internal.sha256(w.resolve(s.steps.c3.outputs.report))));
s.steps.approve.outputs.approval=w.relative(file);s.steps.export.status="pending";
inkprof.internal.writeJson(fullfile(w.Root,'workflow.json'),s);w.reload();
end

function testSeparateDeliveryDestinations(tc)
w=finalReportFixture(tc);external=string(tempname);mkdir(external);cleanup=onCleanup(@()rmdir(external,'s'));
mkdir(fullfile(external,'ICC'));mkdir(fullfile(external,'Rapporter'));
icc=fullfile(external,'ICC','Mitt papper.icc');report=fullfile(external,'Rapporter','Min slutrapport.html');
w.run('export',struct('ICCDestination',icc,'ReportDestination',report));
verifyTrue(tc,w.valid('export'));verifyTrue(tc,isfile(icc));verifyTrue(tc,isfile(report));verifyTrue(tc,isfile(fullfile(external,'Rapporter','Min slutrapport.pdf')));
verifyEqual(tc,inkprof.internal.sha256(icc),inkprof.internal.sha256(w.output('export','profile')));
r=jsondecode(fileread(w.output('export','delivery')));verifyEqual(tc,string(r.iccFile),inkprof.internal.absolutePath(icc));
verifyEqual(tc,string(r.reportFile),inkprof.internal.absolutePath(report));verifyTrue(tc,isfile(fullfile(r.reportAssets,'final-report.json')));
html=string(fileread(report));verifyTrue(tc,contains(html,'Min%20slutrapport-underlag-'));verifyFalse(tc,contains(html,"href='profile.icc'"));verifyTrue(tc,contains(html,"src='Min%20slutrapport-underlag-"));
folder=fileparts(w.output('export','profile'));
verifyError(tc,@()inkprof.internal.saveWorkflowDelivery(folder,icc,report),'inkprof:Exists');
original=inkprof.internal.sha256(icc);
verifyError(tc,@()inkprof.internal.saveWorkflowDelivery(folder,icc,fullfile(external,'missing','report.html'),Overwrite=true),'inkprof:Delivery');
verifyEqual(tc,inkprof.internal.sha256(icc),original);
% A user-selected text report is independently readable; project guards do not depend on external files.
txt=fullfile(external,'Rapporter','rapport.txt');
r=inkprof.internal.saveWorkflowDelivery(folder,icc,txt,Overwrite=true);verifyTrue(tc,isfile(txt));
verifyTrue(tc,contains(fileread(txt),'Rapportunderlag:'));verifyEqual(tc,string(r.iccSHA256),original);
delete(icc);verifyTrue(tc,w.valid('export'));
verifyError(tc,@()inkprof.internal.saveWorkflowDelivery(folder,w.output('profile','profile'),report,Overwrite=true),'inkprof:Delivery');
end
function testEditDetailsKeepsEvidenceAndInvalidatesDelivery(tc)
w=finalReportFixture(tc);w.run('export',struct('ReportUser',"Alice"));
profile=w.output('profile','profile');hash=inkprof.internal.sha256(profile);
report=w.output('export','reportPDF');
a=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
oldRoot=w.Root;[~,stem]=fileparts(oldRoot);newName=stem+" renamed";
d=struct('Name',newName,'User',"Bob",'Printing',a.printing);
w.editDetails(d);tc.TestData.project=w.Root;
profile=replace(profile,oldRoot,w.Root);report=replace(report,oldRoot,w.Root);
verifyFalse(tc,isfolder(oldRoot));verifyTrue(tc,isfolder(w.Root));
verifyTrue(tc,w.valid('approve'));verifyFalse(tc,w.valid('export'));
verifyTrue(tc,isfile(report));verifyEqual(tc,inkprof.internal.sha256(profile),hash);
fresh=inkprof.ProjectWorkflow(w.Root);
b=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
verifyEqual(tc,string(b.name),newName);verifyEqual(tc,string(b.user),"Bob");
verifyEqual(tc,string(a.projectId),string(b.projectId));verifyEqual(tc,string(fresh.State.currentStep),string(w.State.currentStep));
d.Printing.paper="Corrected paper";d.Printing.paperSurface="Matte";fresh.editDetails(d);
verifyFalse(tc,fresh.valid('approve'));verifyFalse(tc,fresh.ready('export'));verifyFalse(tc,fresh.valid('input'));verifyTrue(tc,fresh.valid('measurement'));
verifyTrue(tc,contains(fileread(fullfile(w.Root,'result-log.txt')),'project-details'));
verifyTrue(tc,isfile(report));
end
function testEditDetailsRespectsWorkflowLock(tc)
w=tc.TestData.w;file=fullfile(w.Root,'.workflow.lock');fid=fopen(file,'w');fclose(fid);
verifyError(tc,@()w.editDetails(struct('Name',"Name",'User',"User",'Printing',struct)), 'inkprof:WorkflowBusy');
end
function testRenameRejectsOccupiedFolderAndInvalidName(tc)
w=tc.TestData.w;before=fileread(fullfile(w.Root,'workflow.json'));
a=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
occupied=string(tempname(fileparts(w.Root)));mkdir(occupied);cleanup=onCleanup(@()rmdir(occupied,'s'));
[~,name]=fileparts(occupied);d=struct('Name',name,'User',"User",'Printing',a.printing);
verifyError(tc,@()w.editDetails(d),'inkprof:Exists');
verifyEqual(tc,fileread(fullfile(w.Root,'workflow.json')),before);
d.Name="../outside";verifyError(tc,@()w.editDetails(d),'inkprof:ProjectName');
verifyTrue(tc,isfolder(w.Root));verifyTrue(tc,isfolder(occupied));
end
function testPortableProjectAndIntegrity(tc)
w=finalReportFixture(tc);w.run('export',struct('ReportUser',"Alice"));
check=inkprof.verifyProject(w.Root);verifyTrue(tc,check.passed,strjoin(check.issues,newline));
original=w.Root;copied=string(tempname);copyfile(original,copied);rmdir(original,'s');tc.TestData.project=copied;
fresh=inkprof.ProjectWorkflow(copied);
check=inkprof.verifyProject(copied);verifyTrue(tc,check.passed,strjoin(check.issues,newline));
verifyEqual(tc,string(fresh.State.projectId),string(w.State.projectId));verifyTrue(tc,fresh.valid('export'));
verifyTrue(tc,isfile(fresh.output('export','reportPDF')));verifyTrue(tc,isfile(fresh.output('measurement','measurement')));
file=fresh.output('profile','profile');fid=fopen(file,'a');fprintf(fid,'tampered');fclose(fid);
check=inkprof.verifyProject(copied);verifyFalse(tc,check.passed);verifyTrue(tc,any(contains(check.issues,'Changed file:')));
delete(file);check=inkprof.verifyProject(copied);verifyFalse(tc,check.passed);verifyTrue(tc,any(contains(check.issues,'Missing file:')));
end

function testFWAEditAfterProfilePreservesEvidence(tc)
w=finalReportFixture(tc);profile=w.output('profile','profile');digest=inkprof.internal.sha256(profile);
a=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
w.editDetails(struct('Name',a.name,'User',"Tester",'Printing',struct('fwaCompensation',true)));
fresh=inkprof.ProjectWorkflow(w.Root);
verifyTrue(tc,fresh.valid('measurement'));verifyFalse(tc,fresh.valid('profile'));verifyFalse(tc,fresh.ready('export'));
verifyEqual(tc,inkprof.internal.sha256(profile),digest);
a=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));verifyTrue(tc,a.printing.fwaCompensation);
verifyTrue(tc,contains(fileread(fullfile(w.Root,'result-log.jsonl')),'fwaCompensation'));
end

function testLaterFWAChoiceUpdatesProjectAndKeepsInput(tc)
w=finalReportFixture(tc);profile=w.output('profile','profile');digest=inkprof.internal.sha256(profile);
w.setFWA(true,"profiling-recipe");fresh=inkprof.ProjectWorkflow(w.Root);
a=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));verifyTrue(tc,a.printing.fwaCompensation);
verifyTrue(tc,fresh.valid('input'));verifyTrue(tc,fresh.valid('measurement'));
verifyFalse(tc,fresh.valid('recipe'));verifyFalse(tc,fresh.valid('profile'));verifyFalse(tc,fresh.ready('export'));
verifyEqual(tc,inkprof.internal.sha256(profile),digest);
verifyTrue(tc,contains(fileread(fullfile(w.Root,'result-log.jsonl')),'fwa-selection'));
fresh.setFWA(false);a=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));verifyFalse(tc,a.printing.fwaCompensation);
end
function testFWACertificateUsesBuiltProfileEvidence(tc)
s=struct('count',12,'mean',1.2,'p95',2,'max',3);
fit=struct('summary',s,'colorimetry',struct('fwaCompensation',true,'fwaIlluminant',"D50"));
c3=fit;r=inkprof.internal.fwaReportSummary(fit,c3,struct('fwaCompensation',false),"hash");
verifyTrue(tc,r.applied);verifyFalse(tc,r.projectChoice);verifyEqual(tc,r.trainingResult.mean,1.2);
verifyTrue(tc,contains(r.summaryText,'Ja -'));verifyTrue(tc,contains(r.summaryText,'1.200'));
verifyTrue(tc,contains(r.effectComparedWithUncompensated,'Ej utvärderad'));
fit.colorimetry.fwaCompensation=false;
verifyError(tc,@()inkprof.internal.fwaReportSummary(fit,c3,struct,"hash"),'inkprof:FinalReport');
c3=fit;r=inkprof.internal.fwaReportSummary(fit,c3,struct,"hash");verifyFalse(tc,r.applied);verifyTrue(tc,contains(r.summaryText,'Nej -'));
r=inkprof.internal.fwaReportSummary(struct,struct,struct('fwaCompensation',true),"hash");verifyEmpty(tc,r.applied);verifyEqual(tc,r.status,"Ej dokumenterat");
end

function testExplicitFWAOffIsRecordedWithoutInvalidation(tc)
w=finalReportFixture(tc);w.setFWA(false,"automatic-profiling");
a=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));verifyFalse(tc,a.printing.fwaCompensation);
verifyTrue(tc,w.valid('profile'));verifyTrue(tc,w.valid('input'));
verifyTrue(tc,contains(fileread(fullfile(w.Root,'result-log.jsonl')),'previouslyRecorded'));
end
