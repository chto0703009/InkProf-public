% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function condition=measurementCondition(folder,chartHash,metadata)
% Keep requested mode separate from file-reported and inferred conditions.
condition=struct('requested',"unknown",'reported',"unknown",'interpreted',"unknown", ...
    'basis',"No explicit measurement condition established",'fwaApplied',false);
settingsPath=fullfile(folder,'measurement-settings.json');
if isfile(settingsPath)
    settings=jsondecode(fileread(settingsPath));
    assert(string(settings.chartJSONSHA256)==string(chartHash),'inkprof:Integrity','Measurement settings refer to a different chart.');
    condition.requested=string(settings.requestedCondition);
    condition.settings=settings;
    condition.settingsSHA256=inkprof.internal.sha256(settingsPath);
end
instrument="";filter="";explicit="";serial="";
for k=1:numel(metadata)
    tokens=string(metadata{k});
    if numel(tokens)<2,continue;end
    if tokens(1)=="TARGET_INSTRUMENT",instrument=tokens(2);end
    if tokens(1)=="INSTRUMENT_FILTER",filter=tokens(2);end
    if tokens(1)=="INKPROF_MEASUREMENT_CONDITION",explicit=tokens(2);end
    if tokens(1)=="INKPROF_INSTRUMENT_SERIAL",serial=tokens(2);end
end
logs=dir(fullfile(folder,'transcript-*.txt'));
if numel(logs)==1
 path=fullfile(folder,logs(1).name);text=fileread(path);
 token=regexp(text,'Serial Number:\s*([^\s]+)','tokens','once');
 if ~isempty(token)
  assert(serial==""||serial==string(token{1}),'inkprof:Instrument','Conflicting instrument serial numbers.');
  serial=string(token{1});condition.transcriptSHA256=inkprof.internal.sha256(path);
 end
end
condition.instrument=instrument;condition.instrumentFilter=filter;
if filter=="UVCUT"
    condition.reported="M2";condition.interpreted="M2";condition.basis="TI3 INSTRUMENT_FILTER UVCUT";
elseif instrument=="X-Rite i1 Pro 2" && filter==""
    logs=dir(fullfile(folder,'transcript-*.txt'));
    % Only use the single transcript of a new GUI session; never guess among runs.
    if numel(logs)==1
        path=fullfile(folder,logs(1).name);text=fileread(path);
        if ~isempty(regexp(text,'U\.V\. filter\s*\?:\s*No','once'))
            condition.interpreted="M0";
            condition.basis="Inferred: Argyll i1Pro 2 native reflection mode and log reports no UV filter; TI3 has no explicit M-condition";
            condition.transcriptSHA256=inkprof.internal.sha256(path);
        end
    end
end
if explicit~=""
 assert(any(explicit==["M0","M1","M2"]),'inkprof:Condition','Invalid declared measurement condition.');
 assert(condition.reported=="unknown"||condition.reported==explicit,'inkprof:Condition','Conflicting measurement condition metadata.');
 condition.reported=explicit;condition.interpreted=explicit;
 condition.basis="TI3 INKPROF_MEASUREMENT_CONDITION metadata";
end
if serial~="",condition.instrumentSerial=serial;end
condition.requestMatchesInterpretation=condition.requested==condition.interpreted;
end
