% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testMeasurementRevisions
tests=functiontests(localfunctions);
end
function testOnlyIntactCompleteMatchingRevisions(tc)
root=string(tempname);mkdir(root);c=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
target=fullfile(root,'target.ti2');write(target,'target');
chart=fullfile(root,'chart.json');inkprof.internal.writeJson(chart,struct('sourceSHA256',inkprof.internal.sha256(target)));
m=struct('documentType','inkprof.chart-measurement','complete',true,'measuredSourcePatches',2033,'expectedSourcePatches',2033,'chartJSONSHA256',inkprof.internal.sha256(chart),'patchOverrides',struct('id',1));
for name=["good","incomplete","tampered"]
 ti3=fullfile(root,'measurement-'+name+'.ti3');write(ti3,'measurement');m.sourceTI3SHA256=inkprof.internal.sha256(ti3);m.complete=name~="incomplete";
 inkprof.internal.writeJson(fullfile(root,'measurement-'+name+'.json'),m);
end
write(fullfile(root,'measurement-tampered.ti3'),'changed');
inkprof.internal.writeJson(fullfile(root,'measurement-settings.json'),struct('documentType','settings'));
r=inkprof.internal.measurementRevisions(root,target);
verifyNumElements(tc,r,1);verifyTrue(tc,endsWith(r.file,'measurement-good.json'));
verifyTrue(tc,contains(r.label,'2033 / 2033 patches | Complete'));verifyTrue(tc,startsWith(r.label,'Latest saved'));
write(target,'different target');verifyEmpty(tc,inkprof.internal.measurementRevisions(root,target));
end
function write(file,text)
f=fopen(file,'w');fprintf(f,'%s',text);fclose(f);
end
