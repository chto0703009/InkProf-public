% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function checkpoint=measurementCheckpoint(folder,confirmed)
% Save an immutable raw snapshot, or validate a saved checkpoint.
file=fullfile(folder,'measurement-checkpoint.json');
if nargin==1
 checkpoint=jsondecode(fileread(file));
 assert(string(checkpoint.documentType)=="inkprof.measurement-checkpoint",'inkprof:Checkpoint','Unsupported checkpoint.');
 assert(inkprof.internal.sha256(fullfile(folder,'chart.json'))==string(checkpoint.chartSHA256), ...
  'inkprof:Integrity','Checkpoint chart changed.');
 assert(inkprof.internal.sha256(fullfile(folder,'measurement-settings.json'))==string(checkpoint.settingsSHA256), ...
  'inkprof:Integrity','Checkpoint settings changed.');
 runtime=folder;if string(checkpoint.scanMode)=="paired",runtime=fullfile(folder,'paired');end
 assert(inkprof.internal.sha256(fullfile(runtime,'chart.json'))==string(checkpoint.runtimeChartSHA256), ...
  'inkprof:Integrity','Checkpoint scan layout changed.');
 name=string(checkpoint.snapshot);
 assert(~contains(name,'..')&&~contains(name,filesep),'inkprof:Integrity','Invalid checkpoint snapshot name.');
 assert(inkprof.internal.sha256(fullfile(runtime,name))==string(checkpoint.snapshotSHA256), ...
  'inkprof:Integrity','Checkpoint readings changed.');
 return
end
settings=jsondecode(fileread(fullfile(folder,'measurement-settings.json')));
chart=jsondecode(fileread(fullfile(folder,'chart.json')));runtime=folder;total=sum(chart.passesInStrips);
if string(settings.scanMode)=="paired",runtime=fullfile(folder,'paired');total=2*total;end
confirmed=logical(reshape(confirmed,1,[]));assert(numel(confirmed)==total&&any(confirmed),'inkprof:Checkpoint','No completed rows to save.');
if string(settings.scanMode)=="paired"
 assert(all(confirmed(1:2:end)==confirmed(2:2:end)),'inkprof:Checkpoint','Complete both scans of each row before saving.');
end
source=fullfile(runtime,'chart.ti3');assert(isfile(source),'inkprof:Checkpoint','Instrument has not saved its readings.');
name="checkpoint-"+string(java.util.UUID.randomUUID())+".ti3";
% Argyll saves only read patches. Remove scans outside complete saved rows
% from the resume snapshot, retaining the original raw TI3 as evidence.
runtimeChart=jsondecode(fileread(fullfile(runtime,'chart.json')));
labels=string({runtimeChart.patches.sampleLoc});
rows=str2double(regexprep(labels,'[A-Z]+$',''));uniqueRows=unique(rows);
assert(numel(uniqueRows)==total,'inkprof:Checkpoint','Unexpected scan layout.');
allowed=labels(ismember(rows,uniqueRows(confirmed)));
doc=inkprof.importCgats(source);t=doc.tables(1);column=find(t.fields=="SAMPLE_LOC");
assert(isscalar(column),'inkprof:Checkpoint','Saved readings lack patch locations.');
t.data=t.data(ismember(t.data(:,column),allowed),:);doc.tables(1)=t;
assert(~isempty(t.data),'inkprof:Checkpoint','No completed row readings in saved file.');
inkprof.exportCgats(fullfile(runtime,name),doc);
checkpoint=struct('documentType',"inkprof.measurement-checkpoint",'schemaVersion',1, ...
 'chartSHA256',inkprof.internal.sha256(fullfile(folder,'chart.json')), ...
 'settingsSHA256',inkprof.internal.sha256(fullfile(folder,'measurement-settings.json')), ...
 'runtimeChartSHA256',inkprof.internal.sha256(fullfile(runtime,'chart.json')), ...
 'snapshot',name,'snapshotSHA256',inkprof.internal.sha256(fullfile(runtime,name)), ...
 'scanMode',string(settings.scanMode),'confirmedPasses',find(confirmed), ...
 'totalPasses',total,'complete',all(confirmed),'savedAt',string(datetime('now','TimeZone','UTC')));
inkprof.internal.writeJson(file,checkpoint);
end
