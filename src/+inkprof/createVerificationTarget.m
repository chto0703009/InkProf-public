% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [folder,reference]=createVerificationTarget(jobFolder,options)
%CREATEVERIFICATIONTARGET C2: absolute D50 Lab -> profiled RGB16 print package.
arguments
 jobFolder (1,1) string = ""
 options.Name (1,1) string = "C2-absolute-verification"
 options.OutputFolder (1,1) string = ""
 options.ColourPatches (1,1) double {mustBeInteger,mustBePositive} = 80
 options.GrayPatches (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.GrayPatches,2)} = 24
 options.ChallengePatches (1,1) double {mustBeInteger,mustBeNonnegative} = 12
 options.Repeats (1,1) double {mustBeInteger,mustBeNonnegative} = 12
 options.Seed (1,1) double {mustBeInteger,mustBeNonnegative} = 20260928
 options.DPI (1,1) double {mustBeInteger,mustBePositive} = 300
 options.PlanPaper (1,1) logical = false
 options.Paper (1,1) string = "A4-landscape"
 options.MinTrainingRGBDistance (1,1) double {mustBePositive,mustBeFinite} = 1/255
end
folder="";reference=[];
if jobFolder==""
 p=uigetdir(pwd,'Select the ICC job to validate');if isequal(p,0),return;end;jobFolder=string(p);
end
jobFolder=inkprof.internal.absolutePath(jobFolder);
project=inkprof.internal.findProject(jobFolder);assert(project~="",'inkprof:Project','Select a job in an InkProf project.');
status=jsondecode(fileread(fullfile(jobFolder,'status.json')));
assert(string(status.status)=="succeeded",'inkprof:Verification','Select a successful profile job.');
profileFile=fullfile(jobFolder,'result','profile.icc');profileHash=inkprof.internal.sha256(profileFile);
assert(profileHash==string(status.profileSHA256),'inkprof:Integrity','Profile changed.');
source=fullfile(jobFolder,'engine.ti3');
assert(inkprof.internal.sha256(source)==string(status.engineTI3SHA256),'inkprof:Integrity','Training TI3 changed.');
v=inkprof.cgatsData(inkprof.importCgats(source),RGBScale=100);
assert(isempty(v.cmyk)&&size(v.rgb,2)==3,'inkprof:ColorFormat','RGB measurements required.');
folder=options.OutputFolder;
if folder==""
 slug=regexprep(options.Name,'[^a-zA-Z0-9_-]','-');if slug=="",slug="verification";end
 folder=fullfile(project,'verification',slug+"-"+string(java.util.UUID.randomUUID()));
end
folder=inkprof.internal.absolutePath(folder);
assert(~isfile(folder)&&~isfolder(folder),'inkprof:Exists','Output already exists.');
paths=inkprof.paths();bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'xicclu');if ispc,exe=exe+".exe";end
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
request=struct('name',options.Name,'colourPatches',options.ColourPatches,'grayPatches',options.GrayPatches, ...
 'challengePatches',options.ChallengePatches,'repeats',options.Repeats,'seed',options.Seed, ...
 'minTrainingRGBDistance',options.MinTrainingRGBDistance,'trainingRGB',v.rgb/100);
inkprof.internal.writeJson(fullfile(w,'request.json'),request);
fprintf('InkProf C2: selecting new reference colours and applying the profile once (absolute, no BPC)...\n');
inkprof.runPython(fullfile(paths.Root,'analysis','verification_target.py'), ...
 [jobFolder,exe,fullfile(w,'request.json'),fullfile(w,'definition')], ...
 RequiredModules=["numpy","colour","PIL"],TimeoutSeconds=300);
assert(inkprof.internal.sha256(profileFile)==profileHash,'inkprof:Integrity','Profile changed during generation.');
mkdir(folder);[ok,msg]=movefile(fullfile(w,'definition'),fullfile(folder,'definition'));assert(ok,'inkprof:IO','%s',msg);
reference=jsondecode(fileread(fullfile(folder,'definition','verification.json')));
source=fullfile(folder,'definition','verification.ti1');target=inkprof.importTarget(source);
generation=struct('method',"C2 absolute verification - profile applied once",'settings',rmfield(request,'trainingRGB'));
info=inkprof.internal.targetInfo(target.rgbPercent/100,source,generation);
info.verification=struct('reference',"../verification.json",'profileSHA256',profileHash,'profileApplied',true, ...
 'intent',"absolute colorimetric",'bpc',false);
fprintf('InkProf C2: rendering RGB16 TIFF and matching TI2...\n');
manifest=inkprof.createTarget(fullfile(folder,'print'),Source=source,TargetInfo=info, ...
 PlanPaper=options.PlanPaper,Randomize=true,Seed=options.Seed,DPI=options.DPI,Paper=options.Paper,SpacerMode="bw");
layout=jsondecode(fileread(fullfile(folder,'print','layout.json')));
for k=1:numel(reference.patches)
 matches=find(~[layout.patches.isPadding] & string({layout.patches.originalId})==string(reference.patches(k).id));
 assert(numel(matches)==1,'inkprof:Identity','Missing or duplicate verification patch placement.');
 p=layout.patches(matches);
 assert(isequal(double(p.rgb16(:)'),double(reference.patches(k).deviceRGB16(:)')),'inkprof:Identity','Rendered RGB differs from profiled definition.');
 reference.patches(k).placement=struct('page',p.page,'coordinate',p.coordinate,'sampleId',p.sampleId,'location',p.location,'tiff',"print/"+string(p.tiff));
end
reference.status="ready-to-print-not-measured";
reference.sourceProfile.file="definition/source-Lab-D50.icc";reference.printerProfile.file="definition/printer.icc";
reference.definitions.file="definition/verification.ti1";
reference.printPackage=struct('folder',"print",'manifestSHA256',inkprof.internal.sha256(fullfile(folder,'print','manifest.json')), ...
 'ti2',"print/target.ti2",'ti2SHA256',inkprof.internal.sha256(fullfile(folder,'print','target.ti2')), ...
 'pageCount',manifest.pageCount,'dpi',options.DPI,'paper',options.Paper);
reference.profileJob=replace(erase(jobFolder,project+filesep),filesep,"/");
inkprof.internal.writeJson(fullfile(folder,'verification.json'),reference);
fid=fopen(fullfile(folder,'PRINTING.txt'),'w');assert(fid>=0,'inkprof:IO','Cannot write print instructions.');
c=onCleanup(@()fclose(fid));
fprintf(fid,['C2 ABSOLUTE COLORIMETRIC VERIFICATION\nThe printer ICC has ALREADY been applied ONCE to every source patch.\n' ...
 'Print print/target*.tif at 100%% size. Disable application, OS and driver colour conversion. Do NOT apply the ICC again.\n' ...
 'Use the SAME printer, paper, media, quality and driver settings as the profile recipe.\n' ...
 'Reference printing settings are in verification.json; confirm the actual settings before printing.\n' ...
 'No embedded ICC in TIFF: pixels are already printer-device RGB16. Source Lab ICC is provenance, not a profile to assign to the TIFF.\n' ...
 'Measure with print/target.ti2. Preserve verification.json for patch-ID and page/coordinate mapping.\n' ...
 'Compare measurements to referenceLabD50Absolute, NOT predictedLabD50Absolute.\n' ...
 'Separate challenge colours, gray patches and repeats. Ignore padding and contrast bars in the validation score.\n' ...
 'Numerical criteria are awaiting user acceptance; this package does not mark any profile print-validated.\n']);clear c
inkprof.internal.recordProjectStep(folder,"C2 independent verification target rendered; profile applied once; not printed/measured");
fprintf('InkProf C2: %d patches, %d page(s).\nFolder: %s\n',numel(reference.patches),manifest.pageCount,folder);
end
