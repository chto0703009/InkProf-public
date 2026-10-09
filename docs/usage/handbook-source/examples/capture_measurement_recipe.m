% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function capture_measurement_recipe
exampleDir=fileparts(mfilename('fullpath'));root=fileparts(fileparts(fileparts(fileparts(exampleDir))));addpath(root);addpath(fullfile(root,'src'));
base=fullfile(tempdir,'InkProf-handbook-examples');
d=inkprof.MeasurementDialog("",Source="example-target.ti2",ShowPreview=false);drawnow;pause(2);exportapp(d.Figure,fullfile(base,'measurement-window.png'));delete(d);
s=struct('name',"Handbook example",'description',"Example RGB printer profile",'dataMode',"spectral",'b2aQuality',"high",'projectPrinting',true,'printing',struct);
for key=["printer","paper","media","quality","driver","printPath","colorManagement"],s.printing.(key)="Example setting";end
s.printing.inkType="Pigment";s.printing.printerCoating="unknown";s.printing.coatingSettings="unknown";s.printing.dryingHours="24";s.printing.paperSurface="Matte";
input=struct('patchCount',575,'measurementCondition',struct('interpreted',"M0"));
t=timer('StartDelay',3,'TimerFcn',@(~,~)captureRecipe(base));start(t);
inkprof.internal.profileRecipeDialog(s,input,true,true);stop(t);delete(t);
end
function captureRecipe(base)
f=findall(groot,'Tag','InkProfProfileRecipe');f.Position=[80 20 860 1050];drawnow;pause(1);exportapp(f,fullfile(base,'profiling-recipe.png'));
b=findall(f,'Tag','CancelProfileRecipe');cb=b.ButtonPushedFcn;cb(b,[]);
end
