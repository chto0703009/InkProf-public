% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [result,outputFile]=acceptRowRemeasurement(measurementFile,candidateFile,requestFile)
%ACCEPTROWREMEASUREMENT Replace one whole row in a new immutable revision.
arguments
 measurementFile (1,1) string
 candidateFile (1,1) string
 requestFile (1,1) string
end
measurementFile=inkprof.internal.absolutePath(measurementFile);candidateFile=inkprof.internal.absolutePath(candidateFile);
requestFile=inkprof.internal.absolutePath(requestFile);q=jsondecode(fileread(requestFile));
result=jsondecode(fileread(measurementFile));c=jsondecode(fileread(candidateFile));base=fileparts(measurementFile);
assert(string(q.documentType)=="inkprof.row-request"&&q.schemaVersion==1&&string(c.documentType)=="inkprof.chart-measurement",'inkprof:Input','Invalid row request or candidate.');
assert(inkprof.internal.sha256(measurementFile)==string(q.parentMeasurementSHA256),'inkprof:Integrity','Parent measurement changed.');
assert(~isfile(fullfile(fileparts(requestFile),'decision.json')),'inkprof:Exists','This row attempt already has a decision.');
chartFile=fullfile(base,'chart.json');chart=jsondecode(fileread(chartFile));
assert(inkprof.internal.sha256(chartFile)==string(q.chartJSONSHA256)&&string(result.chartJSONSHA256)==string(q.chartJSONSHA256),'inkprof:Integrity','Original chart changed.');
runtimeChart=fullfile(fileparts(candidateFile),'chart.json');
assert(inkprof.internal.sha256(runtimeChart)==string(q.runtimeChartSHA256)&&string(c.chartJSONSHA256)==string(q.runtimeChartSHA256)&&c.complete,'inkprof:Integrity','Candidate chart differs or row is incomplete.');
% Re-derive the physical row, rather than trusting editable request indices.
labels=strings(numel(chart.patches),1);
for k=1:numel(labels),labels(k)=inkprof.internal.decodeLocation(chart.patches(k).sampleLoc);end
allRows=unique(str2double(labels),'sorted');ordinal=find(allRows==str2double(q.row));
assert(isscalar(ordinal),'inkprof:Identity','Invalid row.');info=inkprof.internal.measurementPage(chart,ordinal);
indices=double(q.chartIndices(:));
assert(info.page==q.page&&isequal(sort(indices),find(labels==string(q.row))),'inkprof:Identity','Row/page mapping differs.');
oldCondition=result.measurementCondition;newCondition=c.measurementCondition;
assert(isequaln(q.settings,oldCondition.settings),'inkprof:Settings','Original settings changed in request.');
assert(~oldCondition.fwaApplied&&~newCondition.fwaApplied&&string(oldCondition.interpreted)==string(newCondition.interpreted)&& ...
 string(oldCondition.requested)==string(newCondition.requested),'inkprof:Condition','Measurement conditions differ.');
for key=["instrument","instrumentFilter","instrumentSerial"]
 if isfield(oldCondition,key)&&strlength(string(oldCondition.(key)))>0
  assert(isfield(newCondition,key)&&string(oldCondition.(key))==string(newCondition.(key)),'inkprof:Instrument','Instrument identity or filter differs.');
 end
end
assert(isfield(newCondition,'settings')&&string(newCondition.settings.scanMode)==string(q.settings.scanMode)&& ...
 string(q.settings.scanMode)==string(oldCondition.settings.scanMode),'inkprof:Settings','Scan mode differs from original.');
for key=["requestedCondition","scanTolerance","port"]
 assert(isfield(newCondition.settings,key)&&isequal(newCondition.settings.(key),q.settings.(key)),'inkprof:Settings','Measurement settings differ.');
end
if string(q.settings.scanMode)=="paired",assert(isfield(c,'pairedReadings'),'inkprof:Measurement','Forward/reverse readings are required.');end
assert(isequal(double(result.data.wavelengthNm(:)),double(c.data.wavelengthNm(:))),'inkprof:Spectrum','Wavelength grids differ.');
% Locate immutable input snapshots by hash, supporting moved project folders.
source=findTI3(base,result.sourceTI3SHA256);newSource=findTI3(fileparts(candidateFile),c.sourceTI3SHA256);
doc=inkprof.importCgats(source);newDoc=inkprof.importCgats(newSource);t=doc.tables(1);nt=newDoc.tables(1);
assert(numel(doc.tables)==1&&numel(newDoc.tables)==1,'inkprof:Input','Expected one measurement table.');
assert(standard(t)==standard(nt)&&standard(t)~="",'inkprof:Condition','Calibration standards differ or are unavailable.');
colourFields=["XYZ_X","XYZ_Y","XYZ_Z",string(t.fields(startsWith(t.fields,'SPEC_'))),string(t.fields(startsWith(t.fields,'LAB_')))];
[hasOld,oldCols]=ismember(colourFields,t.fields);[hasNew,newCols]=ismember(colourFields,nt.fields);
assert(all(hasOld&hasNew),'inkprof:Spectrum','Candidate colour fields differ.');
records=struct('chartIndex',{},'sampleId',{},'sampleLoc',{},'previousXYZ',{},'xyz',{});
real=indices(~[chart.patches(indices).isPadding]);
assert(sum(string(c.data.ids)~="0")==numel(real),'inkprof:Identity','Unexpected number of row readings.');
for k=1:numel(real)
 i=real(k);local=find(indices==i);m=find(result.chartIndex==i);a=find(c.chartIndex==local);
 assert(isscalar(m)&&isscalar(a),'inkprof:Identity','Missing or duplicate row patch.');
 p=chart.patches(i);[~,column]=inkprof.internal.decodeLocation(p.sampleLoc);
 assert(string(c.data.ids(a))==string(p.sampleId)&&string(c.data.locations(a))=="1"+column&& ...
  max(abs(c.data.rgbPercent(a,:)-double(p.rgbPercent(:)')))<1e-4,'inkprof:Identity','Candidate patch identity differs.');
 oldRow=find(t.data(:,t.fields=="SAMPLE_ID")==string(p.sampleId)&t.data(:,t.fields=="SAMPLE_LOC")==string(p.sampleLoc));
 newRow=find(nt.data(:,nt.fields=="SAMPLE_ID")==string(p.sampleId)&nt.data(:,nt.fields=="SAMPLE_LOC")=="1"+column);
 assert(isscalar(oldRow)&&isscalar(newRow),'inkprof:Identity','TI3 patch identity is not unique.');
 values=str2double(nt.data(newRow,newCols));assert(all(isfinite(values)),'inkprof:Measurement','Non-finite row reading.');
 [~,xyzCols]=ismember(["XYZ_X","XYZ_Y","XYZ_Z"],nt.fields);
 spec=find(startsWith(nt.fields,'SPEC_'));
 assert(max(abs(str2double(nt.data(newRow,xyzCols))-c.data.xyz(a,:)))<1e-8&& ...
  max(abs(str2double(nt.data(newRow,spec))-c.data.spectra(a,:)))<1e-8,'inkprof:Integrity','Candidate JSON and TI3 disagree.');
 [~,oldXYZ]=ismember(["XYZ_X","XYZ_Y","XYZ_Z"],t.fields);oldSpec=find(startsWith(t.fields,'SPEC_'));
 assert(max(abs(str2double(t.data(oldRow,oldXYZ))-result.data.xyz(m,:)))<1e-8&& ...
  max(abs(str2double(t.data(oldRow,oldSpec))-result.data.spectra(m,:)))<1e-8,'inkprof:Integrity','Parent JSON and TI3 disagree.');
 records(k)=struct('chartIndex',i,'sampleId',p.sampleId,'sampleLoc',p.sampleLoc,'previousXYZ',result.data.xyz(m,:),'xyz',c.data.xyz(a,:));
 t.data(oldRow,oldCols)=nt.data(newRow,newCols);
 for key=["xyz","xyz100","spectra","spectralFraction","lab"]
  if ~isempty(result.data.(key))
   assert(size(c.data.(key),2)==size(result.data.(key),2)&&size(c.data.(key),1)>=a,'inkprof:Measurement','Missing replacement data.');
   result.data.(key)(m,:)=c.data.(key)(a,:);
  end
 end
end
record=struct('page',q.page,'row',q.row,'scanMode',q.settings.scanMode,'chartIndices',real(:), ...
 'parentMeasurementSHA256',q.parentMeasurementSHA256,'candidateFile',candidateFile,'candidateSHA256',inkprof.internal.sha256(candidateFile), ...
 'requestSHA256',inkprof.internal.sha256(requestFile),'patches',records,'directionComparison',struct);
if isfield(c,'pairedReadings'),record.directionComparison=c.pairedReadings.directionComparison;end
if isfield(result,'rowOverrides')
 keep=~(double([result.rowOverrides.page])==q.page&string({result.rowOverrides.row})==string(q.row));
 result.rowOverrides=result.rowOverrides(keep);result.rowOverrides(end+1)=record;
else,result.rowOverrides=record;end
% Current spot values on this row are superseded; older revisions retain them.
if isfield(result,'patchOverrides')
 loc=string({chart.patches(real).sampleLoc});result.patchOverrides=result.patchOverrides(~ismember(string({result.patchOverrides.sampleLoc}),loc));
 if isempty(result.patchOverrides),result=rmfield(result,'patchOverrides');end
end
t.metadata{end+1}=["KEYWORD","INKPROF_ROW_OVERRIDE"];
t.metadata{end+1}=["INKPROF_ROW_OVERRIDE",sprintf('Page %d row %s replaced by accepted %s scans; original readings retained in parent revision',q.page,q.row,q.settings.scanMode)];
doc.tables=t;
name="measurement-"+string(datetime('now','Format','yyyyMMdd-HHmmssSSS'))+"-row-"+string(java.util.UUID.randomUUID());
ti3=fullfile(base,name+".ti3");outputFile=fullfile(base,name+".json");inkprof.exportCgats(ti3,doc);
result.parentMeasurementSHA256=q.parentMeasurementSHA256;result.sourcePath=ti3;result.sourceTI3SHA256=inkprof.internal.sha256(ti3);
result.metadata=t.metadata;result.data.metadata=t.metadata;
result.rowDirectionCheck=inkprof.internal.checkRowDirection(base,result);
inkprof.internal.writeJson(outputFile,result);
inkprof.internal.writeJson(fullfile(fileparts(requestFile),'decision.json'),struct('decision',"accepted",'measurementFile',outputFile, ...
 'measurementSHA256',inkprof.internal.sha256(outputFile),'candidateSHA256',record.candidateSHA256));
inkprof.internal.recordProjectStep(base,"Accepted page "+q.page+" row "+string(q.row)+" as a new measurement revision");
end
function file=findTI3(folder,hash)
file="";files=dir(fullfile(folder,'*.ti3'));
for entry=reshape(files,1,[])
 path=fullfile(entry.folder,entry.name);if inkprof.internal.sha256(path)==string(hash),file=path;break;end
end
assert(file~="",'inkprof:Integrity','TI3 snapshot missing or changed.');
end
function value=standard(t)
value="";
for k=1:numel(t.metadata),tokens=string(t.metadata{k});if tokens(1)=="DEVCALSTD",value=tokens(2);end,end
end
