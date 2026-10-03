% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function identity=instrumentIdentity(folder,condition)
% Resolve identity only from measurement metadata or its hash-linked transcript.
identity=struct('model',"unknown",'serialNumber',"unknown", ...
 'modelSource',"not recorded",'serialSource',"not recorded",'transcriptSHA256',"", ...
 'calibrationVerified',false);
if isfield(condition,'instrument')&&strlength(string(condition.instrument))>0
 identity.model=string(condition.instrument);identity.modelSource="measurementCondition.instrument";
end
if isfield(condition,'instrumentSerial')&&strlength(string(condition.instrumentSerial))>0
 identity.serialNumber=string(condition.instrumentSerial);identity.serialSource="measurementCondition.instrumentSerial";
end
if isfield(condition,'transcriptSHA256')
 logs=dir(fullfile(folder,'**','transcript-*.txt'));
 for entry=reshape(logs,1,[])
  path=fullfile(entry.folder,entry.name);
  if inkprof.internal.sha256(path)~=string(condition.transcriptSHA256),continue;end
  identity.transcriptSHA256=string(condition.transcriptSHA256);
  serial=regexp(fileread(path),'Serial Number:\s*([^\s]+)','tokens','once');
  if ~isempty(serial)
   assert(identity.serialNumber=="unknown"||identity.serialNumber==string(serial{1}), ...
    'inkprof:Instrument','Conflicting instrument serial numbers in measurement and transcript.');
   identity.serialNumber=string(serial{1});identity.serialSource="SHA-256 verified instrument transcript";
  end
  break
 end
end
end
