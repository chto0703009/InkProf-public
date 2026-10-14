% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testMeasurementCheckpoint
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
end
function testRoundTripAndIntegrity(tc)
p=string(tempname);mkdir(p);cleanup=onCleanup(@()rmdir(p,'s'));
inkprof.internal.writeJson(fullfile(p,'chart.json'),struct('passesInStrips',[2 2]));
inkprof.internal.writeJson(fullfile(p,'measurement-settings.json'),struct('scanMode',"single"));
createRaw(p,4);
c=inkprof.internal.measurementCheckpoint(p,[true true false false]);
r=inkprof.internal.measurementCheckpoint(p);verifyEqual(tc,r.confirmedPasses,[1;2]);verifyFalse(tc,r.complete);
doc=inkprof.importCgats(fullfile(p,string(r.snapshot)));verifyEqual(tc,size(doc.tables(1).data,1),2);
% Raw working file may change after a crash: immutable checkpoint survives.
f=fopen(fullfile(p,'chart.ti3'),'w');fprintf(f,'unsaved later run');fclose(f);
r=inkprof.internal.measurementCheckpoint(p);verifyEqual(tc,string(r.snapshotSHA256),string(c.snapshotSHA256));
f=fopen(fullfile(p,string(c.snapshot)),'a');fprintf(f,'tampered');fclose(f);
verifyError(tc,@()inkprof.internal.measurementCheckpoint(p),'inkprof:Integrity');
end
function testPairedRequiresWholeRows(tc)
p=string(tempname);mkdir(p);mkdir(fullfile(p,'paired'));cleanup=onCleanup(@()rmdir(p,'s'));
inkprof.internal.writeJson(fullfile(p,'chart.json'),struct('passesInStrips',2));
inkprof.internal.writeJson(fullfile(p,'measurement-settings.json'),struct('scanMode',"paired"));
inkprof.internal.writeJson(fullfile(p,'paired','chart.json'),struct('passesInStrips',4));
createRaw(fullfile(p,'paired'),4);
verifyError(tc,@()inkprof.internal.measurementCheckpoint(p,[true false false false]),'inkprof:Checkpoint');
inkprof.internal.measurementCheckpoint(p,[true true false false]);
r=inkprof.internal.measurementCheckpoint(p);verifyEqual(tc,r.totalPasses,4);
inkprof.internal.writeJson(fullfile(p,'measurement-settings.json'),struct('scanMode',"single"));
verifyError(tc,@()inkprof.internal.measurementCheckpoint(p),'inkprof:Integrity');
end

function createRaw(folder,total)
chart=jsondecode(fileread(fullfile(folder,'chart.json')));
chart.patches=struct('sampleLoc',cellstr(string(1:total)+"A"));
inkprof.internal.writeJson(fullfile(folder,'chart.json'),chart);
f=fopen(fullfile(folder,'chart.ti3'),'w');
fprintf(f,'CTI3\nCOLOR_REP "RGB_XYZ"\nNUMBER_OF_FIELDS 8\nBEGIN_DATA_FORMAT\nSAMPLE_ID SAMPLE_LOC RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z\nEND_DATA_FORMAT\nNUMBER_OF_SETS %d\nBEGIN_DATA\n',total);
for k=1:total,fprintf(f,'%d %dA 10 20 30 10 20 30\n',k,k);end
fprintf(f,'END_DATA\n');fclose(f);
end
function testTrimHalfRow(tc)
keep=inkprof.internal.completedMeasurementRows([true true true false false false],true);
verifyEqual(tc,keep,[true true false false false false]);
end

function testResumeExplainsPageRowAndDirection(tc)
chart=struct('passesInStrips',[2 2],'patches',struct('sampleLoc',{'1A','2A','3A','4A'}));
c=struct('totalPasses',4,'confirmedPasses',1,'scanMode',"alternating");
t=inkprof.internal.measurementResumeMessage(chart,c);
verifyTrue(tc,contains(t,"page 1 of 2, printed row 2"));verifyTrue(tc,contains(t,"REVERSE"));
plan=struct('passes',struct('page',{1,1,2,2},'physicalRow',{'1','1','2','2'},'rowOnPage',{1,1,1,1}));
c.confirmedPasses=[1 2];c.scanMode="paired";
t=inkprof.internal.measurementResumeMessage(chart,c,plan);
verifyTrue(tc,contains(t,"1 completed rows"));verifyTrue(tc,contains(t,"page 2 of 2, printed row 2"));
verifyTrue(tc,contains(t,"BOTH directions"));verifyTrue(tc,contains(t,"FORWARD"));
end
