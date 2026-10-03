% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function result=verificationCandidates(observations,training,settings)
% MATLAB Base: bounded sampling around model residuals, never an RGB correction.
assert(size(training,2)==3&&all(isfinite(training),'all')&&all(training>=0&training<=100,'all'),'inkprof:Refinement','Invalid training RGB.');
existing=[training;reshape([observations.rgbPercent],3,[])'];
weights=ones(numel(observations),1);usable=false(size(weights));errors=zeros(size(weights));
for k=1:numel(observations)
 o=observations(k);usable(k)=o.repeatMaxDeltaE00<=settings.RepeatLimit;
 errors(k)=o.deltaE00;if o.gray,weights(k)=settings.GrayWeight;end
end
value=[];if any(usable),value=sqrt(sum(weights(usable).*errors(usable).^2)/sum(weights(usable)));end
pool=struct('rgbPercent',{},'score',{},'observationIndex',{},'direction',{},'radiusPercent',{},'patchId',{});
diagnostics=cell(numel(observations),1);
for k=1:numel(observations)
 o=observations(k);J=double(o.jacobian);r=double(o.residualLab(:));
 assert(isequal(size(J),[3 3])&&numel(r)==3&&all(isfinite(J),'all')&&all(isfinite(r)),'inkprof:Refinement','Invalid Jacobian/residual.');
 [U,S,V]=svd(J);s=diag(S);lambda=max(settings.RegularizationFraction*s(1),1e-8);
 % Tikhonov direction is used on BOTH sides, only to gather information.
 d=-V*((s./(s.^2+lambda^2)).*(U'*r));
 condition=[];if s(3)>1e-12,condition=s(1)/s(3);end
 diagnostics{k}=struct('sampleIds',{o.sampleIds},'singularValues',s,'conditionNumber',condition, ...
  'regularization',lambda,'regularizedDirection',d,'stepRelativeChange',o.jacobianStepRelativeChange, ...
  'status',"eligible");
 if ~usable(k),diagnostics{k}.status="repeat disagreement; remeasure";continue;end
 if isempty(value)||value<=settings.NormTarget||o.deltaE00<=settings.ErrorThreshold
  diagnostics{k}.status="norm or local error within threshold";continue;
 end
 if o.jacobianStepRelativeChange>settings.MaxJacobianChange
  diagnostics{k}.status="Jacobian depends on step; review before sampling";continue;
 end
 dirs=V;names=["singular-1","singular-2","singular-3"];
 if norm(d)>1e-12,dirs=[d/norm(d),dirs];names=["regularized-residual",names];end
 x=double(o.rgbPercent(:));
 for j=1:size(dirs,2)
  direction=dirs(:,j)/norm(dirs(:,j));response=J*direction;
  alignment=abs(dot(response,r))/max(norm(response)*norm(r),1e-12);
  for sign=[-1,1]
   ray=sign*direction;bound=settings.RadiusPercent;
   for axis=1:3
    if ray(axis)>1e-12,bound=min(bound,(100-x(axis))/ray(axis));
    elseif ray(axis)<-1e-12,bound=min(bound,-x(axis)/ray(axis));end
   end
   for fraction=[.5,1]
    distance=bound*fraction;if distance<settings.MinSpacingPercent,continue;end
    c=round((x+ray*distance)/100*65535)'*100/65535;
    if any(c<0|c>100),continue;end
    gap=min(sqrt(sum((existing-c).^2,2)));if gap<settings.MinSpacingPercent,continue;end
    score=(o.deltaE00-settings.ErrorThreshold)*weights(k)*(.25+.75*alignment)*min(1,gap/settings.RadiusPercent);
    pool(end+1)=struct('rgbPercent',c,'score',score,'observationIndex',k, ...
     'direction',names(j),'radiusPercent',distance,'patchId',""); %#ok<AGROW>
   end
  end
 end
end
selected=pool([]);
if ~isempty(pool)
 [~,order]=sort([pool.score],'descend');
 for i=order
  c=pool(i);
  if ~isempty(selected)&&min(vecnorm(reshape([selected.rgbPercent],3,[])'-c.rgbPercent,2,2))<settings.MinSpacingPercent,continue;end
  q=round(c.rgbPercent/100*65535);c.patchId=sprintf('c3-%05d-%05d-%05d',q);
  selected(end+1)=c; %#ok<AGROW>
  if numel(selected)>=settings.MaxNewPatches,break;end
 end
end
reason="eligible candidates exhausted";
if isempty(value),reason="no usable observations";
elseif value<=settings.NormTarget,reason="norm target reached";
elseif numel(selected)>=settings.MaxNewPatches,reason="iteration budget";end
result=struct('candidates',selected,'diagnostics',{diagnostics},'stopReason',reason, ...
 'errorNorm',struct('type',"weighted RMS model-vs-measurement dE00; repeated RGB counted once", ...
 'value',value,'target',settings.NormTarget,'count',sum(usable),'excludedCount',sum(~usable)));
end
