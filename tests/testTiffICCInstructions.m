% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function tests=testTiffICCInstructions
tests=functiontests(localfunctions);
end
function testConversionAndTagAreIndependent(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
s=inkprof.internal.tiffICCInstructions(struct,"");
verifyTrue(tc,contains(s,'ICC conversion: None by InkProf'));
verifyTrue(tc,contains(s,'Discard the embedded profile'));
verifyTrue(tc,contains(s,'Do NOT use Convert to Profile'));
verifyTrue(tc,contains(s,'Off (No Color Adjustment)'));
verifyFalse(tc,contains(s,'preserve its tag without conversion'));
verifyTrue(tc,contains(s,'Embedded ICC: None'));
f=string(tempname);fid=fopen(f,'w');fwrite(fid,'ICC fixture');fclose(fid);c=onCleanup(@()delete(f));
info=struct('verification',struct('profileApplied',true,'profileName','Printer Glossy'));
s=inkprof.internal.tiffICCInstructions(info,f);
verifyTrue(tc,contains(s,'Applied once - absolute colorimetric, no BPC'));
verifyTrue(tc,contains(s,inkprof.internal.sha256(f)));
verifyTrue(tc,contains(s,'Printer Glossy'));
info.verification.profileApplied=false;s=inkprof.internal.tiffICCInstructions(info,f);
verifyTrue(tc,contains(s,'None - device RGB reference set'));
verifyFalse(tc,contains(s,'Applied once'));
verifyTrue(tc,contains(s,'identifying tag only'));
end
