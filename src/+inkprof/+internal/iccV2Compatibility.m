% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function [profile,conversion]=iccV2Compatibility(source,folder,options)
arguments
 source (1,1) string
 folder (1,1) string
 options.ArgyllBin (1,1) string = ""
end
% Consent precedes any reconstruction; the original remains unchanged.
profile=string(source);conversion=struct('converted',false);
f=fopen(source,'rb');assert(f>=0,'inkprof:ICC','Cannot open ICC.');c=onCleanup(@()fclose(f));h=fread(f,128,'*uint8');clear c
assert(numel(h)==128,'inkprof:ICC','Incomplete ICC header.');
if h(9)==2,return;end
assert(h(9)==4,'inkprof:ICC','Only ICC v2/v4 are supported.');
message=sprintf(['This is an ICC v4 profile. Argyll requires a v2 compatibility copy.\n\n' ...
 'InkProf will preserve the original and reconstruct a separate approximate v2 profile. Colours can change; inverse tables and perceptual mapping are rebuilt. Numerical comparison results will be saved.\n\n' ...
 'Choose Cancel to stop this operation, or Create v2 copy to continue.']);
accepted=confirmConversion(message);
if ~accepted,error('inkprof:Cancelled','ICC v4 operation cancelled; no v2 profile selected.');end
progress=inkprof.internal.calculationProgress("Creating ICC v2 compatibility copy","Preserving ICC v4, reconstructing v2 and comparing colours. This may take several minutes."); %#ok<NASGU>
paths=inkprof.paths();bin=inkprof.internal.argyllBin(options.ArgyllBin);suffix="";if ispc,suffix=".exe";end
sourceHash=inkprof.internal.sha256(source);
% Content-addressed common copy makes every caller use identical ICC bytes.
cache=fullfile(paths.Projects,'.icc-v2-cache',sourceHash+"-conversion-v2-bradford");
if isfolder(cache)
 cached=jsondecode(fileread(fullfile(cache,'conversion.json')));
 assert(string(cached.originalSHA256)==sourceHash&& ...
  inkprof.internal.sha256(fullfile(cache,'original-v4.icc'))==sourceHash&& ...
  inkprof.internal.sha256(fullfile(cache,'profile-v2.icc'))==string(cached.convertedSHA256), ...
  'inkprof:Integrity','Cached ICC conversion has changed; no profile selected.');
else
 work=string(tempname);mkdir(work);cleanup=onCleanup(@()rmdir(work,'s'));
 copyfile(source,fullfile(work,'original-v4.icc'));
 inkprof.runPython(fullfile(paths.Root,'profiles','convert_v4_to_v2.py'), ...
  [fullfile(work,'original-v4.icc'),work,fullfile(bin,'colprof'+suffix),fullfile(bin,'xicclu'+suffix)], ...
  RequiredModules=["numpy","colour","PIL"],TimeoutSeconds=1300);
 assert(inkprof.internal.sha256(source)==sourceHash,'inkprof:Integrity','Original ICC changed during conversion.');
 parent=fileparts(cache);if ~isfolder(parent),mkdir(parent);end
 [ok,msg]=copyfile(work,cache);assert(ok,'inkprof:IO','%s',msg);
end
assert(inkprof.internal.sha256(source)==sourceHash,'inkprof:Integrity','Original ICC changed.');
[ok,msg]=copyfile(cache,folder);assert(ok,'inkprof:IO','%s',msg);
profile=fullfile(folder,'profile-v2.icc');conversion=jsondecode(fileread(fullfile(folder,'conversion.json')));conversion.converted=true;
fprintf('InkProf ICC v4 → v2 approximation: absolute mean %.3f, max %.3f; relative mean %.3f, max %.3f dE00. Original preserved.\n', ...
 conversion.validation.absolute.mean,conversion.validation.absolute.max,conversion.validation.relative.mean,conversion.validation.relative.max);
end

function accepted=confirmConversion(message)
accepted=false;dismissed=false;
f=uifigure('Name','ICC v4 compatibility','Tag','InkProfV4Warning','Position',[200 200 650 300],'WindowStyle','alwaysontop');
cleanup=onCleanup(@()closeWindow(f));
g=uigridlayout(f,[2 2]);g.RowHeight={'1x',35};
l=uilabel(g,'Text',message,'WordWrap','on');l.Layout.Column=[1 2];
uibutton(g,'Text','Create v2 copy','Tag','ConfirmV2Conversion','ButtonPushedFcn',@confirm);
uibutton(g,'Text','Cancel','Tag','CancelV2Conversion','ButtonPushedFcn',@cancel);
f.CloseRequestFcn=@cancel;drawnow;if ~dismissed,uiwait(f);end
 function confirm(~,~),accepted=true;dismissed=true;uiresume(f);end
 function cancel(~,~),accepted=false;dismissed=true;uiresume(f);end
end
function closeWindow(f)
if isvalid(f),delete(f);end
end
