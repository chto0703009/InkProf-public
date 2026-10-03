% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function folder=combineProfileInputs(folders,destination,name)
% Preserve validated source packages and namespace IDs in a training-only TI3.
folders=string(folders(:));folder=string(destination);mkdir(folder);
records=cell(numel(folders),1);sources=cell(numel(folders),1);mapping=struct('id',{},'location',{},'sourceInput',{},'sourceId',{},'sourceLocation',{},'sourceDataRow',{});data=strings(0,0);
for k=1:numel(folders)
 r=jsondecode(fileread(fullfile(folders(k),'profile-input.json')));records{k}=r;
 files=["measurement.json","chart.json","source.ti3","profiling.ti3"];
 keys=["measurementSHA256","chartJSONSHA256","sourceTI3SHA256","profilingTI3SHA256"];
 for j=1:numel(files)
  assert(inkprof.internal.sha256(fullfile(folders(k),files(j)))==string(r.(keys(j))),'inkprof:Integrity','Locked source changed.');
 end
 if k>1
  assert(string(r.measurementCondition.interpreted)==string(records{1}.measurementCondition.interpreted), ...
   'inkprof:IterationCondition','Cannot combine different measurement conditions.');
 end
 assert(string(r.measurementCondition.interpreted)~="unknown",'inkprof:IterationCondition','Known measurement condition required.');
 snapshot="sources/input-"+k;copyfile(folders(k),fullfile(folder,snapshot));
 sources{k}=struct('folder',snapshot,'profileInputSHA256',inkprof.internal.sha256(fullfile(folder,snapshot,'profile-input.json')),'patchCount',r.patchCount);
 d=inkprof.importCgats(fullfile(folders(k),'profiling.ti3'));v=inkprof.cgatsData(d,RGBScale=100);
 if k==1
  doc=d;fields=d.tables.fields;waves=v.wavelengthNm;data=strings(0,numel(fields));
 else
  assert(isequal(waves,v.wavelengthNm)&&numel(fields)==numel(d.tables.fields)&&all(ismember(fields,d.tables.fields)), ...
   'inkprof:IterationSchema','Source TI3 schemas or wavelength grids differ; explicit normalization is required.');
 end
 [~,order]=ismember(fields,d.tables.fields);rows=d.tables.data(:,order);
 for j=1:size(rows,1)
  id="input"+k+"-"+v.ids(j);loc="input"+k+"-"+v.locations(j);
  rows(j,fields=="SAMPLE_ID")=id;rows(j,fields=="SAMPLE_LOC")=loc;
  mapping(end+1)=struct('id',id,'location',loc,'sourceInput',k,'sourceId',v.ids(j),'sourceLocation',v.locations(j),'sourceDataRow',r.sourceDataRows(j)); %#ok<AGROW>
 end
 data=[data;rows]; %#ok<AGROW>
end
doc.tables.data=data;inkprof.exportCgats(fullfile(folder,'profiling.ti3'),doc);copyfile(fullfile(folder,'profiling.ti3'),fullfile(folder,'source.ti3'));
% This is a composite provenance document, never a fabricated physical chart.
provenance=struct('schemaVersion',1,'documentType',"inkprof.profile-training-set",'sources',{sources},'mapping',mapping, ...
 'note',"Synthetic training IDs. Physical coordinates and conditions remain in each source snapshot. No new measurement.");
inkprof.internal.writeJson(fullfile(folder,'measurement.json'),provenance);
inkprof.internal.writeJson(fullfile(folder,'chart.json'),provenance);
r=records{1};r.name=name;r.sourceRevision="measurement.json";r.patchCount=size(data,1);r.sourceDataRows=(1:r.patchCount)';
r.excludedPaddingCount=0;r.excludedRoleCount=0;r.composite=true;r.sourceInputs=sources;
r.measurementSHA256=inkprof.internal.sha256(fullfile(folder,'measurement.json'));
r.chartJSONSHA256=inkprof.internal.sha256(fullfile(folder,'chart.json'));
r.sourceTI3SHA256=inkprof.internal.sha256(fullfile(folder,'source.ti3'));r.profilingTI3SHA256=r.sourceTI3SHA256;
r.layoutEvidence=struct('basis',"Each source validated separately; synthetic training IDs map back to preserved physical charts");
r.rowDirectionCheck=struct('available',false,'basis',"See each validated source input");r.pairedScanQuality=struct;
r.notes=["Print comparability and drift require review across measurement sessions; unknown settings are not inferred.";"Only explicitly selected fitting IDs combined; source snapshots preserve excluded observations."];
inkprof.internal.writeJson(fullfile(folder,'profile-input.json'),r);
end
