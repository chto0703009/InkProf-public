% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [results,folder]=comparePreRegularization(inputFolder,options)
%COMPAREPREREGULARIZATION Build one locked B1 input with and without
%pre-regularization and tabulate fit against RAW measurements, change applied
%by the model, high-chroma shift and C1 inverse-ramp gradient diagnostics.
% Numerical comparison only; no profile is selected or approved.
%
%   [T,folder] = inkprof.comparePreRegularization(b1Folder);
%   [T,folder] = inkprof.comparePreRegularization(b1Folder,AvgDev=[0.25 0.5 1]);
%   [T,folder] = inkprof.comparePreRegularization(b1Folder,AvgDev=[],FinalSmoothing=[0.5 1 1.5]);
arguments
 inputFolder (1,1) string
 options.AvgDev (1,:) double {mustBePositive,mustBeFinite,mustBeLessThanOrEqual(options.AvgDev,100)} = [0.25 0.5 1]
 options.PerceptualCompression (1,1) double {mustBePositive,mustBeFinite} = 20
 options.FinalSmoothing (1,:) double = NaN
 options.IncludeOff (1,1) logical = true
 options.A2BQuality (1,1) string {mustBeMember(options.A2BQuality,["medium","high"])} = "medium"
 options.RunPhoto (1,1) logical = true
 options.RunC1 (1,1) logical = true
 options.RunSky (1,1) logical = true
 options.ShowJobDialog (1,1) logical = false
end
inputFolder=inkprof.internal.absolutePath(inputFolder);
if isfile(inputFolder),inputFolder=fileparts(inputFolder);end
project=inkprof.internal.findProject(inputFolder);
assert(project~="",'inkprof:Project','The B1 input must belong to an InkProf project.');
methods=strings(1,0);avg=zeros(1,0);
if options.IncludeOff,methods(end+1)="off";avg(end+1)=NaN;end
methods=[methods,repmat("argyll-colprof",1,numel(options.AvgDev))];avg=[avg,options.AvgDev];
assert(~isempty(options.FinalSmoothing)&&all(isnan(options.FinalSmoothing)|(isfinite(options.FinalSmoothing)&options.FinalSmoothing>0)), ...
 'inkprof:Comparison','FinalSmoothing must contain positive values or NaN for the default.');
baseCount=numel(methods);methods=repelem(methods,numel(options.FinalSmoothing));avg=repelem(avg,numel(options.FinalSmoothing));
final=repmat(options.FinalSmoothing,1,baseCount);
n=numel(methods);assert(n>0,'inkprof:Comparison','Nothing to compare.');
rows=repmat(emptyRow(),n,1);started=tic;
for k=1:n
 r=emptyRow();r.method=methods(k);r.avgdev=avg(k);r.finalSmoothing=final(k);
 if methods(k)=="off"
  r.variant="Off (raw)";
 else
  r.variant=sprintf("Argyll -r %g %%",avg(k));
 end
 if isnan(final(k)),suffix="default";else,suffix=string(final(k));end
 r.variant=r.variant+" / final -r "+suffix;
 fprintf('\nInkProf comparison %d/%d: %s (%.0f s elapsed)\n',k,n,r.variant,toc(started));
 try
  value=avg(k);if isnan(value),value=0.5;end % ignored when off
  [recipeFile,~]=inkprof.createProfileRecipe(inputFolder,'PerceptualCompression',options.PerceptualCompression,'PreRegularization',methods(k), ...
   'PreRegularizationAvgDev',value,'Smoothing',final(k),'A2BQuality',options.A2BQuality,'ShowDialog',false);
  [job,status]=inkprof.runProfileJob(recipeFile,'ShowDialog',options.ShowJobDialog);
  r.job=string(job);r.status=string(status.status);
  if r.status~="succeeded",detail="";if isfield(status,'error'),detail=string(status.error);end;error('inkprof:Comparison','Build %s: %s',r.status,detail);end
  if isfield(status,'preRegularization')
   r.modelChangeMean=status.preRegularization.summary.mean;r.modelChangeMax=status.preRegularization.summary.max;
  else
   r.modelChangeMean=0;r.modelChangeMax=0;
  end
  [fit,~]=inkprof.checkProfileFit(job,'ShowDialog',false);
  r.fitMean=fit.summary.mean;r.fitP95=fit.summary.p95;r.fitMax=fit.summary.max;
  r.grayMean=groupMean(fit,'gray');r.darkMean=groupMean(fit,'dark');r.highChromaMean=groupMean(fit,'highChroma');
  p=fit.patches;hc=[p.highChroma];
  if any(hc)
   P=[p(hc).predictedLab]';M=[p(hc).measuredLab]';
   r.highChromaChromaShift=mean(hypot(P(:,2),P(:,3))-hypot(M(:,2),M(:,3)));
  end
  if options.RunPhoto
   [photo,photoFile]=inkprof.checkPhotoGradients(job,ShowDialog=false);r.photoGradientReport=photoFile;
   metrics=photo.comparisonMetrics;
   if ~isempty(metrics),r.photoCurvatureP95Mean=mean([metrics.curvatureP95]);r.photoLightnessReversals=sum([metrics.lightnessReversals]);r.photoInteriorPaths=numel(metrics);end
  end
  if options.RunC1
   [c1,~]=inkprof.checkProfileC1(job,'ShowDialog',false);ramps=c1.inverseRamps;
   r.rampRGBStepMax=ramps.rgbStepPercent.max;r.rampRGBSecondDiffP95=ramps.rgbSecondDifferencePercent.p95;
   r.rampRGBSecondDiffMax=ramps.rgbSecondDifferencePercent.max;r.rampColourStepMax=ramps.colourStepDeltaE00.max;
   r.c1Alerts=numel(c1.grossFailureAlerts);
  end
  if options.RunSky
   [sky,~]=inkprof.checkSkyRamp(job,'ShowDialog',false);s=sky.summary.relativeColorimetric;
   r.skySecondDiffMax=s.secondDiffMax;r.skySecondDiffBand=s.secondDiffBandMax;r.skyReversalsBand=s.reversalsBand;
   if ~isempty(s.colourStepMaxOverMedian),r.skyStepMaxOverMedian=s.colourStepMaxOverMedian;end
  end
 catch err
  r.error=string(err.message);if r.status=="succeeded",r.status="diagnostics-incomplete";elseif r.status=="",r.status="failed";end
  warning('inkprof:Comparison','%s: %s',r.variant,err.message);
 end
 rows(k)=r;
end
results=struct2table(rows);
stamp=string(datetime('now','TimeZone','UTC','Format','yyyyMMdd''T''HHmmss''Z'''));
folder=fullfile(project,'profiles','comparisons',"preregularization-"+stamp);mkdir(folder);
writetable(results,fullfile(folder,'comparison.csv'));
record=struct('schemaVersion',1,'documentType',"inkprof.preregularization-comparison",'createdUTC',stamp, ...
 'inputFolder',inputFolder,'inputSHA256',inkprof.internal.sha256(fullfile(inputFolder,'profile-input.json')), ...
 'a2bQuality',options.A2BQuality,'finalSmoothing',options.FinalSmoothing,'variants',rows, ...
 'definitions',struct('fit',"Final ICC vs RAW measured training patches, dE00 (training error, not validation)", ...
  'modelChange',"dE00 between pre-regularization model and raw measurement per patch (0 when off)", ...
  'highChromaChromaShift',"Mean predicted minus measured C*ab for measured C*ab >= 40; negative = gamut shrinkage", ...
  'ramps',"C1 inverse ramps (27 paths x 1025 samples): RGB step and second difference in percentage points; colour step dE00", ...
  'sky',"Blue-sky path from the banding test image through B2A (relative colorimetric): max RGB second difference (pp) overall and in L* 40-55, channel reversals in L* 40-55"), ...
 'caveat',"Numerical diagnostics only. Photo curvature averages may have different interior path coverage; inspect matching paths before comparing. Training fit is not held-out validation. Smoother inverse ramps are not proof of less banding on paper; no candidate is selected or approved.");
inkprof.internal.writeJson(fullfile(folder,'comparison.json'),record);
inkprof.internal.recordProjectStep(folder,"Pre-regularization comparison (numerical only; no profile selected)");
fprintf('\nInkProf: comparison saved in %s (%.0f s)\n\n',folder,toc(started));
disp(results(:,["variant","status","modelChangeMean","fitMean","fitP95","fitMax","highChromaMean","highChromaChromaShift","rampRGBSecondDiffMax","rampColourStepMax","skySecondDiffBand","skyReversalsBand","finalSmoothing","photoCurvatureP95Mean","photoLightnessReversals"]));
end

function r=emptyRow()
r=struct('variant',"",'method',"",'avgdev',NaN,'status',"",'modelChangeMean',NaN,'modelChangeMax',NaN, ...
 'fitMean',NaN,'fitP95',NaN,'fitMax',NaN,'grayMean',NaN,'darkMean',NaN,'highChromaMean',NaN,'highChromaChromaShift',NaN, ...
 'rampRGBStepMax',NaN,'rampRGBSecondDiffP95',NaN,'rampRGBSecondDiffMax',NaN,'rampColourStepMax',NaN,'c1Alerts',NaN, ...
 'skySecondDiffMax',NaN,'skySecondDiffBand',NaN,'skyReversalsBand',NaN,'skyStepMaxOverMedian',NaN, ...
 'finalSmoothing',NaN,'photoGradientReport',"",'photoCurvatureP95Mean',NaN,'photoLightnessReversals',NaN,'photoInteriorPaths',0, ...
 'job',"",'error',"");
end

function v=groupMean(fit,name)
v=NaN;if isfield(fit.groups,name)&&~isempty(fit.groups.(name).mean),v=fit.groups.(name).mean;end
end
