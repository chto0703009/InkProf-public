function manifest=createTarget(outputFolder, options)
%CREATETARGET Create a verified RGB TIFF16 + TI1/TI2 print package.
%   inkprof.createTarget("projects/test", PatchCount=100, ArgyllBin="/usr/local/bin")
%   inkprof.createTarget("projects/import", Source="chart.txf", Randomize=true, Seed=42)
% Existing output folders are never overwritten. Imported TXF gets a NEW layout.
arguments
    outputFolder (1,1) string
    options.PlanPaper (1,1) logical = false
    options.PaperLayout (1,1) struct = struct
    options.Continue (1,1) function_handle = @()true
    options.TargetInfo (1,1) struct = struct
    options.Source (1,1) string = ""
    options.RGBScale (1,1) double = NaN
    options.PatchCount (1,1) double {mustBeInteger,mustBePositive} = 100
    options.GraySteps (1,1) double {mustBeInteger,mustBeNonnegative} = 9
    options.WhitePatches (1,1) double {mustBeInteger,mustBeNonnegative} = 4
    options.BlackPatches (1,1) double {mustBeInteger,mustBeNonnegative} = 4
    options.ArgyllBin (1,1) string = ""
    options.Paper (1,1) string = ""
    options.PaperSizeMm (1,:) double {mustBePositive,mustBeFinite} = []
    options.MarginMm (1,1) double {mustBeNonnegative,mustBeFinite} = 10
    options.DPI (1,1) double {mustBeInteger,mustBePositive} = 300
    options.PatchScale (1,1) double {mustBePositive,mustBeFinite} = 1
    options.SpacerMode (1,1) string {mustBeMember(options.SpacerMode,["auto","colored","bw","none"])} = "auto"
    options.SpacerScale (1,1) double {mustBePositive,mustBeFinite} = 1
    options.CompactA4 (1,1) logical = false
    options.Randomize (1,1) logical = false
    options.Seed (1,1) double {mustBeInteger,mustBeNonnegative} = 1
    options.TimeoutSeconds (1,1) double {mustBePositive,mustBeFinite} = 120
end
if options.Paper~=""
    assert(isempty(options.PaperSizeMm),'inkprof:Paper','Use Paper OR PaperSizeMm, not both.');
    switch lower(options.Paper)
        case "a4-landscape",options.PaperSizeMm=[297 210];options.Paper="A4-landscape";
        case "a3-portrait",options.PaperSizeMm=[297 420];options.Paper="A3-portrait";
        case "a4-portrait",options.PaperSizeMm=[210 297];options.Paper="A4-portrait";
        otherwise,error('inkprof:Paper','Choose A4-landscape, A3-portrait or A4-portrait.');
    end
elseif isempty(options.PaperSizeMm)
    options.Paper="A4-portrait";options.PaperSizeMm=[210 297];
else
    options.Paper="custom";
end
if options.CompactA4
    assert(options.Paper=="A4-landscape" || (options.Paper=="A4-portrait" && isequal(options.PaperSizeMm,[210 297])), ...
        'inkprof:Paper','CompactA4 requires A4 paper; omit Paper or use Paper="A4-landscape".');
    options.Paper="A4-landscape";
    options.PaperSizeMm=[297 210];
    options.MarginMm=0;
    options.PatchScale=0.82;
    options.SpacerScale=1;
end
assert(numel(options.PaperSizeMm)==2,'inkprof:Paper','PaperSizeMm must contain [width height].');
assert(options.Seed<=2147483647,'inkprof:Seed','Seed must fit signed 32-bit integer.');
assert(options.DPI>=72 && options.DPI<=1200,'inkprof:DPI','Supported resolution: 72–1200 dpi.');
prefs=inkprof.internal.paperPreferences(inkprof.internal.findProject(outputFolder));
if ~isempty(fieldnames(options.PaperLayout)),prefs=options.PaperLayout.preferences;end
targetLimitMm=[prefs.MaxScanMm prefs.MaxLengthMm];
assert(all(min(options.PaperSizeMm,targetLimitMm)>2*options.MarginMm+40),'inkprof:Paper','Insufficient printable area.');
outputFolder=inkprof.internal.absolutePath(outputFolder);
assert(~isfolder(outputFolder)&&~isfile(outputFolder),'inkprof:Exists','Output already exists: %s',outputFolder);
if options.Source~=""
    target=inkprof.importTarget(options.Source,RGBScale=options.RGBScale);
end
if options.PlanPaper
    count=options.PatchCount;if options.Source~="",count=numel(target.ids);end
    choice=inkprof.internal.paperLayoutDialog(count,inkprof.internal.findProject(outputFolder),options.Source,options.RGBScale);
    assert(~isempty(choice),'inkprof:Cancelled','Paper selection cancelled.');
    options.PaperLayout=choice;options.PaperSizeMm=choice.paperSizeMm;
    targetLimitMm=[choice.preferences.MaxScanMm choice.preferences.MaxLengthMm];
end
assert(all(options.PaperSizeMm<=targetLimitMm),'inkprof:Paper','Target exceeds the measurement limits in project Target paper settings.');
calculation=inkprof.internal.calculationProgress("Creating TIFF16 target","Arranging patches and writing TIFF16 print files. Large targets may take several minutes."); %#ok<NASGU>
checkpoint(options.Continue);
bin=inkprof.internal.argyllBin(options.ArgyllBin);
parent=string(fileparts(outputFolder));if ~isfolder(parent),mkdir(parent);end
stage=string(tempname(parent));mkdir(stage);
cleanup=onCleanup(@()removeStage(stage));
suffix="";if ispc,suffix=".exe";end
targen=fullfile(bin,"targen"+suffix);printtarg=fullfile(bin,"printtarg"+suffix);
logs=struct('executable',{},'arguments',{},'exitCode',{},'output',{});
versions=struct;
for tool=["targen","printtarg"]
    help=inkprof.internal.runTool(fullfile(bin,tool+suffix),"-?",stage,options.TimeoutSeconds,true);
    version=regexp(char(help.output),'Version\s+([0-9]+\.[0-9]+(?:\.[0-9]+)?)','tokens','once');
    assert(~isempty(version),'inkprof:Version','Cannot identify %s version.',tool);
    versions.(tool)=string(version{1});logs(end+1)=help;
end
sourceFolder=fullfile(stage,'source');mkdir(sourceFolder);
if options.Source==""
    assert(options.GraySteps~=1,'inkprof:Generation','GraySteps must be zero or at least two.');
    assert(options.PatchCount>=options.WhitePatches+options.BlackPatches+options.GraySteps, ...
        'inkprof:Generation','PatchCount is too small for the requested ramps/repeats.');
    args=["-d2","-e"+options.WhitePatches,"-B"+options.BlackPatches, ...
        "-g"+options.GraySteps,"-f"+options.PatchCount,"source/generated"];
    logs(end+1)=inkprof.internal.runTool(targen,args,stage,options.TimeoutSeconds);
    sourceFile=fullfile(sourceFolder,'generated.ti1');
    target=inkprof.importTarget(sourceFile);
    template=sourceFile;
else
    [~,~,ext]=fileparts(target.sourcePath);
    sourceFile=fullfile(sourceFolder,"original"+ext);
    copyfile(target.sourcePath,sourceFile);
    assert(inkprof.internal.sha256(sourceFile)==target.sourceSHA256,'inkprof:Integrity','Input changed while importing.');
    % Preserve the verified design sidecar with the archived definition.
    if isfield(target.targetInfo,'upstream')
        [sourceParent,sourceStem]=fileparts(target.sourcePath);
        sidecar=fullfile(sourceParent,sourceStem+".json");
        copyfile(sidecar,fullfile(sourceFolder,'original.json'));
        archived=inkprof.importTarget(sourceFile,RGBScale=target.rgbScale);
        assert(isequaln(archived.targetInfo.upstream,target.targetInfo.upstream),'inkprof:Integrity','Design metadata changed while importing.');
    end
    % Let the installed Argyll produce its own version-specific helper tables.
    logs(end+1)=inkprof.internal.runTool(targen,["-d2","-e1","-B1","-f8","helper"],stage,options.TimeoutSeconds);
    template=fullfile(stage,'helper.ti1');
end
if options.Source==""
    generation=struct('method',"argyll",'settings',struct('PatchCount',options.PatchCount, ...
        'GraySteps',options.GraySteps,'WhitePatches',options.WhitePatches,'BlackPatches',options.BlackPatches), ...
        'version',versions.targen,'arguments',logs(end).arguments);
    target.targetInfo=inkprof.internal.targetInfo(target.rgbPercent/100,fullfile(outputFolder,'source','generated.ti1'),generation);
    target.targetInfo.source.sha256=target.sourceSHA256;
end
if ~isempty(fieldnames(options.TargetInfo))
    assert(options.TargetInfo.patchCount==numel(target.ids),'inkprof:Metadata','Target metadata count mismatch.');
    target.targetInfo=options.TargetInfo;
end
originalPath=target.sourcePath;
[~,sourceName,ext]=fileparts(sourceFile);
target.sourcePath="source/"+sourceName+ext;
target.layoutStatus="new Argyll layout; original layout retained only as source metadata";
if isempty(target.estimatedXYZ)
    target.xyzStatus="sRGB D65 estimate for layout only; device RGB unchanged; not measured";
end
target.estimatedXYZ=inkprof.internal.writeTi1(fullfile(stage,'target.ti1'),target,template);
if isfile(fullfile(stage,'helper.ti1')),delete(fullfile(stage,'helper.ti1'));end
[~,packageName]=fileparts(outputFolder);
target.printSettings=struct('packageName',string(packageName),'outputFolder',outputFolder, ...
    'inputFile',originalPath,'dpi',options.DPI,'paperSizeMm',options.PaperSizeMm, ...
    'footerCenterInsetMm',12,'footerReservedMm',22, ...
    'maximumWidthMm',targetLimitMm(1),'maximumLengthMm',targetLimitMm(2),'lengthPolicy',"project JSON limits",'marginMm',options.MarginMm, ...
    'spacerMode',options.SpacerMode,'randomize',options.Randomize,'seed',options.Seed, ...
    'tiffBitsPerChannel',16,'embeddedICCProfile',false);
if ~isempty(fieldnames(options.PaperLayout))
    options.PaperLayout.sourcePatchCount=numel(target.ids);
    options.PaperLayout.paperSizeMm=options.PaperSizeMm;
    if isfield(options.PaperLayout,'proposal'),options.PaperLayout.edited=~isequal(options.PaperSizeMm,options.PaperLayout.proposal.sizeMm);end
    inkprof.internal.writeJson(fullfile(stage,'paper-layout.json'),options.PaperLayout);
end
inkprof.internal.writeJson(fullfile(stage,'target.json'),target);
% The target canvas includes margins and is capped independently of paper.
% Floor to whole pixels within the measurement limits recorded in JSON.
renderPaper=min(options.PaperSizeMm,floor(targetLimitMm*options.DPI/25.4)*25.4/options.DPI-1e-7);
% Reduce native row capacity by the extra footer reservation (22 vs 12 mm).
% Final TIFF retains the requested paper size; patch pixels are not scaled.
nativePaper=fliplr(renderPaper);nativePaper(1)=nativePaper(1)-10;
paper=compose('%.12gx%.12g',nativePaper(1),nativePaper(2));
mkdir(fullfile(stage,'argyll'));
copyfile(fullfile(stage,'target.ti1'),fullfile(stage,'argyll','target.ti1'));
args=["-ii1","-x0-9,@-9,@-9;1-999","-yA-Z, A-Z","-T"+options.DPI,"-Q16","-S","-p"+paper, ...
    "-M"+options.MarginMm,"-a"+options.PatchScale,"-A"+options.SpacerScale];
if options.SpacerMode=="colored",args=[args,"-c"];elseif options.SpacerMode=="bw",args=[args,"-b"];elseif options.SpacerMode=="none",args=[args,"-n"];end
if options.CompactA4,args=[args,"-P"];end
if options.Randomize,args=[args,"-R"+options.Seed];else,args=[args,"-r"];end
args=[args,"argyll/target"];
logs(end+1)=inkprof.internal.runTool(printtarg,args,stage,options.TimeoutSeconds);
checkpoint(options.Continue);
inkprof.internal.horizontalPages(stage,renderPaper,outputFolder,target.targetInfo);
checkpoint(options.Continue);
layout=inkprof.internal.readLayout(stage);
for k=1:numel(layout)
    layout(k).originalId="";layout(k).originalName="";
    if ~layout(k).isPadding
        id=str2double(layout(k).sampleId);
        assert(isfinite(id)&&id==fix(id)&&id>=1&&id<=numel(target.ids),'inkprof:Identity','Invalid Argyll patch ID.');
        layout(k).originalId=target.ids(id);layout(k).originalName=target.names(id);
    end
    layout(k).rgb16=round(layout(k).rgbPercent/100*65535);
end
inkprof.internal.writeJson(fullfile(stage,'layout.json'),struct('schemaVersion',1, ...
    'documentType',"inkprof.layout",'coordinateSystem',"mm from upper left; rect=[x y width height]", ...
    'targetInfo',target.targetInfo,'instrument',"Argyll i1 (i1Pro family)",'readingDirection',"left to right; numbered rows top to bottom; lettered columns left to right",'patches',layout));
report=inkprof.verifyPackage(stage);
target.printSettings.pageCount=numel(report.pages);
if ~isempty(fieldnames(options.PaperLayout))
    options.PaperLayout.actualPages=numel(report.pages);
    options.PaperLayout.sourcePatchCount=numel(target.ids);
    options.PaperLayout.paperSizeMm=options.PaperSizeMm;
    if isfield(options.PaperLayout,'proposal'),options.PaperLayout.edited=~isequal(options.PaperSizeMm,options.PaperLayout.proposal.sizeMm);end
    inkprof.internal.writeJson(fullfile(stage,'paper-layout.json'),options.PaperLayout);
end
inkprof.internal.writeJson(fullfile(stage,'target.json'),target);
inkprof.internal.writeJson(fullfile(stage,'verification.json'),report);
% Lightweight RGB preview per page; print only target*.tif, never preview PNGs.
for page=reshape(string({report.pages.file}),1,[])
    image=imread(fullfile(stage,page));step=max(1,ceil(max(size(image,1),size(image,2))/1000));
    [~,name]=fileparts(page);imwrite(uint8(double(image(1:step:end,1:step:end,:))/257),fullfile(stage,name+"-preview.png"));
end
fid=fopen(fullfile(stage,'PRINTING.txt'),'w');assert(fid>=0,'inkprof:IO','Cannot write print instructions.');
fprintf(fid,['Print target*.tif at 100%% physical size, without fit-to-page or automatic colour conversion.\n' ...
    'Requested print paper: %.3f x %.3f mm. Resolution: %d dpi. Device RGB, 16 bits/channel.\n' ...
    'Record printer, paper, driver/RIP, media mode and quality settings before printing.\n' ...
    'Rows 1, 2, 3 run from top to bottom; columns A, B, C from left to right. Scan each row from left to right. Target canvas including margins: limits are recorded in target.json and manifest.json. Keep physical size; do not fit to paper.\n' ...
    'Only root target*.tif are for printing; argyll/ contains native intermediate files.\n' ...
    'Use the matching target.ti2 for later Argyll chartread measurement (i1 instrument layout).\n' ...
    'This is a NEW layout; do not measure it with the original TXF.\n' ...
    'Receiver layout compatibility and physical strip measurement are NOT yet verified.\n' ...
    'Preview PNG files are for screen inspection only. Source definitions are archived in source/.\n'], ...
    options.PaperSizeMm,options.DPI);fclose(fid);
savedOptions=rmfield(options,{'TargetInfo','Continue'});savedOptions.RGBScale=target.rgbScale;savedOptions.ArgyllBin=bin;
savedOptions.Source=target.sourcePath;
manifest=struct('schemaVersion',1,'documentType',"inkprof.print-package",'inkprofVersion',"0.1.4", ...
    'createdUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
    'matlabVersion',string(versionMATLAB()),'options',savedOptions,'argyllVersions',versions, ...
    'printSettings',target.printSettings,'targetInfo',target.targetInfo,'originalSourcePath',originalPath,'sourcePatches',numel(target.ids), ...
    'pageCount',numel(report.pages),'renderPaperSizeMm',renderPaper,'maxTotalWidthMm',targetLimitMm(1),'maxTargetSizeMm',targetLimitMm, ...
    'layoutPolicy',"horizontal rows; native Argyll grid transposed without resampling",'rowDirection',"left-to-right",'nativePaperSizeMm',nativePaper,'randomization',struct('enabled',options.Randomize,'seed',options.Seed, ...
    'algorithm',"Argyll printtarg; actual mapping in target.ti2 and layout.json"), ...
    'compatibility',struct('argyllFilesGenerated',true,'pixelChecksPassed',true, ...
    'physicalMeasurementVerified',false,'receiverLayoutVerified',false),'toolRuns',logs,'files',[]);
listing=dir(fullfile(stage,'**','*'));listing=listing(~[listing.isdir]);
files=struct('name',{},'sha256',{},'bytes',{});
for k=1:numel(listing)
    file=fullfile(listing(k).folder,listing(k).name);
    relative=replace(extractAfter(string(file),strlength(stage)+1),"\","/");
    files(end+1)=struct('name',relative,'sha256',inkprof.internal.sha256(file),'bytes',listing(k).bytes); %#ok<AGROW>
end
manifest.files=files;inkprof.internal.writeJson(fullfile(stage,'manifest.json'),manifest);
inkprof.verifyPackage(stage); % Include manifest hashes and declared page dimensions.
assert(~isfolder(outputFolder)&&~isfile(outputFolder),'inkprof:Exists','Output appeared while generating.');
checkpoint(options.Continue);
[ok,message]=movefile(stage,outputFolder);assert(ok,'inkprof:IO','Cannot publish package: %s',message);
clear cleanup
if ~isempty(fieldnames(options.PaperLayout))
    project=inkprof.internal.findProject(outputFolder);
    if project~="",inkprof.updateProject(project,Step="paper-layout-selected",PaperLayout=options.PaperLayout.preferences);end
end
inkprof.internal.recordProjectStep(outputFolder,"print-package-saved");
end
function removeStage(path)
if isfolder(path),rmdir(path,'s');end
end
function v=versionMATLAB()
v=version;
end

function checkpoint(callback)
assert(callback(),'inkprof:Cancelled','Generation cancelled. No output package saved.');
end
