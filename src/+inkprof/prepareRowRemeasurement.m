% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [folder,request]=prepareRowRemeasurement(measurementFile,page,row)
%PREPAREROWREMEASUREMENT Isolate one printed row, keeping its original mapping.
arguments
 measurementFile (1,1) string
 page (1,1) double {mustBeInteger,mustBePositive}
 row (1,1) string
end
measurementFile=inkprof.internal.absolutePath(measurementFile);base=fileparts(measurementFile);
r=jsondecode(fileread(measurementFile));chartFile=fullfile(base,'chart.json');
assert(string(r.documentType)=="inkprof.chart-measurement",'inkprof:Input','Select a saved measurement JSON.');
assert(inkprof.internal.sha256(chartFile)==string(r.chartJSONSHA256),'inkprof:Integrity','Chart changed.');
chart=jsondecode(fileread(chartFile));source=fullfile(base,'source.ti2');
assert(inkprof.internal.sha256(source)==string(chart.sourceSHA256),'inkprof:Integrity','Original TI2 changed.');
labels=strings(numel(chart.patches),1);cols=zeros(size(labels));
for k=1:numel(labels),[labels(k),~,cols(k)]=inkprof.internal.decodeLocation(chart.patches(k).sampleLoc);end
physicalRows=unique(str2double(labels),'sorted');ordinal=find(physicalRows==str2double(row));
assert(isscalar(ordinal),'inkprof:Identity','Unknown printed row.');
info=inkprof.internal.measurementPage(chart,ordinal);
assert(info.page==page,'inkprof:Identity','The selected row is not on the selected page.');
indices=find(labels==info.row);[~,order]=sort(cols(indices));indices=indices(order);
assert(numel(indices)==chart.stepsInPass&&isequal(cols(indices)',1:chart.stepsInPass),'inkprof:Layout','The printed row is incomplete.');
real=indices(~[chart.patches(indices).isPadding]);
assert(~isempty(real)&&all(ismember(real,r.chartIndex)),'inkprof:Measurement','Every source patch on this row must have a saved measurement.');
assert(isfield(r.measurementCondition,'settings'),'inkprof:Settings','The original scan settings are required for row remeasurement.');
s=r.measurementCondition.settings;
assert(isfield(s,'scanMode')&&any(string(s.scanMode)==["single","alternating","paired"]),'inkprof:Settings','Original scan mode is unavailable.');
assert(~r.measurementCondition.fwaApplied,'inkprof:Condition','Row remeasurement requires native, uncompensated readings.');
assert(~isempty(r.data.xyz)&&~isempty(r.data.spectra),'inkprof:Measurement','XYZ and spectra are required for row replacement.');
request=struct('schemaVersion',1,'documentType',"inkprof.row-request",'parentFile',measurementFile, ...
 'parentMeasurementSHA256',inkprof.internal.sha256(measurementFile),'chartJSONSHA256',r.chartJSONSHA256, ...
 'page',page,'totalPages',info.totalPages,'row',info.row,'rowOnPage',info.rowOnPage, ...
 'chartIndices',indices(:),'settings',s,'expectedDirection',"forward");
if string(s.scanMode)=="alternating"&&mod(ordinal,2)==0,request.expectedDirection="reverse";end
% One runtime row, numbered 1, mapped explicitly to the original sheet.
% IDs, RGB and auxiliary/calibration tables are retained.
doc=inkprof.importCgats(source);t=doc.tables(1);loccol=find(t.fields=="SAMPLE_LOC");
assert(isscalar(loccol),'inkprof:Layout','TI2 locations are missing.');
positions=zeros(numel(indices),1);
for k=1:numel(indices)
 pos=find(t.data(:,loccol)==string(chart.patches(indices(k)).sampleLoc));
 assert(isscalar(pos),'inkprof:Identity','TI2 coordinate is not unique.');positions(k)=pos;
end
t.data=t.data(positions,:);
for k=1:numel(indices),[~,column]=inkprof.internal.decodeLocation(chart.patches(indices(k)).sampleLoc);t.data(k,loccol)="1"+column;end
for k=1:numel(t.metadata)
 token=t.metadata{k};if token(1)=="PASSES_IN_STRIPS2",token(2)="1";end
 if token(1)=="STRIP_INDEX_PATTERN",token(2)="0-9,@-9,@-9;1-999";end
 t.metadata{k}=token;
end
doc.tables(1)=t;
parent=fullfile(base,'row-rereads');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,string(java.util.UUID.randomUUID()));mkdir(folder);
inkprof.exportCgats(fullfile(folder,'row.ti2'),doc);
inkprof.prepareChart(fullfile(folder,'row.ti2'),fullfile(folder,'session'));
request.runtimeChartSHA256=inkprof.internal.sha256(fullfile(folder,'session','chart.json'));
inkprof.internal.writeJson(fullfile(folder,'request.json'),request);
inkprof.internal.recordProjectStep(folder,"Prepared remeasurement of page "+page+" row "+row);
end
