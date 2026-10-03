% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function result=analyzeMeasurement(measurementPath,options)
%ANALYZEMEASUREMENT Derive XYZ/Lab from spectra in an immutable measurement JSON.
% SpectralScale is explicit: 100 for percent, 1 for fractional reflectance.
% ReferenceAnalysis optionally compares matched patches using CIEDE2000.
arguments
    measurementPath (1,1) string
    options.SpectralScale (1,1) double = NaN
    options.Illuminant (1,1) string {mustBeMember(options.Illuminant,["D50","D65","A"])} = "D50"
    options.Observer (1,1) string {mustBeMember(options.Observer,["1931_2","1964_10"])} = "1931_2"
    options.ReferenceAnalysis (1,1) string = ""
    options.OutputPath (1,1) string = ""
    options.PythonExecutable (1,1) string = ""
end
assert(isfinite(options.SpectralScale)&&options.SpectralScale>0,'inkprof:Scale', ...
    'Specify SpectralScale=100 for percent or SpectralScale=1 for fractional reflectance.');
measurementPath=inkprof.internal.absolutePath(measurementPath);
assert(isfile(measurementPath),'inkprof:Analysis','Measurement JSON does not exist.');
output=options.OutputPath;
if output==""
    [folder,name]=fileparts(measurementPath);
    output=fullfile(folder,name+"-analysis-"+string(datetime('now','Format','yyyyMMdd-HHmmssSSS'))+".json");
end
output=inkprof.internal.absolutePath(output);
assert(~isfile(output)&&~isfolder(output)&&isfolder(fileparts(output)),'inkprof:Analysis', ...
    'Choose a new output file in an existing directory.');
reference=options.ReferenceAnalysis;
if reference~="",reference=inkprof.internal.absolutePath(reference);end
job=struct('schemaVersion',1,'measurementPath',measurementPath,'outputPath',output, ...
    'spectralScale',options.SpectralScale,'illuminant',options.Illuminant, ...
    'observer',options.Observer,'referenceAnalysisPath',reference);
jobPath=string(tempname)+".json";
cleanup=onCleanup(@()delete(jobPath));
inkprof.internal.writeJson(jobPath,job);
paths=inkprof.paths();
inkprof.runPython(fullfile(paths.Root,'analysis','spectral_analysis.py'),jobPath, ...
    PythonExecutable=options.PythonExecutable,RequiredModules=["numpy","scipy","colour"], ...
    WorkingDirectory=paths.Root);
result=jsondecode(fileread(output));
inkprof.internal.recordProjectStep(output,"analysis-saved");
fprintf('InkProf: spectral analysis saved to %s\n',output);
for k=1:numel(result.warnings),fprintf('InkProf: %s\n',string(result.warnings{k}));end
end
