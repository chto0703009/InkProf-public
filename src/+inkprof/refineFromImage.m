function [proposal,folder]=refineFromImage(jobFile,options)
%REFINEFROMIMAGE Select arbitrary image colours for device-RGB refinement.
arguments
 jobFile (1,1) string
 options.Image (1,1) string = ""
 options.FitReport (1,1) string = ""
 options.SourceProfile (1,1) string = "embedded"
 options.ROI (1,:) double = []
 options.Name (1,1) string = "Image-guided refinement"
 options.MaxNewPatches (1,1) double {mustBeInteger,mustBePositive} = 100
 options.MinSpacingPercent (1,1) double {mustBeFinite,mustBePositive} = 1
 options.NeighborRadiusPercent (1,1) double {mustBeFinite,mustBeNonnegative} = 0
 options.ShowDialog (1,1) logical = true
 options.CreatePrint (1,1) logical = true
 options.PlanPaper (1,1) logical = true
 options.DPI (1,1) double {mustBeInteger,mustBePositive} = 300
 options.Paper (1,1) string = "A4-landscape"
 options.Seed (1,1) double {mustBeInteger,mustBeNonnegative} = 42
end
proposal=[];folder="";paths=inkprof.paths();jobFile=inkprof.internal.absolutePath(jobFile);
job=fileparts(jobFile);project=inkprof.internal.findProject(job);
assert(project~="",'inkprof:Project','Select a profile job in an InkProf project.');
state=jsondecode(fileread(jobFile));profile=fullfile(job,'result','profile.icc');training=fullfile(job,'engine.ti3');
assert(string(state.status)=="succeeded"&&inkprof.internal.sha256(profile)==string(state.profileSHA256),'inkprof:Integrity','Parent ICC job is not valid.');
assert(isfile(training),'inkprof:Image','The parent job has no training measurements.');
work=string(tempname);mkdir(work);cleanup=onCleanup(@()rmdir(work,'s'));
image=options.Image;assumed=false;sourceProfile=options.SourceProfile;
while true
 if image==""
  assert(options.ShowDialog,'inkprof:Image','Specify Image.');
  [n,p]=uigetfile({'*.tif;*.tiff;*.png;*.jpg;*.jpeg','RGB images (8/16-bit TIFF, PNG, JPEG)'},'Select image for refinement');
  if isequal(n,0),return;end;image=string(fullfile(p,n));
 end
 calculation=inkprof.internal.calculationProgress("Reading image profile","Reading image metadata and checking the Python runtime.");
 image=inkprof.internal.absolutePath(image);imageDigest=inkprof.internal.sha256(image);
 inkprof.runPython(fullfile(paths.Root,'analysis','image_refinement.py'),[image,fullfile(work,'image-info.json'),"--inspect"],RequiredModules=["numpy","scipy","colour","PIL"]);
 info=jsondecode(fileread(fullfile(work,'image-info.json')));clear calculation;
 if sourceProfile=="embedded"&&~info.hasEmbeddedProfile
  if ~options.ShowDialog,error('inkprof:ImageProfile','Image has no embedded profile. Set SourceProfile="sRGB" explicitly, or choose a tagged image.');end
  choice=questdlg('This image has no embedded colour profile. sRGB will be used unless you choose another image. If the image is actually Adobe RGB or another space, select a correctly tagged image instead.', ...
   'Missing image colour profile','Use sRGB','Choose another image','Cancel','Use sRGB');
  if strcmp(choice,'Choose another image'),image="";continue;end
  if ~strcmp(choice,'Use sRGB'),return;end
  sourceProfile="sRGB";assumed=true;
 end
 break
end
settings=struct('ROI',options.ROI,'MaxNewPatches',options.MaxNewPatches,'MinSpacingPercent',options.MinSpacingPercent,'NeighborRadiusPercent',options.NeighborRadiusPercent);
if options.ShowDialog
 description=sourceProfile;if sourceProfile=="embedded",description=string(info.description);elseif assumed,description="sRGB (assumed after missing-profile warning)";end
 settings=inkprof.internal.imageRefinementDialog(image,settings,description);if isempty(settings),return;end
end
calculation=inkprof.internal.calculationProgress("Calculating image patches","Converting image colours through the ICC profiles, selecting patches and estimating local errors.");
[pixels,map,alpha]=imread(image);
assert(isempty(map)&&ndims(pixels)==3&&size(pixels,3)==3&&any(strcmp(class(pixels),{'uint8','uint16'})), ...
 'inkprof:Image','Use a true-colour 8-bit or 16-bit RGB image. Convert CMYK, indexed or floating-point images before import.');
[h,width,~]=size(pixels);roi=settings.ROI;if isempty(roi),roi=[1 1 width h];end
assert(numel(roi)==4&&all(isfinite(roi))&&all(roi==round(roi))&&all(roi>=1)&&roi(1)+roi(3)-1<=width&&roi(2)+roi(4)-1<=h,'inkprof:Image','Invalid pixel rectangle.');
% Deterministic spatial sampling retains original 8/16-bit channel precision.
stride=max(1,ceil(sqrt(roi(3)*roi(4)/100000)));ys=roi(2):stride:roi(2)+roi(4)-1;xs=roi(1):stride:roi(1)+roi(3)-1;
samples=reshape(double(pixels(ys,xs,:))/double(intmax(class(pixels))),[],3);
if ~isempty(alpha)
 opaque=alpha(ys,xs)==intmax(class(alpha));samples=samples(opaque(:),:);
end
assert(~isempty(samples),'inkprof:Image','No fully opaque pixels in the selected image area.');
v=inkprof.cgatsData(inkprof.importCgats(training),RGBScale=100);
bin=inkprof.internal.argyllBin("");exe=fullfile(bin,'xicclu');if ispc,exe=exe+".exe";end
selection=struct('rectangleXYWH',roi,'imageWidth',width,'imageHeight',h,'coordinateConvention',"1-based stored pixels; no automatic EXIF rotation", ...
 'sampleStride',stride,'inputBitDepth',8*(1+isa(pixels,'uint16')),'alphaHandling',"Only fully opaque pixels sampled");
request=struct('fitReport',options.FitReport,'trainingSHA256',inkprof.internal.sha256(training),'image',image,'imageSHA256',imageDigest,'sourceProfile',sourceProfile, ...
 'profile',profile,'xicclu',exe,'samples',samples,'existingRGBPercent',v.rgb,'selection',selection, ...
 'maxPatches',settings.MaxNewPatches,'minSpacingPercent',settings.MinSpacingPercent,'neighborRadiusPercent',settings.NeighborRadiusPercent);
inkprof.internal.writeJson(fullfile(work,'request.json'),request);
stage=fullfile(work,'proposal');
inkprof.runPython(fullfile(paths.Root,'analysis','image_refinement.py'),[fullfile(work,'request.json'),stage],RequiredModules=["numpy","scipy","colour","PIL"],TimeoutSeconds=180);
proposal=jsondecode(fileread(fullfile(stage,'proposal.json')));
assert(~isempty(proposal.candidates),'inkprof:Image','No new patches remain at this spacing. Try a smaller spacing, another image area, or a neighbor radius.');
proposal.imageProfile.assumedSRGB=assumed||(~info.hasEmbeddedProfile&&sourceProfile=="sRGB");
proposal.imageProfile.warningAcknowledged=assumed;
proposal.name=options.Name;proposal.iterationId=string(java.util.UUID.randomUUID());
proposal.createdUTC=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
clear calculation;
selected=1:numel(proposal.candidates);reviewFilter=struct;
if options.ShowDialog
 [selected,reviewFilter]=inkprof.internal.reviewImageCandidates(proposal);if isempty(selected),proposal=[];return;end
end
calculation=inkprof.internal.calculationProgress("Saving image selection","Saving selected patches, the source image and profile records in the project.");
proposal.selection=struct('proposedCount',numel(proposal.candidates),'selectedPatchIds',string({proposal.candidates(selected).patchId}), ...
 'reviewed',options.ShowDialog,'selectedCount',numel(selected),'filter',reviewFilter);
inkprof.internal.writeJson(fullfile(stage,'proposed-candidates.json'),proposal.candidates);
proposal.candidates=proposal.candidates(selected);proposal.status="selected-for-print";
context=struct('profileJob',replace(extractAfter(job,strlength(project)+1),filesep,'/'),'trainingTI3SHA256',inkprof.internal.sha256(training));
inkprof.internal.writeJson(fullfile(stage,'sources','context.json'),context);
copyfile(image,fullfile(stage,proposal.image.file));copyfile(profile,fullfile(stage,'sources','profile.icc'));copyfile(training,fullfile(stage,'sources','training.ti3'));
assert(inkprof.internal.sha256(fullfile(stage,proposal.image.file))==string(proposal.image.sha256),'inkprof:Integrity','Source image changed.');
assert(inkprof.internal.sha256(fullfile(stage,'sources','profile.icc'))==string(proposal.sourceProfileSHA256),'inkprof:Integrity','Source ICC changed.');
proposal.snapshots=struct('context',"sources/context.json",'profile',"sources/profile.icc",'training',"sources/training.ti3",'image',proposal.image.file,'imageProfile',proposal.imageProfile.file);
assert(inkprof.internal.sha256(fullfile(stage,'sources','training.ti3'))==string(context.trainingTI3SHA256),'inkprof:Integrity','Training measurements changed.');
folder=fullfile(project,'refinements',proposal.iterationId);if ~isfolder(fileparts(folder)),mkdir(fileparts(folder));end;movefile(stage,folder);
inkprof.internal.writeJson(fullfile(folder,'proposal.json'),proposal);
clear calculation;
if options.CreatePrint
 proposal.print=inkprof.internal.createRefinementPrint(proposal,job,fullfile(folder,'refinement-print'),options.DPI,options.Paper,options.Seed,options.PlanPaper);
 inkprof.internal.writeJson(fullfile(folder,'proposal.json'),proposal);
end
inkprof.internal.recordProjectStep(folder,"Image-guided refinement: "+numel(proposal.candidates)+" selected patches; device RGB, no ICC applied");
fprintf('InkProf: %d image-guided patches saved in %s\n',numel(proposal.candidates),folder);
end
