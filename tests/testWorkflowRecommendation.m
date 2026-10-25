% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testWorkflowRecommendation
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function [s,a]=fixture()
s=struct('currentStep',"profile");a=struct;
for d=inkprof.internal.workflowSteps()'
 a.(d.id)=struct('ready',false,'valid',false,'reason',"Pending");
end
end
function testRefinementLeadsToMeasurementThenBuild(tc)
[s,a]=fixture();a.refine.valid=true;a.refinemeasurement.ready=true;
n=inkprof.internal.recommendWorkflowStep(s,a);verifyEqual(tc,n.id,"refinemeasurement");verifyTrue(tc,n.ready);verifyTrue(tc,startsWith(n.label,'16.'));
a.refinemeasurement.valid=true;a.continue.ready=true;
n=inkprof.internal.recommendWorkflowStep(s,a);verifyEqual(tc,n.id,"continue");
end
function testComparisonDoesNotReplaceChecks(tc)
[s,a]=fixture();s.currentStep="compare";a.profile.valid=true;a.checks.ready=true;a.compare.valid=true;
n=inkprof.internal.recommendWorkflowStep(s,a);verifyEqual(tc,n.id,"checks");
end
function testAfterBuildOffersComparison(tc)
[s,a]=fixture();s.currentStep="continue";a.profile.valid=true;a.compare.ready=true;a.checks.ready=true;
n=inkprof.internal.recommendWorkflowStep(s,a);verifyEqual(tc,n.id,"compare");
end
function testCheckedProfileOffersVerificationAndAlternatives(tc)
[s,a]=fixture();for id=["definition","render","measurement","review","input","profile","checks"],a.(id).valid=true;end
a.c2.ready=true;n=inkprof.internal.recommendWorkflowStep(s,a);verifyEqual(tc,n.id,"c2");verifyTrue(tc,contains(n.reason,'step 19'));
end
function testMissingInputIsNotBypassedAndDeliveryEndsGuidance(tc)
[s,a]=fixture();a.definition.ready=true;n=inkprof.internal.recommendWorkflowStep(s,a);verifyEqual(tc,n.id,"definition");
a.export.valid=true;n=inkprof.internal.recommendWorkflowStep(s,a);verifyEqual(tc,n.id,"");verifyFalse(tc,n.ready);
end
function testVerificationModeLabels(tc)
[s,a]=fixture();a.profile.ready=true;n=inkprof.internal.recommendWorkflowStep(s,a,"verification");verifyEqual(tc,n.id,"profile");verifyTrue(tc,startsWith(n.label,'1. Import'));
end
function testApprovedPrintOffersCertificateDespiteNumericalDelivery(tc)
[s,a]=fixture();a.numericalExport.valid=true;a.approve.valid=true;a.export.ready=true;
n=inkprof.internal.recommendWorkflowStep(s,a);verifyEqual(tc,n.id,"export");verifyTrue(tc,n.ready);
end

function testNumericalFailureSuggestsReview(tc)
[s,a]=fixture();s.steps=struct('continue',struct('status',"failed",'message',"Numerical checks require review"));a.continue.ready=true;
n=inkprof.internal.recommendWorkflowStep(s,a);verifyTrue(tc,contains(n.label,'Review stopped'));verifyTrue(tc,contains(n.reason,'before retrying'));
end
function testNumericalFailureMessageIdentifiesEvidence(tc)
c1=struct('grossFailureAlerts',{{'roundtrip-over-10-dE00'}},'allNegativeControlsDetected',true);
grid=struct('roundtripDeltaE00',struct('max',16.452));
m=inkprof.internal.iterationNumericalMessage(c1,grid,"c1-check.json","grid-check.json");
verifyTrue(tc,contains(m,'16.452'));verifyTrue(tc,contains(m,'not been activated'));verifyTrue(tc,contains(m,'grid-check.json'));
end

function testInputLeadsToRecipeBeforeProfile(tc)
[s,a]=fixture();
for id=["definition","render","measurement","review","input"],a.(id).valid=true;end
a.recipe.ready=true;a.profile.ready=true;
n=inkprof.internal.recommendWorkflowStep(s,a);verifyEqual(tc,n.id,"recipe");
a.recipe.valid=true;
n=inkprof.internal.recommendWorkflowStep(s,a);verifyEqual(tc,n.id,"profile");
end
