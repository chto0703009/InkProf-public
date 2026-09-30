function folder=preparePatchRemeasurement(measurementFile,coordinate)
%PREPAREPATCHREMEASUREMENT Prepare a separate attempt without contacting hardware.
arguments
 measurementFile (1,1) string
 coordinate (1,1) string
end
measurementFile=inkprof.internal.absolutePath(measurementFile);
r=jsondecode(fileread(measurementFile));
assert(string(r.documentType)=="inkprof.chart-measurement",'inkprof:Input','Select a saved measurement JSON.');
chartFile=fullfile(fileparts(measurementFile),'chart.json');
assert(inkprof.internal.sha256(chartFile)==string(r.chartJSONSHA256),'inkprof:Integrity','Chart hash differs.');
chart=jsondecode(fileread(chartFile));
assert(isfield(r,'measurementCondition') && string(r.measurementCondition.interpreted)=="M0" && ~r.measurementCondition.fwaApplied, ...
 'inkprof:Condition','Point replacement currently supports native M0 reflection without FWA only.');
assert(isfield(r.measurementCondition,'instrument') && contains(replace(string(r.measurementCondition.instrument),' ',''),'i1Pro2'),'inkprof:Instrument','Point replacement currently supports i1 Pro 2 only.');
indices=[];
for j=1:numel(chart.patches)
 [row,col]=inkprof.internal.decodeLocation(chart.patches(j).sampleLoc);
 if strcmpi(col+row,strtrim(coordinate)) && ~chart.patches(j).isPadding,indices(end+1)=j;end %#ok<AGROW>
end
assert(isscalar(indices),'inkprof:Identity','Coordinate must identify one non-padding patch.');
m=find(r.chartIndex==indices);assert(isscalar(m),'inkprof:Identity','Patch has no unique saved measurement.');
assert(~isempty(r.data.spectra)&&~isempty(r.data.xyz),'inkprof:Measurement','Spectral and XYZ data are required.');
standard="";
for j=1:numel(r.metadata)
 tokens=string(r.metadata{j});if tokens(1)=="DEVCALSTD",standard=tokens(2);end
end
assert(any(standard==["XRGA","XRDI","GMDI"]),'inkprof:Condition','Unknown original calibration standard.');
port=0;
if isfield(r.measurementCondition,'settings') && isfield(r.measurementCondition.settings,'port'),port=r.measurementCondition.settings.port;end
serial="";
if isfield(r.measurementCondition,'instrumentSerial'),serial=string(r.measurementCondition.instrumentSerial);end
if isfield(r.measurementCondition,'transcriptSHA256')
 logs=dir(fullfile(fileparts(measurementFile),'transcript-*.txt'));
 for entry=reshape(logs,1,[])
  logPath=fullfile(entry.folder,entry.name);
  if inkprof.internal.sha256(logPath)==string(r.measurementCondition.transcriptSHA256)
   token=regexp(fileread(logPath),'Serial Number:\s*(\S+)','tokens','once');
   if ~isempty(token),serial=string(token{1});end
  end
 end
end
request=struct('instrumentSerial',serial,'schemaVersion',1,'documentType','inkprof.spot-request', ...
 'parentMeasurementSHA256',inkprof.internal.sha256(measurementFile),'parentFile',measurementFile, ...
 'chartJSONSHA256',r.chartJSONSHA256,'coordinate',upper(strtrim(coordinate)), ...
 'sampleId',string(r.data.ids(m)),'sampleLoc',string(r.data.locations(m)), ...
 'rgbPercent',r.data.rgbPercent(m,:),'measurementIndex',m,'chartIndex',indices, ...
 'calibrationStandard',standard,'port',port,'condition','M0','identityMethod','operator-selected patch');
folder=fullfile(fileparts(measurementFile),'spot-rereads',string(datetime('now','Format','yyyyMMdd-HHmmss-SSS'))+"-"+string(java.util.UUID.randomUUID()));
mkdir(folder);inkprof.internal.writeJson(fullfile(folder,'request.json'),request);
inkprof.internal.recordProjectStep(folder,'Prepared single-patch measurement');
end
