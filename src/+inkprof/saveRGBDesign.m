function saved=saveRGBDesign(design,ti2Path,options)
%SAVERGBDESIGN Create TIFF/TI2 layout plus design JSON via an explicit path.
arguments
    design (1,1) struct
    ti2Path (1,1) string
    options.Continue (1,1) function_handle = @()true
    options.DPI (1,1) double {mustBeInteger,mustBePositive} = 300
    options.Randomize (1,1) logical = true
    options.Seed (1,1) double {mustBeInteger,mustBeNonnegative} = 42
    options.ArgyllBin (1,1) string = ""
end
assert(isfield(design,'documentType')&&string(design.documentType)=="inkprof.rgb-design",'inkprof:Design','Expected RGB target design.');
inkprof.internal.requireRgb(design.rgb,1);
n=size(design.rgb,1);
quantized=round(design.rgb*65535);
fit=quantized(string(design.roles)=="fit",:);
assert(size(unique(fit,'rows'),1)==size(fit,1),'inkprof:Design', ...
    'Distinct fitting points collapse to one TIFF16 colour. Reduce refinement.');
assert(isempty(intersect(quantized(string(design.roles)=="fit",:),quantized(string(design.roles)=="control",:),'rows')), ...
    'inkprof:Design','A control colour equals a fitting colour at TIFF16 precision. Choose a different design.');
assert(numel(design.sampleId)==n&&numel(unique(string(design.sampleId)))==n&&numel(design.roles)==n, ...
    'inkprof:Design','Invalid design identities or roles.');
ti2Path=inkprof.internal.absolutePath(ti2Path);[parent,stem,ext]=fileparts(ti2Path);
assert(lower(ext)==".ti2",'inkprof:Design','Choose a .ti2 filename.');
assert(isfolder(parent),'inkprof:Input','Output directory must exist.');
jsonPath=fullfile(parent,stem+".json");ti1Path=fullfile(parent,stem+".ti1");folder=fullfile(parent,stem+"-files");
for p=[ti2Path,jsonPath,ti1Path,folder]
    assert(~isfile(p)&&~isfolder(p),'inkprof:Exists','Output already exists: %s',p);
end
w=string(tempname(parent));mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
table=struct('signature',"CTI1",'metadata',{{["DESCRIPTOR",design.name];["ORIGINATOR","InkProf"];["COLOR_REP","iRGB"]}}, ...
    'fields',["SAMPLE_ID","RGB_R","RGB_G","RGB_B"], ...
    'data',[string(design.sampleId(:)),compose('%.17g',design.rgb*100)]);
inkprof.exportCgats(fullfile(w,'definition.ti1'),struct('documentType',"inkprof.cgats",'tables',table));
if isfield(design,'targetInfo')
    info=design.targetInfo;
else
    generation=struct('method',design.options.Method,'name',design.name,'settings',design.options, ...
        'history',design.history,'stopReason',design.stopReason);
    if string(design.options.Method)=="mesh"
        generation.initialLevels=design.options.Levels;generation.iterations=size(design.history,1);
        generation.initialRGB=design.initialRGB;generation.parentEdges=design.parentEdges;generation.gap=design.gap;
    end
    info=inkprof.internal.targetInfo(design.rgb,"",generation,(1:design.fitCount)');
end
info.source=struct('fileName',stem+".ti1",'path',ti1Path,'format',".ti1", ...
    'sha256',inkprof.internal.sha256(fullfile(w,'definition.ti1')),'declaredMetadata',struct);
info.footerText=inkprof.internal.targetInfoText(info);
created=false;published=strings(0,1);
try
    % Point selection is already done; Argyll is used only for print layout.
    manifest=inkprof.createTarget(folder,Source=fullfile(w,'definition.ti1'),Paper="A4-landscape", ...
        Continue=options.Continue,SpacerMode="colored",DPI=options.DPI,Randomize=options.Randomize,Seed=options.Seed,ArgyllBin=options.ArgyllBin,TargetInfo=info);
    created=true;
    layout=jsondecode(fileread(fullfile(folder,'layout.json')));
    record=design;record.targetInfo=info;
    record.print=struct('pageCount',manifest.pageCount,'package',stem+"-files",'ti2',stem+".ti2",'ti1',stem+".ti1", ...
        'ti2SHA256',inkprof.internal.sha256(fullfile(folder,'target.ti2')), ...
        'ti1SHA256',inkprof.internal.sha256(fullfile(w,'definition.ti1')), ...
        'layout',layout,'DPI',options.DPI,'randomize',options.Randomize,'seed',options.Seed, ...
        'sourceIndexRule',"Nonzero layout sampleId indexes design.sampleId/rgb/roles; zero is padding", ...
        'quantization',"Ideal RGB remains in design.rgb; print.layout contains actual TIFF16/RGB values after quantization", ...
        'roleWarning',"All roles are measured. Exclude controls and handle repetitions explicitly when fitting a profile.");
    inkprof.internal.writeJson(fullfile(w,'design.json'),record);
    sources=[fullfile(folder,'target.ti2'),fullfile(w,'definition.ti1'),fullfile(w,'design.json')];
    dests=[ti2Path,ti1Path,jsonPath];
    for k=1:numel(dests)
        assert(~isfile(dests(k))&&~isfolder(dests(k)),'inkprof:Exists','Output appeared during export.');
        [ok,msg]=copyfile(sources(k),dests(k));assert(ok,'inkprof:IO','%s',msg);published(end+1)=dests(k); %#ok<AGROW>
    end
catch err
    for p=published,if isfile(p),delete(p);end,end
    if created&&isfolder(folder),rmdir(folder,'s');end
    rethrow(err);
end
inkprof.internal.recordProjectStep(fileparts(ti2Path),"design-and-print-saved");
saved=struct('ti2',ti2Path,'ti1',ti1Path,'json',jsonPath,'folder',folder,'patchCount',n);
end
