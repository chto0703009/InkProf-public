% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testCgats
tests=functiontests(localfunctions);
end
function setupOnce(tc)
r=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(r,'src'));tc.TestData.root=r;
tc.TestData.work=string(tempname);mkdir(tc.TestData.work);
end
function teardownOnce(tc)
rmdir(tc.TestData.work,'s');
end
function testRealSpectralConditions(tc)
base=fullfile(tc.TestData.root,'tests','fixtures','i1profiler','ui-verification-3.8.5');
for mode=["M0","M1","M2"]
 d=inkprof.importCgats(fullfile(base,"InkProf-2040-spectral-M0_"+mode+".txt"));
 v=inkprof.cgatsData(d,RGBScale=255,SpectralScale=1);
 verifySize(tc,v.spectra,[2040 36]);verifyEqual(tc,v.wavelengthNm,380:10:730);
 verifyEqual(tc,v.spectralFraction,v.spectra);verifyEqual(tc,v.rgbPercent,v.rgb/255*100);
 verifyTrue(tc,any(cellfun(@(x)any(contains(x,"MeasurementCondition="+mode)),d.tables.metadata)));
 out=fullfile(tc.TestData.work,mode+".txt");inkprof.exportCgats(out,d);e=inkprof.importCgats(out);
 verifyEqual(tc,e.tables.data,d.tables.data);verifyEqual(tc,inkprof.cgatsData(e).spectra,v.spectra);
 verifyEmpty(tc,inkprof.cgatsData(e).spectralFraction);
 verifyError(tc,@()inkprof.exportCgats(out,d),'inkprof:Exists');
end
end
function testTargetRoundTrip(tc)
f=fullfile(tc.TestData.root,'tests','fixtures','i1profiler','chart-2033','Chart 2033 Patches.txt');
t=inkprof.importTarget(f,RGBScale=255);out=fullfile(tc.TestData.work,'patches.cgats');
inkprof.exportCgats(out,t);u=inkprof.importTarget(out,RGBScale=255);
verifyEqual(tc,t.rgbOriginal,u.rgbOriginal);verifyEqual(tc,t.ids,u.ids);verifyEqual(tc,t.names,u.names);
verifyError(tc,@()inkprof.importTarget(out),'inkprof:Scale');
end
function testMultipleTablesAndMetadata(tc)
raw=sprintf(['CTI3\nKEYWORD "A-B"\nKEYWORD "A_B"\nA-B "# space"\nA_B ""\n' ...
 'NUMBER_OF_FIELDS 5\nBEGIN_DATA_FORMAT\nSAMPLE_ID LAB_L LAB_A LAB_B EXTRA\nEND_DATA_FORMAT\n' ...
 'NUMBER_OF_SETS 2\nBEGIN_DATA\n"001" 50 -2 1 "hello # world"\n"001" 40 3 -4 ""\nEND_DATA\n' ...
 'CAL\nNUMBER_OF_FIELDS 2\nBEGIN_DATA_FORMAT\nRGB_I RGB_R\nEND_DATA_FORMAT\nNUMBER_OF_SETS 1\nBEGIN_DATA\n0 0\nEND_DATA\n']);
f=save(tc,'multiple.txt',raw);d=inkprof.importCgats(f);out=fullfile(tc.TestData.work,'multiple-out.txt');
inkprof.exportCgats(out,d);e=inkprof.importCgats(out);
verifyEqual(tc,numel(e.tables),2);verifyEqual(tc,e.tables(1).data,d.tables(1).data);
verifyEqual(tc,e.tables(1).metadata(1:4),d.tables(1).metadata(1:4));
v=inkprof.cgatsData(e);verifyFalse(tc,v.idsUnique);verifyEqual(tc,v.lab,[50 -2 1;40 3 -4]);
end
function testRejectBadStructureAndSpectra(tc)
base=sprintf('CGATS.17\nNUMBER_OF_FIELDS 3\nBEGIN_DATA_FORMAT\nSAMPLE_ID SPEC_400 SPEC_410\nEND_DATA_FORMAT\nNUMBER_OF_SETS 1\nBEGIN_DATA\na 0.1 0.2\nEND_DATA\n');
f=save(tc,'bad.txt',strrep(base,'NUMBER_OF_SETS 1','NUMBER_OF_SETS 2'));
verifyError(tc,@()inkprof.importCgats(f),'inkprof:CGATS');
f=save(tc,'bad.txt',strrep(base,sprintf('END_DATA\n'),''));verifyError(tc,@()inkprof.importCgats(f),'inkprof:CGATS');
f=save(tc,'bad.txt',base+string(sprintf('garbage\n')));verifyError(tc,@()inkprof.importCgats(f),'inkprof:CGATS');
f=save(tc,'bad.txt',strrep(base,'SPEC_410','SPECTRAL_NM400'));d=inkprof.importCgats(f);
verifyError(tc,@()inkprof.cgatsData(d),'inkprof:CGATS');
f=save(tc,'bad.txt',strrep(base,'CGATS.17',sprintf('CGATS.17\nSPECTRAL_BANDS 3')));d=inkprof.importCgats(f);
verifyError(tc,@()inkprof.cgatsData(d),'inkprof:CGATS');
f=save(tc,'bad.txt',strrep(base,'0.1','NaN'));d=inkprof.importCgats(f);
verifyError(tc,@()inkprof.cgatsData(d),'inkprof:CGATS');
end
function f=save(tc,name,raw)
f=fullfile(tc.TestData.work,name);fid=fopen(f,'w');c=onCleanup(@()fclose(fid));fprintf(fid,'%s',raw);
end
