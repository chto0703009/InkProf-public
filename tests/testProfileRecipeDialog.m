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
s=struct('name',"Test",'description',"Description",'dataMode',"spectral",'projectPrinting',true,'printing',struct);
for key=["printer","paper","media","quality","driver","printPath","colorManagement"],s.printing.(key)="unknown";end
s.printing.paperSurface="Glossy";input=struct('patchCount',575,'measurementCondition',struct('interpreted',"M0"));
t=timer('ExecutionMode','fixedSpacing','Period',.5,'TimerFcn',@clickButton);c=onCleanup(@()clean(t));start(t);
[accepted,out]=inkprof.internal.profileRecipeDialog(s,input,true,true);
verifyEqual(tc,accepted,expected);if expected,verifyEqual(tc,out.b2aQuality,"medium");end;verifyEqual(tc,out.printing.paperSurface,"Glossy");
verifyEmpty(tc,findall(groot,'Tag','InkProfProfileRecipe'));clean(t);
 function clickButton(~,~)
  f=findall(groot,'Tag','InkProfProfileRecipe');if isempty(f),return;end
  b=findall(f,'Tag',button);if isempty(b),return;end
  verifyEqual(tc,string(findall(f,'Tag','printer').Editable),"off");
  verifyEqual(tc,string(findall(f,'Tag','RecipeSurface').Enable),"off");
  q=findall(f,'Tag','RecipeB2AQuality');q.Value='medium';
  stop(t);cb=b.ButtonPushedFcn;cb(b,[]);
 end
end
function clean(t)
if isvalid(t),stop(t);delete(t);end
end
