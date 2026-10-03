function tests=testProfileRecipeDialog
tests=functiontests(localfunctions);
end
function testSave(tc)
exercise(tc,'SaveProfileRecipe',true);
end
function testCancel(tc)
exercise(tc,'CancelProfileRecipe',false);
end
function exercise(tc,button,expected)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
s=struct('name',"Test",'description',"Description",'dataMode',"spectral",'b2aQuality',"medium",'projectPrinting',true,'printing',struct);
for key=["printer","paper","media","quality","driver","printPath","colorManagement"],s.printing.(key)="unknown";end
s.printing.inkType="Mixed";s.printing.printerCoating="on";s.printing.coatingSettings="Chroma Optimizer | Auto";s.printing.dryingHours="24";s.printing.paperSurface="Glossy";input=struct('patchCount',575,'measurementCondition',struct('interpreted',"M0"));
t=timer('ExecutionMode','fixedSpacing','Period',.5,'TimerFcn',@clickButton);c=onCleanup(@()clean(t));start(t);
[accepted,out]=inkprof.internal.profileRecipeDialog(s,input,true,true);
verifyEqual(tc,accepted,expected);if expected,verifyEqual(tc,out.b2aQuality,"medium");end;verifyEqual(tc,out.printing.paperSurface,"Glossy");verifyEqual(tc,out.printing.dryingHours,"24");
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
  q=findall(f,'Tag','RecipeB2AQuality');verifyEqual(tc,string(q.Enable),"off");
  verifyEqual(tc,string(findall(f,'Tag','RecipeName').Editable),"off");
  verifyEqual(tc,string(findall(f,'Tag','RecipeMode').Enable),"off");
  stop(t);cb=b.ButtonPushedFcn;cb(b,[]);
 end
end
function clean(t)
if isvalid(t),stop(t);delete(t);end
end
