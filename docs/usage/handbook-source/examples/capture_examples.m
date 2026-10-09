% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function capture_examples
exampleDir=fileparts(mfilename('fullpath'));root=fileparts(fileparts(fileparts(fileparts(exampleDir))));addpath(root);addpath(fullfile(root,'src'));
base=fullfile(tempdir,'InkProf-handbook-examples');
if ~isfolder(base),mkdir(base);end
copyfile(fullfile(exampleDir,'example-sRGB.icc'),fullfile(base,'example-sRGB.icc'));
setupInkProf(CheckPython=true,SaveLocalConfig=false);
project=fullfile(base,'example-project');
printing=struct('printer','Example RGB printer','paper','Example matte paper','paperSurface','Matte','ink','Example pigment ink set','inkType','Pigment','driver','Example printer driver','media','Matte paper','quality','High','printPath','Example printing application','colorManagement','Off for profiling target','dryingHours',24);
if ~isfolder(project),inkprof.createProject(project,Name="Handbook example",User="Example operator",Printing=printing);end
f=inkprof.app(project);drawnow;pause(3);exportapp(f,fullfile(base,'main-window.png'));delete(f);
record=jsondecode(fileread(fullfile(project,'inkprof-project.json')));
t=timer('StartDelay',3,'TimerFcn',@(~,~)captureDialog(base));start(t);
inkprof.projectDetailsDialog(record);stop(t);delete(t);
f=inkprof.showGamut(fullfile(base,'example-sRGB.icc'));set(f,'Position',[100 100 1050 760]);drawnow;exportgraphics(f,fullfile(base,'gamut-window.png'),'Resolution',160);delete(f);
end
function captureDialog(base)
f=findall(groot,'Type','figure','Tag','projectDetailsDialog');
exportapp(f,fullfile(base,'project-details.png'));
tg=findall(f,'Type','uitabgroup');tabs=tg.Children;
for k=1:numel(tabs)
 if strcmp(tabs(k).Title,'Profiling'),tg.SelectedTab=tabs(k);end
end
drawnow;pause(1);exportapp(f,fullfile(base,'profiling-settings.png'));
b=findall(f,'Tag','cancelProjectDetails');callback=b.ButtonPushedFcn;callback(b,[]);
end
