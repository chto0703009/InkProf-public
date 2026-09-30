function result=selectIterationCandidate(proposals,minImprovement,maxRegression,maxGrayRegression)
% Fixed development observations and per-colour guardrails; no holdout claim.
selected=1;decisions=cell(numel(proposals),1);
for k=1:numel(proposals)
 p=proposals{k};b=proposals{selected};a=p.evaluatedPatches;old=b.evaluatedPatches;
 assert(isequal(string({a.sampleId}),string({old.sampleId})),'inkprof:IterationIdentity','Candidate development IDs differ.');
 delta=[a.deltaE00]-[old.deltaE00];rgb=reshape([a.rgbPercent],3,[])';gray=max(rgb,[],2)-min(rgb,[],2)<=2;
 grayRegression=0;if any(gray),grayRegression=mean(delta(gray));end
 norm=p.errorNorm.value;oldNorm=b.errorNorm.value;
 accept=~isempty(norm)&&~isempty(oldNorm)&&oldNorm-norm>=minImprovement&&max(delta)<=maxRegression&&grayRegression<=maxGrayRegression;
 decisions{k}=struct('candidate',k,'comparedTo',selected,'norm',norm,'previousNorm',oldNorm, ...
  'worstPatchRegression',max(delta),'grayMeanRegression',grayRegression,'grayCount',sum(gray), ...
  'regressingIds',{cellstr(string({a(delta>0).sampleId}))},'deltaE00Change',delta,'accepted',accept);
 if accept,selected=k;end
end
result=struct('selected',selected,'basis',"Development weighted RMS with per-patch and gray regression guardrails; candidate, not final validation", ...
 'minImprovement',minImprovement,'maxPatchRegression',maxRegression,'maxGrayRegression',maxGrayRegression,'decisions',{decisions});
end
