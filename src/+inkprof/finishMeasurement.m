function result=finishMeasurement(run)
%FINISHMEASUREMENT Validate and import the immutable result of one terminal run.
% A partial chart remains complete=false. No implicit import of old chart.ti3.
arguments
    run (1,1) struct
end
assert(isfield(run,'record'),'inkprof:Input','Expected a run from startMeasurement.');
record=jsondecode(fileread(run.record));
assert(string(record.documentType)=="inkprof.terminal-measurement"&&record.schemaVersion==1, ...
    'inkprof:Measurement','Unsupported measurement result record.');
assert(string(record.status)=="saved_unvalidated",'inkprof:Measurement', ...
    'Measurement is not ready for import (status: %s). Save and finish in Terminal first.',record.status);
folder=string(record.folder);
assert(inkprof.internal.sha256(fullfile(folder,'chart.json'))==string(record.chartJSONSHA256), ...
    'inkprof:Integrity','Chart JSON changed during measurement.');
assert(inkprof.internal.sha256(record.resultTI3)==string(record.resultSHA256), ...
    'inkprof:Integrity','Saved measurement snapshot changed.');
result=inkprof.importChartMeasurement(folder,string(record.resultTI3));
fprintf('InkProf: mätdata importerade. Alla källpatchar finns: %d.\n',result.complete);
end
