% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function lines=measurementTargetInfo(source,locked)
%MEASUREMENTTARGETINFO Read-only identification of the already selected print.
arguments,source (1,1) string,locked (1,1) logical=false,end
lines="TI2: "+source;
if source=="",lines="No target selected.";return;end
folder=fileparts(source);manifest=fullfile(folder,'manifest.json');target=fullfile(folder,'target.json');
if isfile(target)
 t=jsondecode(fileread(target));
 if isfield(t,'ids'),lines(end+1)="Patches: "+numel(t.ids);end
 if isfield(t,'targetInfo')&&isfield(t.targetInfo,'generation')&&isfield(t.targetInfo.generation,'method')
  lines(end+1)="Target type: "+string(t.targetInfo.generation.method);
 end
end
if isfile(manifest)
 m=jsondecode(fileread(manifest));
 if isfield(m,'pageCount'),lines(end+1)="Printed pages: "+string(m.pageCount);end
 if isfield(m,'createdUTC')
  stamp=string(m.createdUTC);
  try
   dt=datetime(stamp,'InputFormat',"yyyy-MM-dd'T'HH:mm:ss'Z'",'TimeZone','UTC');dt.TimeZone='local';dt.Format='yyyy-MM-dd HH:mm';
   lines(end+1)="Package saved: "+string(dt)+" (local time); UTC: "+stamp;
  catch,lines(end+1)="Package saved (UTC): "+stamp;end
 end
end
if locked,lines(end+1)="Locked to this prepared measurement. To select another print, close and select its target in the workflow first.";end
lines(end+1)="Compare the printed footer path/date with this package. Saved time does not prove when the physical sheet was printed.";
end
