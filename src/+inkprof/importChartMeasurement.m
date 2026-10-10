% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function result=importChartMeasurement(sessionFolder,ti3Path,options)
%IMPORTCHARTMEASUREMENT Match measured RGB rows to the canonical JSON chart.
arguments
    sessionFolder (1,1) string
    ti3Path (1,1) string = ""
    options.PairedReadings (1,1) struct = struct
    options.ImportInfo (1,1) struct = struct
    options.ConditionRecord (1,1) struct = struct
end
if ti3Path=="",ti3Path=fullfile(sessionFolder,'chart.ti3');end
chart=jsondecode(fileread(fullfile(sessionFolder,'chart.json')));
assert(chart.schemaVersion==1&&string(chart.colorSpace)=="RGB",'inkprof:ChartFormat','Expected RGB chart JSON.');
doc=inkprof.importCgats(ti3Path);t=doc.tables(1);
assert(t.signature=="CTI3",'inkprof:ChartFormat','Expected measured CTI3 data.');
v=inkprof.cgatsData(doc,RGBScale=100);
assert(isempty(v.cmyk)&&size(v.rgb,2)==3,'inkprof:ColorFormat','Unsupported colour format: only RGB is supported.');
assert(~isempty(v.xyz)||~isempty(v.lab)||~isempty(v.spectra),'inkprof:Measurement','No measured colour data.');
assert(numel(v.ids)==size(v.rgb,1),'inkprof:Identity','Missing measured patch IDs.');
p=chart.patches;ids=string({p.sampleId});locations=string({p.sampleLoc});seen=false(numel(p),1);mapping=zeros(numel(v.ids),1);
for k=1:numel(v.ids)
    match=find(ids==v.ids(k));
    if ~isempty(v.locations),match=match(locations(match)==v.locations(k));end
    if v.ids(k)=="0"&&isempty(v.locations),continue;end % anonymous Argyll padding
    assert(numel(match)==1&&~seen(match),'inkprof:Identity','Ambiguous, duplicate or unknown measured patch: %s',v.ids(k));
    expected=double(p(match).rgbPercent(:)');
    assert(max(abs(v.rgb(k,:)-expected))<=1e-4,'inkprof:Identity','RGB differs from chart at %s.',v.ids(k));
    mapping(k)=match;seen(match)=true;
end
required=~[p.isPadding]';
result=struct('schemaVersion',1,'documentType',"inkprof.chart-measurement", ...
    'chartJSONSHA256',inkprof.internal.sha256(fullfile(sessionFolder,'chart.json')), ...
    'sourceTI3SHA256',inkprof.internal.sha256(ti3Path),'sourcePath',inkprof.internal.absolutePath(ti3Path), ...
    'complete',all(seen(required)),'measuredSourcePatches',sum(seen&required),'expectedSourcePatches',sum(required), ...
    'chartIndex',mapping,'data',v,'spectralScale',"unmodified TI3 values; normalization not assumed", ...
    'metadata',{v.metadata});
if isfield(chart,'targetInfo'),result.targetInfo=chart.targetInfo;end
result.measurementCondition=inkprof.internal.measurementCondition(sessionFolder,result.chartJSONSHA256,v.metadata);
if ~isempty(fieldnames(options.ConditionRecord)),result.measurementCondition=options.ConditionRecord;end
if ~isempty(fieldnames(options.ImportInfo)),result.importInfo=options.ImportInfo;end
if ~isempty(fieldnames(options.PairedReadings))
    result.pairedReadings=options.PairedReadings;
    result.measurementCondition=options.PairedReadings.rawMeasurement.measurementCondition;
end
result.instrument=inkprof.internal.instrumentIdentity(sessionFolder,result.measurementCondition);
result.rowDirectionCheck=inkprof.internal.checkRowDirection(sessionFolder,result);
if isfield(chart,'printControls')
 result.printControlCheck=struct('required',true,'status',"not-measured",'excludedFromProfiling',true);
 file=fullfile(sessionFolder,'print-control-check.json');
 if isfile(file)
  check=jsondecode(fileread(file));
  assert(string(check.definitionSHA256)==string(chart.printControls.sha256),'inkprof:Integrity','Print check definition differs.');
  result.printControlCheck=check;result.printControlCheck.reportSHA256=inkprof.internal.sha256(file);
 end
end
% Keep immutable snapshots, including the full original TI3 and its metadata.
name="measurement-"+string(datetime('now','Format','yyyyMMdd-HHmmssSSS'));
assert(~isfile(fullfile(sessionFolder,name+".json")),'inkprof:Exists','Result already exists.');
copyfile(ti3Path,fullfile(sessionFolder,name+".ti3"));
inkprof.internal.writeJson(fullfile(sessionFolder,name+".json"),result);
inkprof.internal.recordProjectStep(sessionFolder,"measurement-saved");
end
