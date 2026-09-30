function tests=testMeasurementImport
tests=functiontests(localfunctions);
end
function setupOnce(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));tc.TestData.root=root;
end
function testMxfSpotAndTi3Roundtrip(tc)
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
source=fullfile(tc.TestData.root,'tests','fixtures','rgb-reflectance.mxf');hash=inkprof.internal.sha256(source);
[r,file,folder]=inkprof.importMeasurement(source,SessionFolder=fullfile(w,'mxf'),ShowPreview=false);
verifyTrue(tc,r.complete);verifyEqual(tc,r.measuredSourcePatches,7);verifyEqual(tc,string(r.measurementCondition.interpreted),"M0");
verifyEqual(tc,inkprof.internal.sha256(fullfile(folder,'original.mxf')),hash);
fig=inkprof.previewMeasurement(folder,r);c=onCleanup(@()delete(fig));verifyEqual(tc,numel(findall(fig,'Tag','measurementPatch')),4);clear c
attempt=inkprof.preparePatchRemeasurement(file,'B1');q=jsondecode(fileread(fullfile(attempt,'request.json')));verifyEqual(tc,string(q.instrumentSerial),"TEST");
i=q.measurementIndex;
candidate=struct('schemaVersion',1,'documentType','inkprof.spot-candidate','request',q, ...
 'calibrationStandard','XRGA','spectralScale',100,'illuminant','D50','observer','1931_2', ...
 'measurementCondition','M0 (test)','instrumentSerial','TEST','wavelengthNm',r.data.wavelengthNm, ...
 'xyz',r.data.xyz(i,:)+.1,'lab',[50 1 2],'spectra',r.data.spectra(i,:)+.1);
p=fullfile(attempt,'candidate.json');inkprof.internal.writeJson(p,candidate);
bad=candidate;bad.instrumentSerial='OTHER';inkprof.internal.writeJson(p,bad);
verifyError(tc,@()inkprof.acceptPatchRemeasurement(file,p),'inkprof:Instrument');
inkprof.internal.writeJson(p,candidate);[updated,newFile]=inkprof.acceptPatchRemeasurement(file,p);
verifyTrue(tc,isfile(newFile));verifyEqual(tc,inkprof.internal.sha256(source),hash);
other=setdiff(1:7,i);verifyEqual(tc,updated.data.spectra(other,:),r.data.spectra(other,:));
verifyEqual(tc,updated.data.spectra(i,:),candidate.spectra);saved=jsondecode(fileread(file));verifyEqual(tc,updated.importInfo,saved.importInfo);
[again,~,~]=inkprof.importMeasurement(updated.sourcePath,TargetFile=fullfile(folder,'source.ti2'),SessionFolder=fullfile(w,'ti3'),ShowPreview=false);
verifyEqual(tc,again.data.spectra,updated.data.spectra,'AbsTol',1e-10);verifyEqual(tc,again.data.xyz,updated.data.xyz,'AbsTol',1e-10);
verifyEqual(tc,string(again.measurementCondition.interpreted),"M0");
bad=inkprof.importCgats(updated.sourcePath);bad.tables.data(1,bad.tables.fields=="RGB_R")="0";badFile=fullfile(w,'bad.ti3');inkprof.exportCgats(badFile,bad);
verifyError(tc,@()inkprof.importMeasurement(badFile,TargetFile=fullfile(folder,'source.ti2'),SessionFolder=fullfile(w,'invalid'),ShowPreview=false),'inkprof:Identity');
verifyFalse(tc,isfolder(fullfile(w,'invalid')));
verifyError(tc,@()inkprof.importMeasurement(fullfile(folder,'source.ti2'),ShowPreview=false),'inkprof:MeasurementFile');
verifyError(tc,@()inkprof.importMeasurement(source,SessionFolder=folder,ShowPreview=false),'inkprof:Exists');
end
