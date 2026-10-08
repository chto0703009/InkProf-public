% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [recipeFile,recipe]=createProfileRecipe(inputFolder,options)
%CREATEPROFILERECIPE Save an explicit B2 recipe; does not generate an ICC.
arguments
 inputFolder (1,1) string = ""
 options.Name (1,1) string = ""
 options.Description (1,1) string = ""
 options.DataMode (1,1) string {mustBeMember(options.DataMode,["","spectral","storedXYZ"])} = ""
 options.B2AQuality (1,1) string {mustBeMember(options.B2AQuality,["","medium","high"])} = ""
 options.A2BQuality (1,1) string {mustBeMember(options.A2BQuality,["medium","high"])} = "medium"
 options.PerceptualCompression (1,1) double {mustBePositive,mustBeFinite} = 20
 options.Smoothing (1,1) double = 0.5
 options.GradientPreview (1,1) logical = false
 options.PreRegularization (1,1) string {mustBeMember(options.PreRegularization,["off","argyll-colprof"])} = "off"
 options.PreRegularizationAvgDev (1,1) double = 0.5
 options.Printing (1,1) struct = struct
 options.ShowDialog (1,1) logical = true
 options.ProjectPrinting (1,1) logical = false
 options.PaperWhiteReferenceFile (1,1) string = ""
 options.PaperWhiteReference (1,1) struct = struct
 options.SyncProjectFWA (1,1) logical = true
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
for key=["printer","paper","paperSurface","inkType","media","quality","driver","printPath","colorManagement","dryingHours","printerCoating","coatingSettings"]
 if ~isfield(printing,key),printing.(key)="unknown";end
 if isfield(options.Printing,key),printing.(key)=options.Printing.(key);end
end
name=options.Name;if name==""
 if project~="",name=string(manifest.name);else,name=string(input.name);end
 name=projectValue(printing,'profileName',name);
end
description=options.Description;if description=="",description=projectValue(printing,'profileDescription',name);end
if options.DataMode=="",options.DataMode=projectValue(printing,'profileDataMode',"spectral");end
if options.B2AQuality=="",options.B2AQuality=projectValue(printing,'profileB2AQuality',"high");end
assert(any(options.DataMode==["spectral","storedXYZ"]),'inkprof:RecipeData','Invalid project colour data setting.');
assert(any(options.B2AQuality==["medium","high"]),'inkprof:RecipeData','Invalid project B2A quality setting.');
settings=struct('perceptualCompression',options.PerceptualCompression,'name',name,'description',description,'dataMode',options.DataMode,'b2aQuality',options.B2AQuality,'smoothing',options.Smoothing,'gradientPreview',options.GradientPreview,'printing',printing,'projectPrinting',projectPrinting, ...
 'preRegularization',options.PreRegularization,'preRegularizationAvgDev',options.PreRegularizationAvgDev);
if options.ShowDialog
 [accepted,settings]=inkprof.internal.profileRecipeDialog(settings,input,~isempty(v.spectra),~isempty(v.xyz));
 if ~accepted,return;end
end
assert(strlength(strtrim(settings.name))>0&&strlength(strtrim(settings.description))>0, ...
 'inkprof:RecipeName','Profile name and description are required.');
fwa=isfield(settings.printing,'fwaCompensation')&&isequal(settings.printing.fwaCompensation,true);
if fwa
 assert(settings.dataMode=="spectral",'inkprof:FWA','FWA/OBA requires spectra, not stored XYZ.');
 c=input.measurementCondition;
 assert(isfield(c,'interpreted')&&string(c.interpreted)=="M0"&& ...
  isfield(c,'instrument')&&strlength(string(c.instrument))>0&& ...
  (~isfield(c,'instrumentFilter')||string(c.instrumentFilter)~="UVCUT")&& ...
  (~isfield(c,'fwaApplied')||~c.fwaApplied), ...
  'inkprof:FWA','FWA/OBA requires native M0 spectra with a known, non-UV-filtered instrument; unknown, M1, M2 or already compensated data cannot be used.');
 assert(~isempty(v.wavelengthNm)&&min(v.wavelengthNm)<=400&&max(v.wavelengthNm)>=700,'inkprof:FWA','FWA requires measured spectral coverage at or below 400 nm through at least 700 nm. A blank-paper reading cannot replace missing colour spectra.');
 whiteReference=struct;
 whiteData=v;whiteSourceHash=input.profilingTI3SHA256;
 if ~any(all(v.rgb>99.9,2))
  original=inkprof.cgatsData(inkprof.importCgats(fullfile(inputFolder,'source.ti3')),RGBScale=100);
  if ~isempty(original.spectra)&&isequal(original.wavelengthNm,v.wavelengthNm)&&any(all(original.rgb>99.9,2))
   whiteData=original;whiteSourceHash=input.sourceTI3SHA256;
  end
 end
 whiteIndices=find(all(whiteData.rgb>99.9,2));
 if ~isempty(whiteIndices)
  samples=repmat(struct('sampleId',"",'spectrum',[]),numel(whiteIndices),1);
  for q=1:numel(whiteIndices),samples(q).sampleId=whiteData.ids(whiteIndices(q));samples(q).spectrum=whiteData.spectra(whiteIndices(q),:);end
  whiteReference=struct('schemaVersion',1,'documentType',"inkprof.paper-white-reference",'approved',true,'sourceKind',"locked-target-white", ...
   'measurementCondition',"M0",'instrument',string(c.instrument),'spectralScale',100,'wavelengthNm',v.wavelengthNm, ...
   'count',numel(whiteIndices),'meanSpectrum',mean(whiteData.spectra(whiteIndices,:),1),'samples',samples,'sourceTI3SHA256',whiteSourceHash);
 end
 if isempty(whiteIndices)&&~isempty(fieldnames(options.PaperWhiteReference))
  whiteReference=options.PaperWhiteReference;
  assert(isfield(whiteReference,'approved')&&whiteReference.approved&&string(whiteReference.instrument)==string(c.instrument),'inkprof:FWA','Invalid inherited paper-white reference.');
  assert(isequal(reshape(double(whiteReference.wavelengthNm),1,[]),v.wavelengthNm),'inkprof:FWA','Inherited white reference wavelengths differ.');
 elseif isempty(whiteIndices)
  referenceFile=options.PaperWhiteReferenceFile;
  if referenceFile==""&&options.ShowDialog
   whiteDialog=uifigure('Name','InkProf - FWA paper white','Visible','on');
   whiteCleanup=onCleanup(@()delete(whiteDialog));
   choice=uiconfirm(whiteDialog,'No measured white patches are available. FWA compensation needs measured blank paper of the same stock and backing. Measure several locations to average random variation.','FWA paper white','Options',{'Measure blank paper','Select saved blank-paper reference','Cancel'},'DefaultOption',1,'CancelOption',3);
   clear whiteCleanup;
   if choice=="Measure blank paper"
    referenceFile=inkprof.measurePaperWhite(inputFolder,MeasurementCondition=c);
   elseif choice=="Select saved blank-paper reference"
    [f,p]=uigetfile('*.json','Select approved blank-paper reference');if ~isequal(f,0),referenceFile=fullfile(p,f);end
   end
  end
  if referenceFile==""&&options.ShowDialog,return;end
  assert(referenceFile~="",'inkprof:FWAWhiteMissing','No measured paper white. Measure blank paper using inkprof.measurePaperWhite and pass PaperWhiteReferenceFile, or cancel FWA.');
  whiteReference=jsondecode(fileread(referenceFile));
  assert(string(whiteReference.documentType)=="inkprof.paper-white-reference"&&whiteReference.approved&&string(whiteReference.instrument)==string(c.instrument),'inkprof:FWA','Invalid blank-paper reference or instrument mismatch.');
  assert(isequal(reshape(double(whiteReference.wavelengthNm),1,[]),v.wavelengthNm),'inkprof:FWA','Blank-paper and target wavelengths differ.');
 end
end
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
if fwa
 colorimetry.fwaCompensation=true;colorimetry.fwaIlluminant="D50";
 colorimetry.fwaPreparation="white-reference-spec2cie-v1";
 if ~isempty(fieldnames(whiteReference)),colorimetry.paperWhiteReference=whiteReference;end
 colorimetry.inputPreparation="Native M0 spectra retained; Argyll spec2cie integrates and FWA-compensates once to simulated D50 XYZ before fitting, using averaged measured white; not measured M1";
 args=args(1:2); % spec2cie integrates and compensates once before colprof.
end
assert(isnan(settings.smoothing)||(isfinite(settings.smoothing)&&settings.smoothing>0), ...
 'inkprof:RecipeSmoothing','Smoothing must be positive, or NaN for the engine default.');
if options.A2BQuality=="high",args(1)="-qh";end
if ~isnan(settings.smoothing),args=[args,"-r",string(sprintf('%.17g',settings.smoothing))];end
if settings.b2aQuality=="high",args=[args,"-bh"];else,args=[args,"-bm"];end
args=[args,"-s",string(sprintf('%.17g',settings.perceptualCompression)),"-D",string(settings.description)];
if string(settings.printing.paperSurface)=="Matte",args=[args,"-Z","m"];end
shadow=inkprof.internal.shadowSettings(settings.printing);
if shadow.enabled,args=[args,"-V",string(sprintf('%.17g',shadow.gridEmphasis))];end
% Optional pre-regularization (experimental, off by default). Pass 1 builds an
% Argyll model with -r; its values at the original device RGB form a separate,
% derived build TI3 for pass 2. Raw measurements are never modified.
[pre,args,colorimetry]=preRegularizationPlan(settings,args,colorimetry,fwa,shadow);
% A pending dialog may outlive edits to the source. Check again before saving.
assert(inkprof.internal.sha256(inputFile)==inputHash,'inkprof:Integrity','B1 metadata changed while editing the recipe.');verifyInput(inputFolder,input);
recipe=struct('schemaVersion',1,'documentType',"inkprof.profile-recipe", ...
 'createdUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
 'name',settings.name,'description',settings.description,'inputFile',"../../profile-input.json", ...
 'inputSHA256',inputHash,'profilingTI3SHA256',input.profilingTI3SHA256, ...
 'patchCount',input.patchCount,'measurementCondition',input.measurementCondition, ...
 'printing',settings.printing,'printingBasis',"Project definition at recipe creation, or explicit standalone declarations; B1 is unchanged", ...
 'colorimetry',colorimetry,'engine',struct('name',"ArgyllCMS colprof", ...
 'shadow',shadow,'quality',options.A2BQuality,'smoothing',settings.smoothing,'b2aQuality',settings.b2aQuality,'algorithm',"Lab cLUT",'plannedArguments',args, ...
 'version',"record at build time",'iccVersion',"inspect generated file",'gamutMapping',struct('method',"generic-compression",'compressionPercent',settings.perceptualCompression,'requiredIntents',{{'relative','perceptual','absolute'}},'absoluteBasis',"relative colorimetric table plus media white")), ...
 'status',"recipe-saved-not-built");
if ~isempty(pre),recipe.engine.preRegularization=pre;end
recipe.gradientPreview=struct('enabled',~isempty(pre)&&settings.gradientPreview,'kind',"RGB ramps and optional blue-sky inverse check");
% Synchronize only after validating the saved choice. Workflow B2 synchronizes
% through its owning controller, which already holds the workflow lock.
if project~=""&&options.SyncProjectFWA
 current=jsondecode(fileread(fullfile(project,'inkprof-project.json')));
 previous=isfield(current.printing,'fwaCompensation')&&isequal(current.printing.fwaCompensation,true);
 if previous~=fwa
  if isfile(fullfile(project,'workflow.json'))
   workflow=inkprof.ProjectWorkflow(project);workflow.setFWA(fwa,"profiling-recipe");
  else
   inkprof.updateProject(project,Step="fwa-selection-at-recipe",Printing=struct('fwaCompensation',fwa));
  end
 end
end
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

function [pre,args,colorimetry]=preRegularizationPlan(settings,args,colorimetry,fwa,shadow)
%Methods are listed in inkprof.internal.preRegularizationMethods. Add new
%methods there, here and in profiles/preregularize.py.
pre=[];method="off";
if isfield(settings,'preRegularization'),method=string(settings.preRegularization);end
switch method
 case "off"
  return
 case "argyll-colprof"
  avg=settings.preRegularizationAvgDev;
  assert(isscalar(avg)&&isfinite(avg)&&avg>0&&avg<=100,'inkprof:RecipePreRegularization', ...
   'Pre-regularization avgdev (colprof -r) must be a percentage > 0 and <= 100.');
  colourArgs=strings(1,0);if settings.dataMode=="spectral"&&~fwa,colourArgs=["-i","D50","-o","1931_2"];end
  shadowArgs=strings(1,0);if shadow.enabled,shadowArgs=["-V",string(sprintf('%.17g',shadow.gridEmphasis))];end
  preArgs=[args(1),"-al",colourArgs,"-r",string(sprintf('%.17g',avg)),shadowArgs,"-bl","-nc","-D","InkProf pre-regularization model"];
  % Pass 2 reads derived XYZ; spectral integration happens in pass 1 only.
  args=[args(1:2),args(3+numel(colourArgs):end)];
  pre=struct('enabled',true,'method',"argyll-colprof-a2b-resample",'avgdev',avg,'plannedArguments',preArgs, ...
   'evaluation',"profcheck -v2 -k -I a at the original device RGB (absolute colorimetric)", ...
   'derivedData',"Model XYZ (D50 PCS) replaces measured colour in a separate build TI3; raw measurements unchanged", ...
   'note',"Experimental. Argyll -r is the assumed average device+instrument deviation in percent. The final build applies its own -r again.");
  colorimetry.inputPreparation=string(colorimetry.inputPreparation)+"; pre-regularization: pass 1 uses this colourimetry, pass 2 profiles derived model XYZ";
 otherwise
  error('inkprof:RecipePreRegularization','Unknown pre-regularization method: %s. InkProf grid regularization (axial/Hessian) has been removed.',method);
end
end

function v=projectValue(printing,key,fallback)
v=fallback;if isfield(printing,key)&&strlength(strtrim(string(printing.(key))))>0,v=string(printing.(key));end
end
