function tests=testProjectDetailsDialog
tests=functiontests(localfunctions);
end
function testSaveAndPreserveUnknownFields(tc)
record=struct('name',"Old name",'user',"Old user",'printing',struct('printer',"Old printer",'customSetting',42));
t=timer('ExecutionMode','fixedSpacing','Period',0.2,'TimerFcn',@saveDialog);
cleanup=onCleanup(@()stopTimer(t));start(t);
d=inkprof.projectDetailsDialog(record);
verifyEmpty(tc,findall(groot,'Tag','projectDetailsDialog'),'Save must close the modal dialog.');
verifyEqual(tc,d.Name,"Renamed project");verifyEqual(tc,d.User,"New user");
verifyEqual(tc,d.Printing.printer,"New printer");verifyEqual(tc,d.Printing.paper,"Photo paper");
verifyEqual(tc,d.Printing.paperSurface,"Matte");verifyEqual(tc,d.Printing.customSetting,42);
verifyEqual(tc,d.Printing.settings,"Quality: high"+newline+"No colour correction");
end
function testCancelLegacyRecord(tc)
t=timer('ExecutionMode','fixedSpacing','Period',0.2,'TimerFcn',@cancelDialog);
cleanup=onCleanup(@()stopTimer(t));start(t);
d=inkprof.projectDetailsDialog(struct('name',"Legacy project"));verifyEmpty(tc,d);
verifyEmpty(tc,findall(groot,'Tag','projectDetailsDialog'),'Cancel must close the modal dialog.');
end
function saveDialog(t,~)
f=findall(groot,'Tag','projectDetailsDialog');if isempty(f),return;end
b=findobj(f,'Tag','saveProjectDetails');if isempty(b),return;end
stop(t);
control=findobj(f,'Tag','projectName');control.Value='Renamed project';
control=findobj(f,'Tag','projectUser');control.Value='New user';
control=findobj(f,'Tag','projectPrinter');control.Value='New printer';
control=findobj(f,'Tag','projectPaper');control.Value='Photo paper';
control=findobj(f,'Tag','projectFinish');control.Value='Matte';
control=findobj(f,'Tag','projectSettings');control.Value={'Quality: high';'No colour correction'};
b.ButtonPushedFcn(b,[]);
end
function cancelDialog(t,~)
f=findall(groot,'Tag','projectDetailsDialog');if isempty(f),return;end
b=findobj(f,'Tag','cancelProjectDetails');if isempty(b),return;end
stop(t);b.ButtonPushedFcn(b,[]);
end
function stopTimer(t)
stop(t);delete(t);
f=findall(groot,'Tag','projectDetailsDialog');delete(f);
end
