% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testPreviousCertificate
tests=functiontests(localfunctions);
end
function testHistoricalEvidenceAndTampering(tc)
root=string(tempname);mkdir(root);cleanup=onCleanup(@()rmdir(root,'s'));
source=fullfile(root,'old');mkdir(source);dest=fullfile(root,'new');mkdir(dest);
file=fullfile(source,'final-report.json');
inkprof.internal.writeJson(file,struct('iteration',1,'profile',struct('sha256',"original-profile")));
a=struct('path',"old/final-report.json",'sha256',inkprof.internal.sha256(file));
s=struct('status',"completed",'outputs',struct('reportJSON',a.path),'artifacts',a);
e=struct('step',"cycle",'status',"archived",'cycle',1,'details',struct('export',s));
w=struct('State',struct('cycle',2,'history',{{e}}),'resolve',@(p)fullfile(root,p));
r=inkprof.internal.previousCertificate(w,dest);
verifyEqual(tc,r.iteration,1);verifyEqual(tc,string(r.profileSHA256),"original-profile");
verifyEqual(tc,inkprof.internal.sha256(fullfile(dest,r.file)),a.sha256);
fid=fopen(file,'a');fprintf(fid,' ');fclose(fid);
verifyError(tc,@()inkprof.internal.previousCertificate(w,dest),'inkprof:Integrity');
end
