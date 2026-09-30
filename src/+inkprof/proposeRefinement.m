function [proposal,folder]=proposeRefinement(jobFolder,measurementFile,options)
%PROPOSEREFINEMENT Suggest new device RGB points from forward-model errors.
% Selected measurements become adaptive development data, not final holdout.
arguments
 jobFolder (1,1) string
 measurementFile (1,1) string
 options.Name (1,1) string = "Local refinement"
 options.MaxNewPatches (1,1) double {mustBeInteger,mustBePositive} = 24
 options.NormTarget (1,1) double {mustBeNonnegative,mustBeFinite} = 1
 options.ErrorThreshold (1,1) double {mustBeNonnegative,mustBeFinite} = 2
 options.RadiusPercent (1,1) double {mustBePositive,mustBeFinite} = 10
 options.MinSpacingPercent (1,1) double {mustBePositive,mustBeFinite} = 1
 options.RepeatLimit (1,1) double {mustBePositive,mustBeFinite} = 1
 options.GrayWeight (1,1) double {mustBePositive,mustBeFinite} = 1
 options.Iteration (1,1) double {mustBePositive,mustBeInteger} = 1
 options.ParentIterationId (1,1) string = ""
 options.UseJacobian (1,1) logical = false
 options.DevelopmentSampleIds (:,1) string = strings(0,1)
 options.ShowDialog (1,1) logical = true
end
jobFolder=inkprof.internal.absolutePath(jobFolder);measurementFile=inkprof.internal.absolutePath(measurementFile);
v=inkprof.cgatsData(inkprof.importCgats(fullfile(jobFolder,'engine.ti3')),RGBScale=100);
assert(~isempty(v.rgb),'inkprof:Refinement','RGB training data required.');
paths=inkprof.paths();bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'profcheck');if ispc,exe=exe+".exe";end
request=struct('jobFolder',jobFolder,'measurementFile',measurementFile,'trainingRGBPercent',v.rgb, ...
 'useJacobian',options.UseJacobian,'xicclu',replace(string(exe),"profcheck","xicclu"), ...
 'measurementRole',"adaptive_validation",'developmentSampleIds',{cellstr(options.DevelopmentSampleIds)},'name',options.Name,'profcheck',exe, ...
 'iteration',options.Iteration,'parentIterationId',options.ParentIterationId, ...
 'parameters',struct('budget',options.MaxNewPatches,'norm_target',options.NormTarget, ...
 'threshold',options.ErrorThreshold,'radius',options.RadiusPercent,'spacing',options.MinSpacingPercent, ...
 'repeat_limit',options.RepeatLimit,'gray_weight',options.GrayWeight));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
inkprof.internal.writeJson(fullfile(w,'request.json'),request);
inkprof.runPython(fullfile(paths.Root,'analysis','refinement.py'),[fullfile(w,'request.json'),fullfile(w,'proposal')], ...
 RequiredModules=["numpy","scipy","colour","PIL"],TimeoutSeconds=180);
parent=fullfile(jobFolder,'refinement');if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,string(java.util.UUID.randomUUID()));[ok,msg]=movefile(fullfile(w,'proposal'),folder);assert(ok,'inkprof:IO','%s',msg);
proposal=jsondecode(fileread(fullfile(folder,'proposal.json')));
inkprof.internal.recordProjectStep(folder,"Forward-error refinement proposal; iteration budget and error norm");
fprintf('InkProf: iteration %d; %d new candidates (maximum %d).\n%s\n',options.Iteration,numel(proposal.candidates),options.MaxNewPatches,folder);
if ~options.ShowDialog,return;end
f=uifigure('Name','InkProf - Refinement proposal','Position',[100 100 1050 650],'WindowStyle','alwaysontop');
g=uigridlayout(f,[4 1]);g.RowHeight={100,'1x',60,40};
value=proposal.errorNorm.value;if isempty(value),normText="unavailable";else,normText=compose('%.3f',value);end
uilabel(g,'Text',sprintf('Iteration %d | Error norm (weighted RMS dE00): %s | Target: %.3f\nNew patches: %d / %d | Stop: %s\nDevelopment proposal. No measurements merged and no profile replaced.',options.Iteration,normText,options.NormTarget,numel(proposal.candidates),options.MaxNewPatches,proposal.stopReason),'WordWrap','on');
c=proposal.candidates;rows=cell(numel(c),5);
for k=1:numel(c),rows(k,:)={c(k).patchId,c(k).rgbPercent(1),c(k).rgbPercent(2),c(k).rgbPercent(3),c(k).score};end
uitable(g,'Data',rows,'ColumnName',{'Patch ID','R %','G %','B %','Priority'},'ColumnWidth',{350,110,110,110,110},'RowName',{});
uilabel(g,'Text',sprintf('Saved: %s\nReview proposal.json for existing measured points suitable for reuse and observations needing remeasurement. Render target.ti1 separately.',folder),'WordWrap','on');
uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));drawnow;focus(f);
end
