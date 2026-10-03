% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function file=selectMeasurementRevision(folder,target,options)
%SELECTMEASUREMENTREVISION Choose by saved time and patch count, not UUID.
arguments
 folder (1,1) string
 target (1,1) string
 options.Parent = []
end
calculation=inkprof.internal.calculationProgress("Finding saved measurement revisions","Checking saved revisions and their integrity before displaying the choices.",Parent=options.Parent);
file="";revisions=inkprof.internal.measurementRevisions(folder,target);
clear calculation;
if isempty(revisions)
 uiwait(msgbox('No complete, intact measurement revision for this target was found. Finish and save the measurement, or import an existing measurement file.', ...
  'Measurement revisions','warn','modal'));return
end
[index,accepted]=listdlg('Name','Select measurement revision', ...
 'PromptString',{'Select a saved revision for this target. Latest saved is selected.'; ...
 'Times are local file-save times. Complete means all patches exist; review follows in the next step.'}, ...
 'ListString',cellstr(string({revisions.label})),'SelectionMode','single', ...
 'InitialValue',1,'ListSize',[850 300],'OKString','Use revision','CancelString','Cancel');
if accepted,file=revisions(index).file;end
end
