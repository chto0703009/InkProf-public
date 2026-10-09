% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function capture_icc_choices
% Real project dialog, fictional data; cancel without saving a project.
exampleDir=fileparts(mfilename('fullpath'));root=fileparts(fileparts(fileparts(fileparts(exampleDir))));addpath(root);addpath(fullfile(root,'src'));
base=fullfile(root,'docs','usage','handbook-source','examples');
printing=struct('printer','Example RGB printer','paper','Example matte paper','paperSurface','Matte','ink','Example pigment ink set','inkType','Pigment','driver','Example printer driver','media','Matte paper','quality','High','printPath','Example printing application','colorManagement','Off for profiling target','dryingHours',24,'profileOutputVersions','both');
record=struct('name','Handbook example','user','Example operator','printing',printing);
t=timer('StartDelay',3,'TimerFcn',@(~,~)capture(base));clean=onCleanup(@()delete(t));start(t);
inkprof.projectDetailsDialog(record);stop(t);
end
function capture(base)
f=findall(groot,'Type','figure','Tag','projectDetailsDialog');
exportapp(f,fullfile(base,'project-details.png'));
tg=findall(f,'Type','uitabgroup');tabs=tg.Children;
for k=1:numel(tabs)
 if strcmp(tabs(k).Title,'Profiling'),tg.SelectedTab=tabs(k);end
end
drawnow;pause(1);exportapp(f,fullfile(base,'profiling-settings.png'));
b=findall(f,'Tag','cancelProjectDetails');b.ButtonPushedFcn(b,[]);
end
