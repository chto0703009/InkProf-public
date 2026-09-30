function [folder,record]=prepareProfileInput(source,options)
%PREPAREPROFILEINPUT Validate and freeze a selected measurement for profiling (B1).
arguments
 source (1,1) string = ""
 options.ProjectFolder (1,1) string = ""
 options.TargetFile (1,1) string = ""
 options.Name (1,1) string = "Profile input"
 options.FitSampleIds (:,1) string = strings(0,1)
 options.ShowDialog (1,1) logical = true
end
folder="";record=[];
if source==""
 [n,p]=uigetfile({'*.json;*.ti3;*.mxf','Measurements (JSON, TI3, MXF)'},'Select the measurement revision for profiling');
 if isequal(n,0),return;end
 source=fullfile(p,n);
end
source=inkprof.internal.absolutePath(source);
[~,~,ext]=fileparts(source);
if any(lower(ext)==[".ti3",".mxf"])
 [~,source]=inkprof.importMeasurement(source,TargetFile=options.TargetFile,ShowPreview=false);
 if source=="",return;end
end
fprintf('InkProf B1: checking the selected measurement revision...\n');drawnow;
measurement=jsondecode(fileread(source));
assert(isfield(measurement,'documentType')&&string(measurement.documentType)=="inkprof.chart-measurement", ...
 'inkprof:ProfileInput','Select a measurement JSON, not a target or analysis JSON.');
assert(measurement.complete,'inkprof:ProfileIncomplete','Measurement is incomplete.');
measurementHash=inkprof.internal.sha256(source);
[parent,stem]=fileparts(source);ti3=fullfile(parent,stem+".ti3");chartFile=fullfile(parent,'chart.json');
assert(isfile(ti3)&&isfile(chartFile),'inkprof:ProfileInput','Matching revision TI3 and chart.json are required.');
assert(inkprof.internal.sha256(chartFile)==string(measurement.chartJSONSHA256),'inkprof:Integrity','Chart hash does not match measurement.');
project=options.ProjectFolder;
if project=="",project=inkprof.internal.findProject(source);end
if project==""
 p=uigetdir(char(parent),'Select an existing InkProf profiling project');
 if isequal(p,0),return;end
 project=string(p);
end
project=inkprof.internal.findProject(project);assert(project~="",'inkprof:Project','An existing InkProf project is required.');
work=string(tempname);mkdir(work);cleanup=onCleanup(@()rmdir(work,'s'));
copyfile(chartFile,fullfile(work,'chart.json'));
% Recheck identity, RGB, completeness and row direction from actual TI3 bytes.
fprintf('InkProf B1: verifying patch identities and row direction...\n');drawnow;
verified=inkprof.importChartMeasurement(work,ti3,ConditionRecord=measurement.measurementCondition);
assert(verified.complete,'inkprof:ProfileIncomplete','The TI3 is incomplete.');
for key=["ids","locations"]
 assert(isequal(string(verified.data.(key)),string(measurement.data.(key))),'inkprof:Integrity','JSON and TI3 patch identities differ.');
end
for key=["rgb","xyz","lab","spectra","wavelengthNm"]
 a=double(verified.data.(key));b=double(measurement.data.(key));
 assert(numel(a)==numel(b)&&(isempty(a)||max(abs(a(:)-b(:)))<=1e-7),'inkprof:Integrity','JSON and TI3 values differ: %s.',key);
end
assert(~isempty(verified.data.xyz)||~isempty(verified.data.spectra),'inkprof:ProfileInput','B1 requires measured XYZ or spectra.');
check=verified.rowDirectionCheck;
layoutEvidence=struct;originalMXF="";
if isfield(check,'available')&&check.available
 assert(isempty(check.flaggedRows),'inkprof:ProfileDirection','Suspected reversed rows remain. Review or remeasure before locking.');
else
 % Positioned MXF provides identity/layout evidence, not estimated TI2 XYZ.
 % Reparse the preserved source instead of trusting an import flag in JSON.
 assert(isfield(measurement,'importInfo')&&string(measurement.importInfo.format)=="MXF", ...
  'inkprof:ProfileDirection','Row-direction check is unavailable and no positioned MXF source is available.');
 originalMXF=fullfile(parent,'original.mxf');
 assert(isfile(originalMXF)&&inkprof.internal.sha256(originalMXF)==string(measurement.importInfo.sourceSHA256), ...
  'inkprof:Integrity','Preserved MXF is missing or its hash changed.');
 [original,~,~]=inkprof.importMeasurement(originalMXF,SessionFolder=fullfile(work,'mxf-check'), ...
  Condition=string(measurement.importInfo.selectedCondition),ShowPreview=false);
 for key=["ids","locations"]
  assert(isequal(string(original.data.(key)),string(verified.data.(key))), ...
   'inkprof:Identity','MXF source and selected revision patch mapping differ.');
 end
 assert(isequal(size(original.data.rgb),size(verified.data.rgb))&& ...
  max(abs(original.data.rgb(:)-verified.data.rgb(:)))<=1e-7, ...
  'inkprof:Identity','MXF source and selected revision RGB definitions differ.');
 layoutEvidence=struct('available',true,'basis',"Preserved positioned MXF reparsed: patch IDs, locations and RGB match the selected revision", ...
  'sourceSHA256',measurement.importInfo.sourceSHA256,'sourceFile',"original.mxf", ...
  'physicalScanDirectionVerified',false);
end
chart=jsondecode(fileread(chartFile));mapping=verified.chartIndex(:);keep=mapping>0;
keep(keep)=~[chart.patches(mapping(keep)).isPadding]';
assert(sum(keep)==verified.expectedSourcePatches,'inkprof:Identity','Source patch count mismatch.');
paddingCount=sum(~keep);
if ~isempty(options.FitSampleIds)
 ids=string(verified.data.ids(:));selected=options.FitSampleIds;
 assert(numel(unique(selected))==numel(selected)&&all(ismember(selected,ids(keep))), ...
  'inkprof:FitSelection','Fit sample IDs must be unique non-padding IDs in this measurement.');
 keep=keep & ismember(ids,selected);
 assert(any(keep),'inkprof:FitSelection','At least one fitting patch is required.');
end
manifest=jsondecode(fileread(fullfile(project,'inkprof-project.json')));
notes=["Row-direction check is heuristic, not profile colour accuracy.";"Print settings and measurement-condition provenance are preserved without guessing."];
quality=struct;
if isfield(measurement,'pairedReadings')&&isfield(measurement.pairedReadings,'directionComparison')
 quality=measurement.pairedReadings.directionComparison;
 notes(end+1)="Original paired-scan quality (may predate spot corrections): "+string(jsonencode(quality));
end
if check.available
 notes(end+1)=sprintf('Row-direction diagnostic evaluated %d full rows; partial/uncheckable rows are not certified.',numel(check.rows));
else
 notes(end+1)="Colour-based row-direction diagnostic unavailable: no TI2 XYZ estimates. Original MXF identity/layout was verified instead; physical scanning direction is not certified.";
end
summary=sprintf('Revision: %s\nSHA-256: %s\nRGB patches: %d\nSpectral bands: %d | XYZ available: %d\nMeasurement conditions:\n%s\nPrinting:\n%s\n\n%s', ...
 source,measurementHash,sum(keep),numel(verified.data.wavelengthNm),~isempty(verified.data.xyz), ...
 jsonencode(measurement.measurementCondition,PrettyPrint=true),jsonencode(manifest.printing,PrettyPrint=true),strjoin(notes,newline));
name=options.Name;
if options.ShowDialog
 [accepted,name]=inkprof.internal.confirmProfileInput(summary,name);if ~accepted,return;end
end
assert(strlength(strtrim(name))>0,'inkprof:Name','Enter a name for this profile input.');
fprintf('InkProf B1: saving the validated snapshot...\n');drawnow;
package=fullfile(work,'locked');mkdir(package);
copyfile(source,fullfile(package,'measurement.json'));copyfile(chartFile,fullfile(package,'chart.json'));copyfile(ti3,fullfile(package,'source.ti3'));
assert(inkprof.internal.sha256(fullfile(package,'measurement.json'))==measurementHash&& ...
 inkprof.internal.sha256(fullfile(package,'chart.json'))==string(measurement.chartJSONSHA256)&& ...
 inkprof.internal.sha256(fullfile(package,'source.ti3'))==string(verified.sourceTI3SHA256), ...
 'inkprof:Integrity','Source changed while preparing the snapshot.');
if originalMXF~=""
 copyfile(originalMXF,fullfile(package,'original.mxf'));
 assert(inkprof.internal.sha256(fullfile(package,'original.mxf'))==string(layoutEvidence.sourceSHA256), ...
  'inkprof:Integrity','MXF changed during snapshot creation.');
end
 doc=inkprof.importCgats(fullfile(package,'source.ti3'));assert(numel(doc.tables)==1,'inkprof:ProfileInput','Expected a single measured table.');
doc.tables(1).data=doc.tables(1).data(keep,:);
inkprof.exportCgats(fullfile(package,'profiling.ti3'),doc);
% Read the exported file back to verify the exact retained patch order/values.
out=inkprof.cgatsData(inkprof.importCgats(fullfile(package,'profiling.ti3')),RGBScale=100);
assert(isequal(out.ids,verified.data.ids(keep))&&isequal(out.rgb,verified.data.rgb(keep,:)), ...
 'inkprof:Integrity','Profiling TI3 patch mapping changed.');
for key=["xyz","lab","spectra"]
 assert(isequal(out.(key),verified.data.(key)(keep,:)),'inkprof:Integrity','Export changed measured values.');
end
record=struct('schemaVersion',1,'documentType',"inkprof.profile-input",'name',name, ...
 'createdUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
 'sourceRevision',source,'measurementSHA256',measurementHash,'sourceTI3SHA256',verified.sourceTI3SHA256, ...
 'chartJSONSHA256',measurement.chartJSONSHA256,'profilingTI3SHA256',inkprof.internal.sha256(fullfile(package,'profiling.ti3')), ...
 'measurementFile',"measurement.json",'chartFile',"chart.json",'profilingFile',"profiling.ti3", ...
 'patchCount',sum(keep),'excludedPaddingCount',paddingCount,'excludedRoleCount',sum(~keep)-paddingCount,'sourceDataRows',find(keep), ...
 'measurementCondition',measurement.measurementCondition,'printing',manifest.printing, ...
 'rowDirectionCheck',check,'layoutEvidence',layoutEvidence,'pairedScanQuality',quality,'notes',notes,'status',"locked-input-not-profiled");
inkprof.internal.writeJson(fullfile(package,'profile-input.json'),record);
base=fullfile(project,'profiles','inputs');if ~isfolder(base),mkdir(base);end
folder=fullfile(base,string(java.util.UUID.randomUUID()));
[ok,msg]=movefile(package,folder);assert(ok,'inkprof:IO','%s',msg);
inkprof.internal.recordProjectStep(folder,"Locked validated measurement revision for ICC profiling (B1)");
fprintf('InkProf: locked %d patches.\nProfile input: %s\n',record.patchCount,folder);
end