function output=exportMeasurementReport(measurementFile,analysisFile,output,options)
%EXPORTMEASUREMENTREPORT Complete PDF with coordinates, colour swatches and XYZ/Lab.
arguments
 measurementFile (1,1) string
 analysisFile (1,1) string
 output (1,1) string
 options.TargetWarningDeltaE (1,1) double {mustBePositive,mustBeFinite} = 20
 options.PythonExecutable (1,1) string = ""
end
measurementFile=inkprof.internal.absolutePath(measurementFile);
analysisFile=inkprof.internal.absolutePath(analysisFile);
output=inkprof.internal.absolutePath(output);
assert(isfile(measurementFile)&&isfile(analysisFile),'inkprof:Report','Input JSON files must exist.');
assert(~isfile(output)&&isfolder(fileparts(output)),'inkprof:Report','Choose a new PDF file in an existing directory.');
paths=inkprof.paths();
inkprof.runPython(fullfile(paths.Root,'analysis','measurement_report.py'), ...
 [measurementFile,analysisFile,output,"--target-warning-threshold",string(options.TargetWarningDeltaE)],PythonExecutable=options.PythonExecutable, ...
 RequiredModules=["numpy","colour","reportlab"],WorkingDirectory=paths.Root);
inkprof.internal.recordProjectStep(output,"report-saved");
fprintf('InkProf: PDF saved to %s\n',output);
end
