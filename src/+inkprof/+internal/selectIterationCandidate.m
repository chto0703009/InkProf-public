% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function result=selectIterationCandidate(proposals,minImprovement,maxRegression,maxGrayRegression,gradientTolerance,accuracyTradeoff)
% Development accuracy plus relative photographic-gradient guardrails.
if nargin<5,gradientTolerance=Inf;end
if nargin<6,accuracyTradeoff=0;end
selected=1;decisions=cell(numel(proposals),1);
for k=1:numel(proposals)
 p=proposals{k};b=proposals{selected};a=p.evaluatedPatches;old=b.evaluatedPatches;
 assert(isequal(string({a.sampleId}),string({old.sampleId})),'inkprof:IterationIdentity','Candidate development IDs differ.');
 delta=[a.deltaE00]-[old.deltaE00];rgb=reshape([a.rgbPercent],3,[])';gray=max(rgb,[],2)-min(rgb,[],2)<=2;
 grayRegression=0;if any(gray),grayRegression=mean(delta(gray));end
 norm=p.errorNorm.value;oldNorm=b.errorNorm.value;
 [gradientOK,gradientImprovement,gradientReason]=gradientGuard(p,b,gradientTolerance);
 accuracyOK=~isempty(norm)&&~isempty(oldNorm)&&norm-oldNorm<=accuracyTradeoff;
 improvement=~isempty(norm)&&~isempty(oldNorm)&&oldNorm-norm>=minImprovement;
 accept=accuracyOK&&(improvement||gradientImprovement>=.05)&&max(delta)<=maxRegression&&grayRegression<=maxGrayRegression&&gradientOK;
 decisions{k}=struct('candidate',k,'comparedTo',selected,'norm',norm,'previousNorm',oldNorm, ...
  'worstPatchRegression',max(delta),'grayMeanRegression',grayRegression,'grayCount',sum(gray), ...
  'gradientAccepted',gradientOK,'gradientImprovement',gradientImprovement,'gradientReason',gradientReason, ...
  'regressingIds',{cellstr(string({a(delta>0).sampleId}))},'deltaE00Change',delta,'accepted',accept);
 if accept,selected=k;end
end
result=struct('selected',selected,'basis',"Development weighted RMS and relative photographic-gradient guardrails; candidate, not final validation", ...
 'gradientTolerance',gradientTolerance,'maxAccuracyTradeoff',accuracyTradeoff,'minImprovement',minImprovement,'maxPatchRegression',maxRegression,'maxGrayRegression',maxGrayRegression,'decisions',{decisions});
end

function [ok,improvement,reason]=gradientGuard(p,b,tolerance)
ok=true;improvement=0;reason="Gradient guard not requested.";
if isinf(tolerance),return;end
ok=false;reason="Gradient evidence unavailable; retain baseline for review.";
if ~isfield(p,'gradientEvidence')||~isfield(b,'gradientEvidence')||isempty(p.gradientEvidence)||isempty(b.gradientEvidence),return;end
new=p.gradientEvidence;old=b.gradientEvidence;keys=string({new.key});reductions=zeros(numel(old),1);
for k=1:numel(old)
 j=find(keys==string(old(k).key));
 if numel(j)~=1,reason="Missing matching gradient or no interior support.";return;end
 a=new(j);v=old(k);
 metrics=[a.curvatureP95,a.curvatureMax,v.curvatureP95,v.curvatureMax];
 if numel(metrics)~=4||any(~isfinite(metrics)),reason="Nonfinite or missing gradient metrics.";return;end
 if a.interiorFraction<v.interiorFraction-.05,reason="Gradient interior coverage decreased.";return;end
 if a.curvatureP95>v.curvatureP95*(1+tolerance)+1 || a.curvatureMax>v.curvatureMax*(1+tolerance)+1
  reason="Curvature worsened beyond the relative gradient tolerance: "+string(v.key);return;
 end
 if ~isfield(a,'labSpan')||~isfield(v,'labSpan')||isempty(a.labSpan)||isempty(v.labSpan)||~isfinite(a.labSpan)||~isfinite(v.labSpan)
  reason="Missing or invalid gradient colour span.";return;
 end
 if a.labSpan<v.labSpan*.95-.1,reason="Gradient colour span decreased: "+string(v.key);return;end
 if a.lightnessReversals>v.lightnessReversals,reason="Additional lightness reversals: "+string(v.key);return;end
 reductions(k)=(v.curvatureP95-a.curvatureP95)/max(v.curvatureP95,1);
end
ok=true;improvement=mean(reductions);reason="Matched float gradients stayed within curvature, lightness and interior-coverage guardrails.";
end
