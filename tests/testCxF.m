function tests=testCxF
tests=functiontests(localfunctions);
end
function setupOnce(tc)
r=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(r,'src'));tc.TestData.source=fullfile(r,'tests','fixtures','cxf','rgb-spectrum.cxf');
end
function testReadAndImport(tc)
d=inkprof.readCxF(tc.TestData.source);verifyTrue(tc,d.validation.xsdValidated);
t=inkprof.importTarget(tc.TestData.source);verifyEqual(tc,t.rgbOriginal,[10 20 30]);verifyEqual(tc,t.rgbScale,100);
verifyError(tc,@()inkprof.importTarget(tc.TestData.source,RGBScale=255),'inkprof:Scale');
end
function testInvalidSchema(tc)
f=string(tempname)+".cxf";c=onCleanup(@()delete(f));
s=fileread(tc.TestData.source);fid=fopen(f,'w');fprintf(fid,'%s',strrep(s,'<R>10</R>','<R>10.5</R>'));fclose(fid);
verifyError(tc,@()inkprof.readCxF(f),'inkprof:CxFSchema');
end
function testDuplicateIdentity(tc)
f=string(tempname)+".cxf";c=onCleanup(@()delete(f));s=fileread(tc.TestData.source);
object=regexp(s,'<Object Id=.*?</Object>','match','once');s=strrep(s,'</ObjectCollection>',[object '</ObjectCollection>']);
fid=fopen(f,'w');fprintf(fid,'%s',s);fclose(fid);verifyError(tc,@()inkprof.readCxF(f),'inkprof:CxFSchema');
end
function testSavedJSON(tc)
f=string(tempname)+".json";c=onCleanup(@()delete(f));[d,p]=inkprof.readCxF(tc.TestData.source,OutputFile=f);verifyEqual(tc,p,f);
r=jsondecode(fileread(p));verifyEqual(tc,r.sourceSHA256,d.sourceSHA256);
verifyError(tc,@()inkprof.readCxF(tc.TestData.source,OutputFile=f),'inkprof:Exists');
end
