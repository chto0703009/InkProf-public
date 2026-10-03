% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function result=averagePairedMeasurement(folder,raw,threshold)
if nargin<3,threshold=1;end
% Equal-weight spectral/XYZ mean. Preserve raw readings and comparison data.
plan=jsondecode(fileread(fullfile(folder,'paired-plan.json')));
assert(string(plan.physicalChartSHA256)==inkprof.internal.sha256(fullfile(folder,'chart.json')) && ...
 string(plan.runtimeChartSHA256)==string(raw.chartJSONSHA256),'inkprof:Integrity','Paired definitions changed.');
assert(raw.complete,'inkprof:Measurement','Both readings are required for every source patch.');
chart=jsondecode(fileread(fullfile(folder,'chart.json')));p=chart.patches;real=find(~[p.isPadding]);
doc=inkprof.importCgats(raw.sourcePath);t=doc.tables(1);
assert(all(ismember(["XYZ_X","XYZ_Y","XYZ_Z"],t.fields)) && ~any(startsWith(t.fields,"LAB_")), ...
 'inkprof:Measurement','Paired averaging currently requires XYZ output; Lab is not averaged.');
spec=find(startsWith(t.fields,"SPEC_"));assert(~isempty(spec),'inkprof:Measurement','Spectral readings are required.');
numcols=find(ismember(t.fields,["XYZ_X","XYZ_Y","XYZ_Z"])|startsWith(t.fields,"SPEC_"));
[~,idcol]=ismember("SAMPLE_ID",t.fields);[~,loccol]=ismember("SAMPLE_LOC",t.fields);
original=plan.originalChartIndex(raw.chartIndex);phase=plan.scanNumber(raw.chartIndex);
output=strings(numel(real),numel(t.fields));pairs=zeros(numel(real),2);rms=zeros(numel(real),1);
for k=1:numel(real)
    i=real(k);a=find(original==i&phase==1);b=find(original==i&phase==2);
    assert(isscalar(a)&&isscalar(b),'inkprof:Identity','Missing or duplicate paired reading.');
    pairs(k,:)=[a b];output(k,:)=t.data(a,:);
    output(k,idcol)=string(p(i).sampleId);output(k,loccol)=string(p(i).sampleLoc);
    [~,rgbcols]=ismember(["RGB_R","RGB_G","RGB_B"],t.fields);
    assert(max(abs(str2double(t.data(a,rgbcols))-str2double(t.data(b,rgbcols))))<=1e-4, ...
       'inkprof:Identity','Paired RGB values disagree.');
    va=str2double(t.data(a,numcols));vb=str2double(t.data(b,numcols));
    output(k,numcols)=compose('%.12g',(va+vb)/2);
    delta=str2double(t.data(a,spec))-str2double(t.data(b,spec));rms(k)=sqrt(mean(delta.^2));
end
t.data=output;
for k=1:numel(t.metadata)
    token=t.metadata{k};if token(1)=="ORIGINATOR",token(2)="InkProf paired spectral mean";end;t.metadata{k}=token;
end
t.metadata{end+1}=["KEYWORD","INKPROF_AVERAGING"];
t.metadata{end+1}=["INKPROF_AVERAGING","Two readings per patch; equal-weight spectral and XYZ mean"];
doc.tables(1)=t;meanPath=fullfile(folder,'chart-mean.ti3');inkprof.exportCgats(meanPath,doc);
provenance=struct('method',"arithmetic mean; equal weights; spectral bands and linear XYZ; no Lab averaging", ...
 'rawTI3',"paired/chart.ti3",'rawTI3SHA256',raw.sourceTI3SHA256, ...
 'rawChartJSONSHA256',raw.chartJSONSHA256,'rawMeasurement',raw, ...
 'pairRows',pairs,'originalChartIndex',real(:),'weights',[.5 .5], ...
 'spectralRmsDifference',rms,'spectralDifferenceUnit',"original TI3 spectral units", ...
 'directionVerified',false,'directionNote',"Directions are instructed by the UI; no independent motion sensor verification");
% Compute diagnostics before publishing the immutable mean measurement JSON.
probe=struct('pairedReadings',provenance,'data',struct('locations',string({p(real).sampleLoc})'));
provenance.directionComparison=inkprof.internal.checkPairedReadings(probe,threshold);
result=inkprof.importChartMeasurement(folder,meanPath,PairedReadings=provenance);
end
