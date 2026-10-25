% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [report,file]=reviewMeasuredDensity(job,options)
% Review measured Lab density, with an optional separately built trial.
arguments
 job (1,1) string
 options.Parent = []
 options.FitReportFile (1,1) string = ""
 options.LabRadius (1,1) double {mustBePositive,mustBeFinite} = 1
 options.TargetPerGroup (1,1) double {mustBePositive,mustBeInteger} = 4
 options.RepeatLimit (1,1) double {mustBePositive,mustBeFinite} = 1
 options.ShowDialog (1,1) logical = true
 options.DevelopmentMeasurement (1,1) string = ""
 options.DevelopmentIds (:,1) string = strings(0,1)
end
job=inkprof.internal.absolutePath(job);status=jsondecode(fileread(fullfile(job,'status.json')));
assert(string(status.status)=="succeeded"&&inkprof.internal.sha256(fullfile(job,'result','profile.icc'))==string(status.profileSHA256)&& ...
 inkprof.internal.sha256(fullfile(job,'engine.ti3'))==string(status.engineTI3SHA256),'inkprof:Integrity','Source job changed.');
progress=[];if options.ShowDialog
 parent=options.Parent;if isempty(parent),parents=findall(groot,'Type','figure','Tag','InkProfWorkflow');if ~isempty(parents),parent=parents(1);end,end
 progress=inkprof.internal.calculationProgress("Measured Lab density","Checking measured training colours, repeated RGB and conservative trial selection.",Parent=parent);
end %#ok<NASGU>
fitFile=options.FitReportFile;if fitFile=="",[~,fitFile]=inkprof.checkProfileFit(job,ShowDialog=false);end
folder=fullfile(job,'checks',string(java.util.UUID.randomUUID()));mkdir(folder);
request=struct('fitReport',fitFile,'fitReportSHA256',inkprof.internal.sha256(fitFile),'profileSHA256',status.profileSHA256, ...
 'sourceTI3SHA256',status.engineTI3SHA256,'radius',options.LabRadius,'cap',options.TargetPerGroup,'repeatLimit',options.RepeatLimit);
inkprof.internal.writeJson(fullfile(folder,'request.json'),request);paths=inkprof.paths();file=fullfile(folder,'measurement-density.json');
inkprof.runPython(fullfile(paths.Root,'analysis','measurement_density.py'),[fullfile(folder,'request.json'),file],RequiredModules=["numpy","scipy","colour"]);
report=jsondecode(fileread(file));inkprof.internal.recordProjectStep(folder,"Measured Lab density and repeat review; source measurements unchanged");
clear progress;
if ~options.ShowDialog,return;end
inkprof.internal.showMeasuredDensity(report,job,file,options);
end
