% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [result,outputFile]=acceptPatchRemeasurement(measurementFile,candidateFile)
%ACCEPTPATCHREMEASUREMENT Explicitly accept one spot value as a new immutable revision.
arguments
 measurementFile (1,1) string
 candidateFile (1,1) string
end
measurementFile=inkprof.internal.absolutePath(measurementFile);candidateFile=inkprof.internal.absolutePath(candidateFile);
result=jsondecode(fileread(measurementFile));c=jsondecode(fileread(candidateFile));q=c.request;
assert(string(c.documentType)=="inkprof.spot-candidate"&&c.schemaVersion==1,'inkprof:Input','Invalid candidate.');
assert(string(q.parentMeasurementSHA256)==inkprof.internal.sha256(measurementFile),'inkprof:Integrity','Original measurement changed.');
requestFile=fullfile(fileparts(candidateFile),'request.json');
assert(isequaln(jsondecode(fileread(requestFile)),q),'inkprof:Integrity','Candidate/request mismatch.');
assert(~isfile(fullfile(fileparts(candidateFile),'decision.json')),'inkprof:Exists','This attempt already has a decision.');
assert(string(result.measurementCondition.interpreted)=="M0"&&~result.measurementCondition.fwaApplied&&startsWith(string(c.measurementCondition),'M0'),'inkprof:Condition','M-condition mismatch.');
assert(string(c.calibrationStandard)==string(q.calibrationStandard)&&c.spectralScale==100&&string(c.illuminant)=="D50"&&string(c.observer)=="1931_2",'inkprof:Condition','Spectral/colour convention mismatch.');
if isfield(q,'instrumentSerial')&&strlength(string(q.instrumentSerial))>0
 assert(string(c.instrumentSerial)==string(q.instrumentSerial),'inkprof:Instrument','Instrument serial differs.');
end
m=q.measurementIndex;
assert(isscalar(m)&&m==fix(m)&&m>=1&&m<=numel(result.chartIndex),'inkprof:Identity','Invalid patch index.');
assert(string(result.data.ids(m))==string(q.sampleId)&&string(result.data.locations(m))==string(q.sampleLoc)&&result.chartIndex(m)==q.chartIndex&&isequal(reshape(result.data.rgbPercent(m,:),1,[]),reshape(q.rgbPercent,1,[])),'inkprof:Identity','Patch identity mismatch.');
assert(isequal(double(result.data.wavelengthNm(:)),double(c.wavelengthNm(:))),'inkprof:Spectrum','Wavelength grid differs; replacement rejected.');
assert(numel(c.spectra)==numel(c.wavelengthNm)&&numel(c.xyz)==3&&numel(c.lab)==3&&all(isfinite([c.spectra(:);c.xyz(:);c.lab(:)])),'inkprof:Spectrum','Incomplete or non-finite candidate.');
folder=fileparts(measurementFile);chartFile=fullfile(folder,'chart.json');
assert(string(q.chartJSONSHA256)==string(result.chartJSONSHA256)&&inkprof.internal.sha256(chartFile)==string(q.chartJSONSHA256),'inkprof:Integrity','Chart changed.');
% Resolve by content hash, so moved project directories remain usable.
files=dir(fullfile(folder,'*.ti3'));source="";
for f=reshape(files,1,[])
 path=fullfile(folder,f.name);if inkprof.internal.sha256(path)==string(result.sourceTI3SHA256),source=path;break;end
end
assert(strlength(source)>0,'inkprof:Integrity','Original TI3 snapshot could not be verified.');
doc=inkprof.importCgats(source);assert(numel(doc.tables)==1,'inkprof:Input','Expected one measurement table.');
t=doc.tables;fields=string(t.fields);ids=t.data(:,fields=="SAMPLE_ID");loc=t.data(:,fields=="SAMPLE_LOC");row=find(ids==string(q.sampleId)&loc==string(q.sampleLoc));
assert(isscalar(row),'inkprof:Identity','TI3 patch is not unique.');
for j=1:numel(t.metadata)
 tokens=string(t.metadata{j});
 if tokens(1)=="DEVCALSTD",assert(tokens(2)==string(c.calibrationStandard),'inkprof:Condition','Calibration standard differs.');end
end
xyzFields=["XYZ_X","XYZ_Y","XYZ_Z"];
for j=1:3
 col=find(fields==xyzFields(j));assert(isscalar(col),'inkprof:Input','Missing XYZ field.');
 assert(abs(str2double(t.data(row,col))-result.data.xyz(m,j))<1e-8,'inkprof:Integrity','TI3 and JSON XYZ differ.');
 t.data(row,col)=compose('%.17g',c.xyz(j));
end
spec=find(startsWith(fields,'SPEC_'));
assert(numel(spec)==numel(c.spectra),'inkprof:Spectrum','TI3 spectral bands differ.');
assert(all(abs(str2double(t.data(row,spec))-reshape(result.data.spectra(m,:),1,[]))<1e-8),'inkprof:Integrity','TI3 and JSON spectra differ.');
t.data(row,spec)=compose('%.17g',reshape(c.spectra,1,[]));
labFields=["LAB_L","LAB_A","LAB_B"];
for j=1:3,col=find(fields==labFields(j));if ~isempty(col),t.data(row,col)=compose('%.17g',c.lab(j));end,end
% Preserve historical averaging statement, but explicitly identify the override.
t.metadata{end+1}=["KEYWORD","INKPROF_SPOT_OVERRIDE"];
t.metadata{end+1}=["INKPROF_SPOT_OVERRIDE",string(q.coordinate)+" replaced by accepted spot measurement; original scans retained in JSON provenance"];
doc.tables=t;
record=struct('coordinate',q.coordinate,'sampleId',q.sampleId,'sampleLoc',q.sampleLoc, ...
 'parentMeasurementSHA256',q.parentMeasurementSHA256,'candidateSHA256',inkprof.internal.sha256(candidateFile), ...
 'candidateFile',candidateFile,'previousXYZ',result.data.xyz(m,:),'previousSpectrum',result.data.spectra(m,:), ...
 'xyz',reshape(c.xyz,1,[]),'spectra',reshape(c.spectra,1,[]),'instrumentSerial',c.instrumentSerial, ...
 'condition',c.measurementCondition,'method','Accepted spot replaces final value; not included as a third paired reading');
if isfield(result,'patchOverrides'),result.patchOverrides(end+1)=record;else,result.patchOverrides=record;end
result.parentMeasurementSHA256=q.parentMeasurementSHA256;
result.data.xyz(m,:)=reshape(c.xyz,1,[]);result.data.spectra(m,:)=reshape(c.spectra,1,[]);
if ~isempty(result.data.lab),result.data.lab(m,:)=reshape(c.lab,1,[]);end
if ~isempty(result.data.xyz100),result.data.xyz100(m,:)=reshape(c.xyz,1,[]);end
if ~isempty(result.data.spectralFraction),result.data.spectralFraction(m,:)=reshape(c.spectra,1,[])/100;end
base="measurement-"+string(datetime('now','Format','yyyyMMdd-HHmmssSSS'))+"-spot-"+string(java.util.UUID.randomUUID());
outputFile=fullfile(folder,base+".json");ti3=fullfile(folder,base+".ti3");
inkprof.exportCgats(ti3,doc);
result.sourcePath=ti3;result.sourceTI3SHA256=inkprof.internal.sha256(ti3);result.metadata=t.metadata;result.data.metadata=t.metadata;
result.rowDirectionCheck=inkprof.internal.checkRowDirection(folder,result);
inkprof.internal.writeJson(outputFile,result);
inkprof.internal.writeJson(fullfile(fileparts(candidateFile),'decision.json'),struct('decision','accepted','measurementFile',outputFile,'measurementSHA256',inkprof.internal.sha256(outputFile),'candidateSHA256',record.candidateSHA256));
inkprof.internal.recordProjectStep(folder,'Accepted single-patch replacement; retained parent measurement and raw scans');
end
