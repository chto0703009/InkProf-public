% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function tests=testProfileTradeoffs
tests=functiontests(localfunctions);
end
function testCartesianComparisonPreservesInput(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
f=string(tempname);mkdir(f);cleanup=onCleanup(@()rmdir(f,'s'));
project=inkprof.createProject(fullfile(f,'project'),Printing=struct('profileDataMode',"storedXYZ"));
target=fullfile(f,'target');inkprof.createTarget(target,PatchCount=40,GraySteps=4,DPI=100);
session=fullfile(project,'measurements','synthetic');inkprof.prepareChart(fullfile(target,'target.ti2'),session);
doc=inkprof.importCgats(fullfile(target,'target.ti2'));doc.tables=doc.tables(1);doc.tables.signature="CTI3";doc.tables.metadata{end+1}=["DEVICE_CLASS","OUTPUT"];
file=fullfile(f,'synthetic.ti3');inkprof.exportCgats(file,doc);inkprof.importChartMeasurement(session,file);
files=dir(fullfile(session,'measurement-*.json'));measurement=fullfile(files(1).folder,files(1).name);
[input,~]=inkprof.prepareProfileInput(measurement,ShowDialog=false);before=inkprof.internal.sha256(fullfile(input,'profiling.ti3'));
[T,folder]=inkprof.comparePreRegularization(input,AvgDev=0.5, ...
 FinalSmoothing=[.5 1],A2BQuality="medium",RunC1=false,RunSky=false);
verifyEqual(tc,height(T),4);verifyEqual(tc,T.finalSmoothing,[.5;1;.5;1]);verifyTrue(tc,all(T.status=="succeeded"));
for k=1:height(T)
 saved=jsondecode(fileread(fullfile(T.job(k),'status.json')));
 if string(saved.status)=="succeeded",verifyTrue(tc,isfield(saved,'renderingIntents'));end
 if T.status(k)~="succeeded",disp(fileread(fullfile(T.job(k),'status.json')));disp(fileread(fullfile(T.job(k),'colprof.log')));end
end
verifyTrue(tc,all(T.error==""));verifyTrue(tc,all(isfinite(T.photoCurvatureP95Mean)));verifyTrue(tc,all(T.photoInteriorPaths>0));
verifyEqual(tc,inkprof.internal.sha256(fullfile(input,'profiling.ti3')),before);
verifyTrue(tc,isfile(fullfile(folder,'comparison.json')));
w=inkprof.ProjectWorkflow(project);verifyEqual(tc,string(w.State.steps.profile.status),"pending");
end
