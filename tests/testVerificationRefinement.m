% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testVerificationRefinement
tests=functiontests(localfunctions);
end
function [o,s]=fixture()
o=struct('rgbPercent',[50 50 50],'residualLab',[6 2 0],'jacobian',diag([2 1 .001]), ...
 'deltaE00',5,'repeatMaxDeltaE00',.2,'repeatCount',2,'gray',false, ...
 'sampleIds',{{'1','2'}},'coordinates',{{'K3','H1'}},'jacobianStepRelativeChange',.01);
s=struct('RepeatLimit',1,'GrayWeight',2,'RegularizationFraction',.1,'NormTarget',1, ...
 'ErrorThreshold',1,'MaxJacobianChange',.5,'RadiusPercent',5,'MinSpacingPercent',1,'MaxNewPatches',7);
end
function testBoundsSpacingAndBudget(tc)
[o,s]=fixture();o.rgbPercent=[0 50 100];p=inkprof.internal.verificationCandidates(o,[10 50 90],s);
verifyLessThanOrEqual(tc,numel(p.candidates),7);verifyNotEmpty(tc,p.candidates);
x=reshape([p.candidates.rgbPercent],3,[])';verifyTrue(tc,all(x>=0&x<=100,'all'));
verifyLessThanOrEqual(tc,max(vecnorm(x-o.rgbPercent,2,2)),5.002);
for k=1:size(x,1)
 verifyGreaterThanOrEqual(tc,norm(x(k,:)-o.rgbPercent),1);
 for j=k+1:size(x,1),verifyGreaterThanOrEqual(tc,norm(x(k,:)-x(j,:)),1);end
end
end
function testSingularDoesNotExplode(tc)
[o,s]=fixture();o.jacobian=diag([1 0 0]);p=inkprof.internal.verificationCandidates(o,[0 0 0],s);
verifyNotEmpty(tc,p.candidates);verifyEmpty(tc,p.diagnostics{1}.conditionNumber);
verifyTrue(tc,all(isfinite(p.diagnostics{1}.regularizedDirection)));
end
function testGatesAndNorm(tc)
[o,s]=fixture();o.repeatMaxDeltaE00=2;p=inkprof.internal.verificationCandidates(o,[0 0 0],s);
verifyEmpty(tc,p.candidates);verifyEqual(tc,p.errorNorm.excludedCount,1);
[o,s]=fixture();o.jacobianStepRelativeChange=.8;p=inkprof.internal.verificationCandidates(o,[0 0 0],s);verifyEmpty(tc,p.candidates);
[o,s]=fixture();s.NormTarget=6;p=inkprof.internal.verificationCandidates(o,[0 0 0],s);
verifyEmpty(tc,p.candidates);verifyEqual(tc,p.stopReason,"norm target reached");
end
function testRepeatGroupCountsOnce(tc)
[o,s]=fixture();p=inkprof.internal.verificationCandidates(o,[0 0 0],s);
verifyEqual(tc,p.errorNorm.count,1);verifyEqual(tc,p.errorNorm.value,5);
end
function testSavedProposalTableText(tc)
[o,s]=fixture();p=inkprof.internal.verificationCandidates(o,[0 0 0],s);
p.documentType="inkprof.verification-refinement";p.name="Table regression";p.parameters=s;p.observations=o;
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
inkprof.internal.writeJson(fullfile(w,'proposal.json'),p);
f=inkprof.showRefinementProposal(w,Visible=false);closeFigure=onCleanup(@()delete(f));
t=findall(f,'Type','uitable');verifyEqual(tc,size(t.Data,1),numel(p.candidates));
verifyTrue(tc,all(cellfun(@(v)isnumeric(v)||islogical(v)||ischar(v),t.Data),'all'));
verifyEqual(tc,t.Data{1,1},'K3, H1');
end
