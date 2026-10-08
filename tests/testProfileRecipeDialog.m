% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testProfileRecipeDialog
tests=functiontests(localfunctions);
end
function testSave(tc)
exercise(tc,'SaveProfileRecipe',true);
end
function testCancel(tc)
exercise(tc,'CancelProfileRecipe',false);
end
function testArgyllMethodsOnly(tc)
[ids,~]=inkprof.internal.preRegularizationMethods();
verifyEqual(tc,ids,["off","argyll-colprof"]);
end
function testColprofSelection(tc)
exercise(tc,'SaveProfileRecipe',true,"argyll-colprof");
end
function exercise(tc,button,expected,method)
if nargin<4,method="off";end
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
s=struct('name',"Test",'description',"Description",'dataMode',"spectral",'b2aQuality',"medium",'projectPrinting',true,'printing',struct);
for key=["printer","paper","media","quality","driver","printPath","colorManagement"],s.printing.(key)="unknown";end
s.printing.inkType="Mixed";s.printing.printerCoating="on";s.printing.coatingSettings="Chroma Optimizer | Auto";s.printing.dryingHours="24";s.printing.paperSurface="Glossy";input=struct('patchCount',575,'measurementCondition',struct('interpreted',"M0"));
t=timer('ExecutionMode','fixedSpacing','Period',.5,'TimerFcn',@clickButton);c=onCleanup(@()clean(t));start(t);
[accepted,out]=inkprof.internal.profileRecipeDialog(s,input,true,true);
verifyEqual(tc,accepted,expected);if expected,verifyEqual(tc,out.b2aQuality,"medium");verifyEqual(tc,out.smoothing,0.22);verifyEqual(tc,out.perceptualCompression,25);verifyEqual(tc,out.preRegularization,method);verifyFalse(tc,isfield(out,'conditioningSelection'));verifyEqual(tc,out.gradientPreview,method~="off");end;verifyEqual(tc,out.printing.paperSurface,"Glossy");verifyEqual(tc,out.printing.dryingHours,"24");
verifyEqual(tc,out.printing.inkType,"Mixed");verifyEqual(tc,out.printing.printerCoating,"on");verifyEqual(tc,out.printing.coatingSettings,"Chroma Optimizer | Auto");
verifyEmpty(tc,findall(groot,'Tag','InkProfProfileRecipe'));clean(t);
 function clickButton(~,~)
  f=findall(groot,'Tag','InkProfProfileRecipe');if isempty(f),return;end
  b=findall(f,'Tag',button);if isempty(b),return;end
  verifyEqual(tc,string(findall(f,'Tag','printer').Editable),"off");
  verifyEqual(tc,string(findall(f,'Tag','printerCoating').Editable),"off");
  verifyEqual(tc,string(findall(f,'Tag','inkType').Editable),"off");
  verifyEqual(tc,string(findall(f,'Tag','inkType').Value),"Mixed");
  verifyEqual(tc,string(findall(f,'Tag','coatingSettings').Value),"Chroma Optimizer | Auto");
  verifyEqual(tc,string(findall(f,'Tag','dryingHours').Value),"24");
  verifyEqual(tc,string(findall(f,'Tag','dryingHours').Editable),"off");
  verifyEqual(tc,string(findall(f,'Tag','RecipeSurface').Enable),"off");
  verifyEqual(tc,string(findall(f,'Tag','RecipePreRegularizationAvgDev').Enable),"off");
  q=findall(f,'Tag','RecipeB2AQuality');verifyEqual(tc,string(q.Enable),"off");
  verifyEqual(tc,string(findall(f,'Tag','RecipeName').Editable),"off");
  verifyEqual(tc,string(findall(f,'Tag','RecipeMode').Enable),"off");
  m=findall(f,'Tag','RecipePreRegularization');m.Value=char(method);cb=m.ValueChangedFcn;cb(m,[]);
  verifyEmpty(tc,findall(f,'Tag','RecipeConditioningSelection'));
  if method=="argyll-colprof"
   verifyEqual(tc,string(findall(f,'Tag','RecipePreRegularizationAvgDev').Enable),"on");
  end
  preview=findall(f,'Tag','RecipeGradientPreview');preview.Value=true;
  if method=="off",verifyEqual(tc,string(preview.Enable),"off");else,verifyEqual(tc,string(preview.Enable),"on");end
  r=findall(f,'Tag','RecipeSmoothing');verifyEqual(tc,string(r.Editable),"on");r.Value='0.22';cb=r.ValueChangedFcn;cb(r,[]);verifyEqual(tc,string(r.Value),"0.2");
  compression=findall(f,'Tag','RecipePerceptualCompression');compression.Value=25;
  stop(t);cb=b.ButtonPushedFcn;cb(b,[]);
 end
end
function clean(t)
if isvalid(t),stop(t);delete(t);end
end
