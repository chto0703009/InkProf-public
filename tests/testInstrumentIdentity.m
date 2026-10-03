% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testInstrumentIdentity
tests=functiontests(localfunctions);
end
function testLinkedTranscriptAndUnknown(tc)
p=string(tempname);mkdir(p);c=onCleanup(@()rmdir(p,'s')); %#ok<NASGU>
mkdir(fullfile(p,'paired'));file=fullfile(p,'paired','transcript-1.txt');
f=fopen(file,'w');fprintf(f,'Serial Number:     1001799\n');fclose(f);
condition=struct('instrument',"X-Rite i1 Pro 2",'transcriptSHA256',inkprof.internal.sha256(file));
r=inkprof.internal.instrumentIdentity(p,condition);
verifyEqual(tc,r.model,"X-Rite i1 Pro 2");verifyEqual(tc,r.serialNumber,"1001799");verifyFalse(tc,r.calibrationVerified);
condition.transcriptSHA256="wrong";r=inkprof.internal.instrumentIdentity(p,condition);verifyEqual(tc,r.serialNumber,"unknown");
condition.transcriptSHA256=inkprof.internal.sha256(file);condition.instrumentSerial="different";
verifyError(tc,@()inkprof.internal.instrumentIdentity(p,condition),'inkprof:Instrument');
end
function testCaptureAtImport(tc)
p=string(tempname);mkdir(p);c=onCleanup(@()rmdir(p,'s')); %#ok<NASGU>
f=fopen(fullfile(p,'transcript-1.txt'),'w');fprintf(f,'Serial Number: 001234\n');fclose(f);
cnd=inkprof.internal.measurementCondition(p,"unused",{{'TARGET_INSTRUMENT','X-Rite i1 Pro 2'}});
verifyEqual(tc,cnd.instrumentSerial,"001234");verifyTrue(tc,isfield(cnd,'transcriptSHA256'));
end
