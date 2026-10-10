% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function chart=prepareChart(ti2Path,sessionFolder)
%PREPARECHART Validate a printed RGB chart and create a self-contained session.
arguments
    ti2Path (1,1) string
    sessionFolder (1,1) string
end
ti2Path=inkprof.internal.absolutePath(ti2Path);sessionFolder=inkprof.internal.absolutePath(sessionFolder);
assert(isfile(ti2Path),'inkprof:Input','TI2 file does not exist.');
assert(~isfile(sessionFolder)&&~isfolder(sessionFolder),'inkprof:Exists','Session already exists.');
t=inkprof.internal.readCgats(ti2Path);
assert(t.signature=="CTI2",'inkprof:ChartFormat','Measurement requires CTI2 with the printed patch layout. Create a TIFF/TI2 package from PXF, CGATS or TI1 first.');
assert(isfield(t.headers,'COLOR_REP')&&any(t.headers.COLOR_REP==["RGB","iRGB"]), ...
    'inkprof:ColorFormat','Unsupported colour format: InkProf supports RGB targets and measurement definitions only.');
[ok,idx]=ismember(["SAMPLE_ID","SAMPLE_LOC","RGB_R","RGB_G","RGB_B"],t.fields);
assert(all(ok),'inkprof:ChartFormat','TI2 must contain patch IDs, locations and RGB values.');
rgb=str2double(t.data(:,idx(3:5)));inkprof.internal.requireRgb(rgb,100);
ids=t.data(:,idx(1));locations=t.data(:,idx(2));
assert(all(strlength(ids)>0)&&all(strlength(locations)>0)&&numel(unique(locations))==numel(locations), ...
    'inkprof:Identity','Patch locations must be nonempty and unique.');
real=ids~="0";assert(any(real)&&numel(unique(ids(real)))==sum(real),'inkprof:Identity','Source patch IDs must be unique; zero is reserved for padding.');
for key=["STEPS_IN_PASS","PASSES_IN_STRIPS2","STRIP_INDEX_PATTERN","PATCH_INDEX_PATTERN"]
    assert(isfield(t.headers,key),'inkprof:ChartFormat','Missing TI2 layout field: %s',key);
end
steps=str2double(t.headers.STEPS_IN_PASS);passes=str2double(split(t.headers.PASSES_IN_STRIPS2,','));
assert(isscalar(steps)&&isfinite(steps)&&steps>0&&steps==fix(steps)&&all(isfinite(passes)&passes>0&passes==fix(passes)) ...
    &&sum(passes)*steps==numel(ids),'inkprof:ChartFormat','Unsupported or inconsistent strip/page counts.');
patches=repmat(struct('index',0,'sampleId',"",'sampleLoc',"",'rgbPercent',[], ...
    'isPadding',false),numel(ids),1);
for k=1:numel(ids)
    patches(k)=struct('index',k,'sampleId',ids(k),'sampleLoc',locations(k),'rgbPercent',rgb(k,:),'isPadding',ids(k)=="0");
end
targetInfo=inkprof.internal.importTargetInfo(rgb(real,:)/100,ti2Path,ids(real),t.headers);
chart=struct('schemaVersion',1,'documentType',"inkprof.measurement-chart",'colorSpace',"RGB", ...
    'targetInfo',targetInfo,'sourceFormat',"CTI2",'sourcePath',ti2Path,'sourceFile',"source.ti2", ...
    'sourceSHA256',inkprof.internal.sha256(ti2Path),'patchCount',numel(ids),'sourcePatchCount',sum(real), ...
    'stepsInPass',steps,'passesInStrips',passes(:)','metadata',t.headers,'patches',patches, ...
    'validation',"TI2 structure and RGB checked; physical print and instrument compatibility not verified");
% JSON is authoritative. Retain all imported auxiliary/calibration tables.
doc=inkprof.importCgats(ti2Path);tables=struct('signature',{},'fields',{},'metadata',{},'rows',{});
for table=reshape(doc.tables,1,[])
    meta=struct('tokens',{});rows=struct('values',{});
    for k=1:numel(table.metadata),meta(k).tokens=table.metadata{k};end
    for k=1:size(table.data,1),rows(k).values=table.data(k,:);end
    tables(end+1)=struct('signature',table.signature,'fields',table.fields,'metadata',meta,'rows',rows); %#ok<AGROW>
end
chart.exchangeTables=tables;
controlFile=fullfile(fileparts(ti2Path),'print-controls.json');
if isfile(controlFile)
 controls=jsondecode(fileread(controlFile));
 assert(string(controls.documentType)=="inkprof.print-controls"&&controls.excludedFromProfiling&& ...
  string(controls.targetTI2SHA256)==chart.sourceSHA256,'inkprof:Integrity','Print controls do not belong to this TI2.');
 chart.printControls=struct('file',"print-controls.json",'sha256',inkprof.internal.sha256(controlFile));
end
parent=fileparts(sessionFolder);if ~isfolder(parent),mkdir(parent);end
stage=string(tempname(parent));mkdir(stage);cleanup=onCleanup(@()removeStage(stage));
copyfile(ti2Path,fullfile(stage,'source.ti2'));
if isfield(chart,'printControls'),copyfile(controlFile,fullfile(stage,'print-controls.json'));end
assert(inkprof.internal.sha256(fullfile(stage,'source.ti2'))==chart.sourceSHA256,'inkprof:Integrity','TI2 changed during preparation.');
inkprof.internal.writeJson(fullfile(stage,'chart.json'),chart);
[ok,msg]=movefile(stage,sessionFolder);assert(ok,'inkprof:IO','%s',msg);
% Cleanup only applies to an unfinished staging directory.
clear cleanup
inkprof.internal.recordProjectStep(sessionFolder,"chart-prepared");
end

function removeStage(p)
if isfolder(p),rmdir(p,'s');end
end
