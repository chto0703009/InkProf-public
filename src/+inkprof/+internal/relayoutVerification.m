function folder=relayoutVerification(referenceFile,folder)
% Preserve frozen reference RGB/Lab, replace only their print placement.
reference=jsondecode(fileread(referenceFile));old=fileparts(referenceFile);
assert(~isfolder(folder),'inkprof:Exists','Output exists.');
source=fullfile(old,'definition','verification.ti1');
target=inkprof.importTarget(source);
choice=inkprof.internal.paperLayoutDialog(numel(target.ids),inkprof.internal.findProject(referenceFile),source);
assert(~isempty(choice),'inkprof:Cancelled','Paper selection cancelled.');
mkdir(folder);copyfile(fullfile(old,'definition'),fullfile(folder,'definition'));
oldTarget=jsondecode(fileread(fullfile(old,'print','target.json')));
manifest=inkprof.createTarget(fullfile(folder,'print'),Source=fullfile(folder,'definition','verification.ti1'), ...
 TargetInfo=oldTarget.targetInfo,PaperSizeMm=choice.paperSizeMm,PaperLayout=choice, ...
 Randomize=true,Seed=20260928,DPI=reference.printPackage.dpi,SpacerMode="bw");
layout=jsondecode(fileread(fullfile(folder,'print','layout.json')));
for k=1:numel(reference.patches)
 matches=find(~[layout.patches.isPadding] & string({layout.patches.originalId})==string(reference.patches(k).id));
 assert(numel(matches)==1,'inkprof:Identity','Missing or duplicate verification patch placement.');
 p=layout.patches(matches);
 assert(isequal(double(p.rgb16(:)'),double(reference.patches(k).deviceRGB16(:)')),'inkprof:Identity','Rendered RGB differs from profiled definition.');
 reference.patches(k).placement=struct('page',p.page,'coordinate',p.coordinate,'sampleId',p.sampleId,'location',p.location,'tiff',"print/"+string(p.tiff));
end
reference.status="ready-to-print-not-measured";
reference.sourceProfile.file="definition/source-Lab-D50.icc";reference.printerProfile.file="definition/printer.icc";
reference.definitions.file="definition/verification.ti1";
reference.printPackage=struct('folder',"print",'manifestSHA256',inkprof.internal.sha256(fullfile(folder,'print','manifest.json')), ...
 'ti2',"print/target.ti2",'ti2SHA256',inkprof.internal.sha256(fullfile(folder,'print','target.ti2')), ...
 'pageCount',manifest.pageCount,'dpi',manifest.options.DPI,'paper',"custom",'paperSizeMm',manifest.renderPaperSizeMm);

inkprof.internal.writeJson(fullfile(folder,'verification.json'),reference);
copyfile(fullfile(old,'PRINTING.txt'),fullfile(folder,'PRINTING.txt'));
end
