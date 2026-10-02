function [recipeFile,recipe]=createProfileRecipe(inputFolder,options)
%CREATEPROFILERECIPE Save an explicit B2 recipe; does not generate an ICC.
arguments
 inputFolder (1,1) string = ""
 options.Name (1,1) string = ""
 options.Description (1,1) string = ""
 options.DataMode (1,1) string {mustBeMember(options.DataMode,["spectral","storedXYZ"])} = "spectral"
 options.B2AQuality (1,1) string {mustBeMember(options.B2AQuality,["medium","high"])} = "high"
 options.A2BQuality (1,1) string {mustBeMember(options.A2BQuality,["medium","high"])} = "medium"
 options.Smoothing (1,1) double = NaN
 options.Printing (1,1) struct = struct
 options.ShowDialog (1,1) logical = true
 options.ProjectPrinting (1,1) logical = false
end
recipeFile="";recipe=[];
if inputFolder==""
 [n,p]=uigetfile('profile-input.json','Select locked B1 profile input');
 if isequal(n,0),return;end
 inputFolder=string(p);
end
inputFolder=inkprof.internal.absolutePath(inputFolder);
if isfile(inputFolder),inputFolder=fileparts(inputFolder);end
inputFile=fullfile(inputFolder,'profile-input.json');
assert(isfile(inputFile),'inkprof:RecipeInput','Select a B1 folder containing profile-input.json.');
inputHash=inkprof.internal.sha256(inputFile);input=jsondecode(fileread(inputFile));
assert(string(input.documentType)=="inkprof.profile-input"&&input.schemaVersion==1&& ...
 string(input.status)=="locked-input-not-profiled",'inkprof:RecipeInput','Unsupported B1 input.');
verifyInput(inputFolder,input);
v=inkprof.cgatsData(inkprof.importCgats(fullfile(inputFolder,'profiling.ti3')),RGBScale=100);
assert(isempty(v.cmyk)&&size(v.rgb,2)==3&&numel(v.ids)==input.patchCount,'inkprof:RecipeInput','Expected locked RGB patch data.');
printing=input.printing;
project=inkprof.internal.findProject(inputFolder);
projectPrinting=options.ProjectPrinting;
if project~=""
 manifest=jsondecode(fileread(fullfile(project,'inkprof-project.json')));
 printing=manifest.printing;projectPrinting=true;
end
for key=string(fieldnames(options.Printing))',printing.(key)=options.Printing.(key);end
for key=["printer","paper","paperSurface","media","quality","driver","printPath","colorManagement"]
 if ~isfield(printing,key),printing.(key)="unknown";end
 if isfield(options.Printing,key),printing.(key)=options.Printing.(key);end
end
name=options.Name;if name=="",name=string(input.name);end
description=options.Description;if description=="",description=name;end
settings=struct('name',name,'description',description,'dataMode',options.DataMode,'b2aQuality',options.B2AQuality,'printing',printing,'projectPrinting',projectPrinting);
if options.ShowDialog
 [accepted,settings]=inkprof.internal.profileRecipeDialog(settings,input,~isempty(v.spectra),~isempty(v.xyz));
 if ~accepted,return;end
end
assert(strlength(strtrim(settings.name))>0&&strlength(strtrim(settings.description))>0, ...
 'inkprof:RecipeName','Profile name and description are required.');
if settings.dataMode=="spectral"
 assert(~isempty(v.spectra),'inkprof:RecipeData','This input has no spectral data. Select stored XYZ explicitly.');
 colorimetry=struct('mode',"spectral",'illuminant',"D50",'observer',"1931_2", ...
  'fwaCompensation',false,'engine',"ArgyllCMS colprof",'inputPreparation',"retain spectra; force spectral integration with -i D50 -o 1931_2");
 args=["-qm","-al","-i","D50","-o","1931_2"];
else
 assert(~isempty(v.xyz),'inkprof:RecipeData','This input has no stored XYZ values.');
 colorimetry=struct('mode',"storedXYZ",'illuminant',"as stored; not independently established by B2", ...
 'observer',"as stored; not independently established by B2",'fwaCompensation',false, ...
 'engine',"ArgyllCMS colprof",'inputPreparation',"remove spectral and Lab columns and spectral metadata from build copy; preserve stored XYZ unchanged");
 args=["-qm","-al"];
end
assert(isnan(options.Smoothing)||(isfinite(options.Smoothing)&&options.Smoothing>0), ...
 'inkprof:RecipeSmoothing','Smoothing must be positive, or NaN for the engine default.');
if options.A2BQuality=="high",args(1)="-qh";end
if ~isnan(options.Smoothing),args=[args,"-r",string(sprintf('%.17g',options.Smoothing))];end
if settings.b2aQuality=="high",args=[args,"-bh"];else,args=[args,"-bm"];end
args=[args,"-D",string(settings.description)];
if string(settings.printing.paperSurface)=="Matte",args=[args,"-Z","m"];end
% A pending dialog may outlive edits to the source. Check again before saving.
assert(inkprof.internal.sha256(inputFile)==inputHash,'inkprof:Integrity','B1 metadata changed while editing the recipe.');verifyInput(inputFolder,input);
recipe=struct('schemaVersion',1,'documentType',"inkprof.profile-recipe", ...
 'createdUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
 'name',settings.name,'description',settings.description,'inputFile',"../../profile-input.json", ...
 'inputSHA256',inputHash,'profilingTI3SHA256',input.profilingTI3SHA256, ...
 'patchCount',input.patchCount,'measurementCondition',input.measurementCondition, ...
 'printing',settings.printing,'printingBasis',"Project definition at recipe creation, or explicit standalone declarations; B1 is unchanged", ...
 'colorimetry',colorimetry,'engine',struct('name',"ArgyllCMS colprof", ...
 'quality',options.A2BQuality,'smoothing',options.Smoothing,'b2aQuality',settings.b2aQuality,'algorithm',"Lab cLUT",'plannedArguments',args, ...
 'version',"record at build time",'iccVersion',"inspect generated file",'gamutMapping',"engine default; no source gamut supplied"), ...
 'status',"recipe-saved-not-built");
base=fullfile(inputFolder,'recipes');if ~isfolder(base),mkdir(base);end
stage=string(tempname(base));mkdir(stage);cleanup=onCleanup(@()removeStage(stage));
inkprof.internal.writeJson(fullfile(stage,'recipe.json'),recipe);
roundtrip=jsondecode(fileread(fullfile(stage,'recipe.json')));
assert(string(roundtrip.inputSHA256)==inputHash&&string(roundtrip.colorimetry.mode)==string(settings.dataMode),'inkprof:Integrity','Recipe roundtrip failed.');
folder=fullfile(base,string(java.util.UUID.randomUUID()));[ok,msg]=movefile(stage,folder);assert(ok,'inkprof:IO','%s',msg);
recipeFile=fullfile(folder,'recipe.json');inkprof.internal.recordProjectStep(folder,"Saved ICC profiling recipe (B2); no profile generated");
fprintf('InkProf B2: recipe saved (%s). No ICC generated.\nRecipe: %s\n',settings.dataMode,recipeFile);
end
function verifyInput(folder,input)
files=["measurement.json","chart.json","source.ti3","profiling.ti3"];
keys=["measurementSHA256","chartJSONSHA256","sourceTI3SHA256","profilingTI3SHA256"];
for k=1:numel(files)
 p=fullfile(folder,files(k));assert(isfile(p)&&inkprof.internal.sha256(p)==string(input.(keys(k))), ...
 'inkprof:Integrity','Locked B1 file missing or changed: %s.',files(k));
end
end
function removeStage(p)
if isfolder(p),rmdir(p,'s');end
end
