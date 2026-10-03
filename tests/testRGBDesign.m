% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testRGBDesign
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
end
function testMidpointsAndBudget(tc)
d=inkprof.designRGBTarget(Refinement="edge",Levels=3,MaxPoints=50,GraySteps=9,ControlCount=5,RepeatCount=3);
verifyEqual(tc,size(d.rgb),[50 3]);verifyEqual(tc,d.fitCount,42);
verifyTrue(tc,all(d.rgb>=0 & d.rgb<=1,'all'));
verifyEqual(tc,size(unique(d.rgb(1:d.fitCount,:),'rows'),1),d.fitCount);
verifyEqual(tc,d.rgb(1:size(d.initialRGB,1),:),d.initialRGB);
for i=size(d.initialRGB,1)+1:d.fitCount
    verifyEqual(tc,d.rgb(i,:),mean(d.rgb(d.parentEdges(i,:),:),1),'AbsTol',1e-14);
end
verifyEqual(tc,d.rgb(end-2:end,:),d.rgb(d.repeatOf(end-2:end),:));
verifyEmpty(tc,intersect(d.rgb(1:d.fitCount,:),d.rgb(d.roles=="control",:),'rows'));
verifyTrue(tc,all(diff(d.sortedDistances)<=0));
verifyEqual(tc,d.sortedDistances,sqrt(sum((d.rgb(d.sortedEdges(:,1),:)-d.rgb(d.sortedEdges(:,2),:)).^2,2)));
verifyEqual(tc,d.history(:,2),[d.initialDistances(1);d.history(1:end-1,3)],'AbsTol',1e-12);
end
function testStopsAndDeterminism(tc)
a=inkprof.designRGBTarget(Refinement="edge",Levels=2,MaxPoints=40,GraySteps=0,ControlCount=0,RepeatCount=0,Refine=false);
verifyEqual(tc,a.fitCount,8);verifyEqual(tc,a.stopReason,"base preview");
b=inkprof.designRGBTarget(Refinement="edge",Levels=2,MaxPoints=40,GraySteps=0,ControlCount=0,RepeatCount=0,MaxEdge=2);
verifyEqual(tc,b.fitCount,8);verifyEqual(tc,b.stopReason,"distance threshold");
c=inkprof.designRGBTarget(Refinement="edge",Levels=2,MaxPoints=40,GraySteps=0,ControlCount=0,RepeatCount=0);
e=inkprof.designRGBTarget(Refinement="edge",Levels=2,MaxPoints=40,GraySteps=0,ControlCount=0,RepeatCount=0);
verifyEqual(tc,c.rgb,e.rgb);verifyLessThan(tc,c.sortedDistances(1),a.sortedDistances(1));
g=inkprof.designRGBTarget(Refinement="edge",Levels=2,MaxPoints=150,GraySteps=0,ControlCount=0,RepeatCount=0,GapRatio=1.1);
verifyTrue(tc,g.gap.applied);verifyEqual(tc,g.stopReason,"distance threshold");
verifyLessThanOrEqual(tc,g.sortedDistances(1),g.effectiveThreshold+1e-12);
verifyError(tc,@()inkprof.designRGBTarget(Refinement="edge",MaxPoints=10),'inkprof:Design');
verifyError(tc,@()inkprof.designRGBTarget(Refinement="edge",Progress=@(~)false),'inkprof:Cancelled');
end
function testSaveAndRoundtrip(tc)
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
d=inkprof.designRGBTarget(Name="Refinement test",Levels=2,MaxPoints=24,GraySteps=3,ControlCount=3,RepeatCount=2);
s=inkprof.saveRGBDesign(d,fullfile(w,'test.ti2'),DPI=100);
t=inkprof.importTarget(s.ti1);verifyEqual(tc,t.rgbPercent,d.rgb*100,'AbsTol',1e-12);
record=jsondecode(fileread(s.json));verifyEqual(tc,record.rgb,d.rgb,'AbsTol',1e-14);
verifyEqual(tc,string(record.roles),d.roles);
verifyEqual(tc,string(record.targetInfo.source.fileName),"test.ti1");
verifyEqual(tc,string(record.targetInfo.generation.method),"mesh");
verifyEqual(tc,record.targetInfo.network.pointCount,d.fitCount);
package=jsondecode(fileread(fullfile(s.folder,'target.json')));
verifyEqual(tc,package.targetInfo,record.targetInfo);
reimported=inkprof.importTarget(s.ti2);
verifyEqual(tc,string(reimported.targetInfo.source.fileName),"test.ti2");
verifyEqual(tc,string(reimported.targetInfo.generation.method),"mesh");
verifyEqual(tc,reimported.targetInfo.network.pointCount,d.fitCount);
verifyEqual(tc,string(record.print.ti2SHA256),inkprof.internal.sha256(s.ti2));
chart=inkprof.prepareChart(s.ti2,fullfile(w,'measure'));
verifyEqual(tc,chart.sourcePatchCount,24);
verifyEqual(tc,string(chart.targetInfo.generation.method),"mesh");
verifyEqual(tc,chart.targetInfo.network.pointCount,d.fitCount);
for p=reshape(chart.patches,1,[])
    if p.isPadding,continue;end
    verifyEqual(tc,p.rgbPercent,round(d.rgb(str2double(p.sampleId),:)*65535)/65535*100,'AbsTol',5.1e-6);
end
verifyError(tc,@()inkprof.saveRGBDesign(d,s.ti2,DPI=100),'inkprof:Exists');
verifyTrue(tc,isfile(s.json));
bad=d;bad.rgb(2,:)=bad.rgb(1,:)+1e-9;
verifyError(tc,@()inkprof.saveRGBDesign(bad,fullfile(w,'collapse.ti2'),DPI=100),'inkprof:Design');
verifyFalse(tc,isfile(fullfile(w,'collapse.ti2')));
record.print.ti2SHA256=repmat('0',1,64);
inkprof.internal.writeJson(s.json,record);
verifyError(tc,@()inkprof.importTarget(s.ti2),'inkprof:Integrity');
end
function testArgyll(tc)
d=inkprof.designRGBTarget(Method="argyll",MaxPoints=45,GraySteps=5,ControlCount=4,RepeatCount=2);
verifyLessThanOrEqual(tc,size(d.rgb,1),45);verifyEqual(tc,d.fitCount,39);
verifyEqual(tc,d.stopReason,"Argyll generation complete");verifyNotEmpty(tc,d.argyllRun.version);
end
function testDialog(tc)
f=inkprof.designTarget();cleanup=onCleanup(@()delete(f));
set(findobj(f,'Tag','levels'),'Value',2);set(findobj(f,'Tag','graySteps'),'Value',3);
set(findobj(f,'Tag','maxPoints'),'Value',24);set(findobj(f,'Tag','controls'),'Value',3);set(findobj(f,'Tag','repeats'),'Value',2);
b=findobj(f,'Tag','previewBase');b.ButtonPushedFcn(b,[]);
verifyEqual(tc,f.UserData.design.stopReason,"base preview");
b=findobj(f,'Tag','generate');b.ButtonPushedFcn(b,[]);
verifyEqual(tc,size(f.UserData.design.rgb,1),24);verifyEqual(tc,string(findobj(f,'Tag','saveDesign').Enable),"on");
field=findobj(f,'Tag','maxPoints');field.Value=25;field.ValueChangedFcn(field,[]);
verifyEqual(tc,string(findobj(f,'Tag','saveDesign').Enable),"off");
end

function testBudgetExplanation(tc)
try
    inkprof.designRGBTarget(MaxPoints=100);
    verifyFail(tc,'Expected an insufficient-budget error.');
catch err
    verifyEqual(tc,err.identifier,'inkprof:Design');
    verifyTrue(tc,contains(err.message,'100 - 64 - 12 = 24'));
    verifyTrue(tc,contains(err.message,'Required fitting points: 153'));
    verifyTrue(tc,contains(err.message,'at least 229'));
end
try
    inkprof.designRGBTarget(MaxPoints=10);
    verifyFail(tc,'Expected a negative remaining budget.');
catch err
    verifyTrue(tc,contains(err.message,'10 - 64 - 12 = -66'));
end
try
    inkprof.designRGBTarget(Method="argyll",MaxPoints=40,GraySteps=5,ControlCount=20,RepeatCount=10);
    verifyFail(tc,'Expected an insufficient Argyll budget.');
catch err
    verifyTrue(tc,contains(err.message,'Required fitting points: 13'));
    verifyTrue(tc,contains(err.message,'at least 43'));
end
end
