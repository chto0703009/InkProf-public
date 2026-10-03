function info=snapshotVerification(file,job,destination)
% Preserve the current C2 design without applying the ICC a second time.
r=jsondecode(fileread(file));profile=fullfile(job,'result','profile.icc');
assert(string(r.documentType)=="inkprof.verification-target"&&string(r.printerProfile.sha256)==inkprof.internal.sha256(profile), ...
 'inkprof:Verification','C2 belongs to a different ICC profile.');
assert(string(r.trainingTI3SHA256)==inkprof.internal.sha256(fullfile(job,'engine.ti3')),'inkprof:Verification','C2 training inputs differ.');
source=fileparts(file);mkdir(destination);copyfile(fullfile(source,'definition'),fullfile(destination,'definition'));
copyfile(file,fullfile(destination,'verification.json'));
assert(inkprof.internal.sha256(fullfile(destination,r.printerProfile.file))==string(r.printerProfile.sha256),'inkprof:Integrity','C2 printer profile changed.');
assert(inkprof.internal.sha256(fullfile(destination,r.definitions.file))==string(r.definitions.sha256),'inkprof:Integrity','C2 definition changed.');
info=struct('file',"sources/c2/verification.json",'sha256',inkprof.internal.sha256(fullfile(destination,'verification.json')), ...
 'patchCount',numel(r.patches),'role',"fit (repeat/paper-white controls excluded)",'parentProfileSHA256',r.printerProfile.sha256,'status',"Included for measurement; not yet verified");
end
