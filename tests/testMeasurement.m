% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testMeasurement
tests=functiontests(localfunctions);
end
function testJsonChartAndResults(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
package=fullfile(w,'target');inkprof.createTarget(package,PatchCount=20,GraySteps=3,DPI=100);
folder=fullfile(w,'session');chart=inkprof.prepareChart(fullfile(package,'target.ti2'),folder);
verifyTrue(tc,isfile(fullfile(folder,'chart.json')));verifyFalse(tc,isfile(fullfile(folder,'chart.ti2')));
verifyEqual(tc,chart.colorSpace,"RGB");
inkprof.exportChartTi2(fullfile(folder,'chart.json'),fullfile(folder,'export.ti2'));
a=inkprof.internal.readCgats(fullfile(package,'target.ti2'));b=inkprof.internal.readCgats(fullfile(folder,'export.ti2'));
verifyEqual(tc,a.fields,b.fields);verifyEqual(tc,a.data(:,1:2),b.data(:,1:2));
verifyEqual(tc,str2double(a.data(:,3:5)),str2double(b.data(:,3:5)),AbsTol=1e-10);
% The bridge's adapter must produce the same semantic TI2 without source files.
script=fullfile(w,'adapt.py');fid=fopen(script,'w');fprintf(fid,'import sys,json\nsys.path.insert(0,sys.argv[1])\nfrom chartread_bridge import chart_to_ti2\nopen(sys.argv[3],"w").write(chart_to_ti2(json.load(open(sys.argv[2]))))\n');fclose(fid);
inkprof.runPython(script,[fullfile(root,'bridge'),fullfile(folder,'chart.json'),fullfile(folder,'python.ti2')]);
c=inkprof.internal.readCgats(fullfile(folder,'python.ti2'));verifyEqual(tc,b.fields,c.fields);verifyEqual(tc,str2double(b.data(:,3:5)),str2double(c.data(:,3:5)),AbsTol=1e-10);
% Synthetic values test identity/completeness, never claim instrument measurements.
p=chart.patches;real=p(~[p.isPadding]);f=fullfile(w,'synthetic.ti3');
writeTi3(f,real(1:end-1));r=inkprof.importChartMeasurement(folder,f);verifyFalse(tc,r.complete);
pause(.01);writeTi3(f,real);r=inkprof.importChartMeasurement(folder,f);verifyTrue(tc,r.complete);
real(1).rgbPercent=[-1 0 0];writeTi3(f,real);
verifyError(tc,@()inkprof.importChartMeasurement(folder,f),'inkprof:Scale');
verifyError(tc,@()inkprof.prepareChart(fullfile(package,'target.ti1'),fullfile(w,'bad')),'inkprof:ChartFormat');
end
function writeTi3(path,p)
f=fopen(path,'w');c=onCleanup(@()fclose(f));
fprintf(f,'CTI3\nCOLOR_REP "RGB_XYZ"\nNUMBER_OF_FIELDS 7\nBEGIN_DATA_FORMAT\nSAMPLE_ID RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z\nEND_DATA_FORMAT\nNUMBER_OF_SETS %d\nBEGIN_DATA\n',numel(p));
for k=1:numel(p),fprintf(f,'%s %.12g %.12g %.12g 10 20 30\n',p(k).sampleId,p(k).rgbPercent);end
fprintf(f,'END_DATA\n');
end
function testMatlabController(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
assumeTrue(tc,isunix,'POSIX only');
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
pkg=fullfile(w,'target');inkprof.createTarget(pkg,PatchCount=20,GraySteps=3,DPI=100);
folder=fullfile(w,'session');inkprof.prepareChart(fullfile(pkg,'target.ti2'),folder);
bin=fullfile(w,'bin');mkdir(bin);
for name=["targen","printtarg"],f=fopen(fullfile(bin,name),'w');fclose(f);end
runtime=inkprof.checkPython();script=fullfile(bin,'chartread');f=fopen(script,'w');
fprintf(f,'#!%s\nimport sys\nif "-?" in sys.argv: print("Fake Version 1.0");sys.exit(1)\nprint("CONTROLLER TEST PROMPT",flush=True)\ninput()\n',runtime.executable);fclose(f);
file=java.io.File(char(script));file.setExecutable(true);
session=inkprof.ChartReadSession(folder,ArgyllBin=bin);stop=onCleanup(@()delete(session));
sent=false;exited=false;start=tic;
while toc(start)<15
    events=session.poll();
    for k=1:numel(events)
        event=events{k};
        if string(event.event)=="output"&&contains(string(event.text),"CONTROLLER TEST PROMPT")&&~sent
            session.sendKey(char(13));sent=true;
        end
        if string(event.event)=="exited",exited=true;verifyEqual(tc,event.exitCode,0);end
    end
    if exited,break;end
    pause(.05);
end
verifyTrue(tc,sent);verifyTrue(tc,exited);
end
function testTerminalLaunchAndImport(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
package=fullfile(w,'target');inkprof.createTarget(package,PatchCount=20,GraySteps=3,DPI=100);
folder=fullfile(w,'session');chart=inkprof.prepareChart(fullfile(package,'target.ti2'),folder);
run=inkprof.startMeasurement(folder,OpenTerminal=false);
verifyTrue(tc,isfile(run.launcher));verifyFalse(tc,isfile(fullfile(folder,'chart.ti3')));
verifyError(tc,@()inkprof.finishMeasurement(run),'inkprof:Measurement');
% Simulated result manifest exercises MATLAB's return boundary, not an instrument.
record=jsondecode(fileread(run.record));f=fullfile(folder,'synthetic-result.ti3');
p=chart.patches;p=p(~[p.isPadding]);writeTi3(f,p);
record.status="saved_unvalidated";record.resultTI3=f;record.resultSHA256=inkprof.internal.sha256(f);
inkprof.internal.writeJson(run.record,record);
result=inkprof.finishMeasurement(run);verifyTrue(tc,result.complete);
fid=fopen(f,'a');fprintf(fid,'\n');fclose(fid);
verifyError(tc,@()inkprof.finishMeasurement(run),'inkprof:Integrity');
end
