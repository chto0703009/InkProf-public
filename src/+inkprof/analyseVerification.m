function [feedback,feedbackFile]=analyseVerification(reportFile,options)
%ANALYSEVERIFICATION Rank C3 model residuals for iteration; never ISO approval.
arguments
 reportFile (1,1) string = ""
 options.MeanLimit (1,1) double {mustBeFinite,mustBePositive} = 2.5
 options.PatchLimit (1,1) double {mustBeFinite,mustBePositive} = 5
 options.GrayLimit (1,1) double {mustBeFinite,mustBePositive} = 2
 options.ModelTolerance (1,1) double {mustBeFinite,mustBePositive} = 1
 options.RepeatLimit (1,1) double {mustBeFinite,mustBePositive} = 1
 options.GrayWeight (1,1) double {mustBeFinite,mustBePositive} = 2
 options.MaxPriorityPatches (1,1) double {mustBeFinite,mustBePositive,mustBeInteger} = 20
end
feedback=[];feedbackFile="";
if reportFile==""
 [f,p]=uigetfile('*.json','Select C3 verification-check.json');
 if isequal(f,0),return;end;reportFile=fullfile(p,f);
end
reportFile=inkprof.internal.absolutePath(reportFile);
paths=inkprof.paths();w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
inkprof.internal.writeJson(fullfile(w,'parameters.json'),options);
inkprof.runPython(fullfile(paths.Root,'analysis','verification_feedback.py'), ...
 [reportFile,fullfile(w,'result'),"--parameters",fullfile(w,'parameters.json')],RequiredModules=["numpy","colour"]);
folder=fullfile(fileparts(reportFile),'feedback',string(java.util.UUID.randomUUID()));
mkdir(fileparts(folder));[ok,msg]=movefile(fullfile(w,'result'),folder);assert(ok,'inkprof:IO','%s',msg);
feedbackFile=fullfile(folder,'iteration-feedback.json');feedback=jsondecode(fileread(feedbackFile));
inkprof.internal.recordProjectStep(folder,"C3 iteration feedback; diagnostic priorities, no ISO or profile approval");
fprintf('InkProf: %d iteration priorities; repeatability %s. No ISO approval.\nFeedback: %s\n',numel(feedback.priorities),feedback.repeatability.status,feedbackFile);
end
