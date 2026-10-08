% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testICC
tests=functiontests(localfunctions);
end
function testReadAndDialog(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
% Byte-identical import/save applies to v2. V4 requires explicit consent
% and reconstruction, covered separately by testICCV2Compatibility.
source=fullfile(w,'test.icc');f=fopen(source,'w','ieee-be');
fwrite(f,zeros(160,1),'uint8');fseek(f,0,'bof');fwrite(f,160,'uint32');
fseek(f,8,'bof');fwrite(f,[2 32],'uint8');fseek(f,12,'bof');fwrite(f,'prtrRGB Lab ','char');
fseek(f,24,'bof');fwrite(f,[2026 9 27 12 0 0],'uint16');fseek(f,36,'bof');fwrite(f,'acsp','char');
fseek(f,128,'bof');fwrite(f,1,'uint32');fwrite(f,'cprt','char');fwrite(f,[144 13],'uint32');
fseek(f,144,'bof');fwrite(f,'text','char');fwrite(f,0,'uint32');fwrite(f,[double('test') 0],'uint8');fclose(f);
before=inkprof.internal.sha256(source);
[r,file,win]=inkprof.readICC(source,OutputFolder=w,ShowDialog=true);closeUI=onCleanup(@()delete(win));
verifyEqual(tc,string(r.header.version),"2.2.0");verifyTrue(tc,isfile(file));verifyTrue(tc,isvalid(win));
verifyEqual(tc,inkprof.internal.sha256(source),before);verifyFalse(tc,r.capabilities.lutEvaluated);
project=inkprof.createProject(fullfile(w,'project'));
[imported,record]=inkprof.importICC(source,project);
verifyEqual(tc,inkprof.internal.sha256(imported),before);
verifyEqual(tc,string(record.source.path),"test.icc");
manifest=jsondecode(fileread(fullfile(project,'inkprof-project.json')));
verifyEqual(tc,manifest.unresolvedLinkCount,0);
[out,receipt]=inkprof.saveICC(imported,fullfile(w,'renamed.icm'));
verifyTrue(tc,receipt.byteIdentical);verifyEqual(tc,inkprof.internal.sha256(out),before);
verifyError(tc,@()inkprof.saveICC(imported,out),'inkprof:Exists');
inkprof.saveICC(imported,out,Overwrite=true);
verifyEqual(tc,inkprof.internal.sha256(out),before);
verifyError(tc,@()inkprof.saveICC(imported,imported),'inkprof:SameFile');
bad=fullfile(w,'bad.icc');fid=fopen(bad,'w');fprintf(fid,'broken');fclose(fid);
verifyError(tc,@()inkprof.saveICC(bad,out,Overwrite=true),'inkprof:PythonRun');
verifyEqual(tc,inkprof.internal.sha256(out),before);
% Imported profile remains usable when the project folder moves.
moved=fullfile(w,'moved-project');movefile(project,moved);
portable=fullfile(moved,record.source.projectRelativePath);
verifyTrue(tc,isfile(portable));verifyEqual(tc,inkprof.internal.sha256(portable),before);
end
