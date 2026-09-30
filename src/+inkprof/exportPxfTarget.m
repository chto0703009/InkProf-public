function report=exportPxfTarget(sourcePath,outputPath,options)
%EXPORTPXFTARGET Export RGB TI1/TI2 definitions as a Prism/CxF3 PXF patch set.
% Preserves patch order; RGB8 compatibility by default. No print layout implied.
arguments
 sourcePath (1,1) string
 outputPath (1,1) string
 options.Name (1,1) string = ""
 options.Template (1,1) string = ""
 options.RGBEncoding (1,1) string {mustBeMember(options.RGBEncoding,["rgb8","float","round8"])} = "rgb8"
end
sourcePath=inkprof.internal.absolutePath(sourcePath);outputPath=inkprof.internal.absolutePath(outputPath);
[~,~,ext]=fileparts(sourcePath);assert(any(lower(ext)==[".ti1",".ti2"]),'inkprof:Input','PXF export requires RGB TI1 or TI2.');
[parent,stem,ext]=fileparts(outputPath);assert(lower(ext)==".pxf",'inkprof:Input','Choose a .pxf output filename.');
assert(isfolder(parent),'inkprof:Input','Output directory does not exist.');
jsonPath=fullfile(parent,stem+".json");
for path=[outputPath,jsonPath],assert(~isfile(path)&&~isfolder(path),'inkprof:Exists','Output already exists: %s',path);end
target=inkprof.importTarget(sourcePath);n=numel(target.ids);
templatePath=options.Template;
if templatePath=="",paths=inkprof.paths();templatePath=fullfile(paths.Root,'resources','templates','rgb-patch-set.pxf');end
raw=string(fileread(templatePath));
assert(isempty(regexpi(raw,'<!DOCTYPE|<!ENTITY','once')),'inkprof:XML','DTD/entities are not accepted.');
assert(contains(raw,'xmlns:cc="http://colorexchangeformat.com/CxF3-core"')&&contains(raw,'<xrp:CustomAttributes '),'inkprof:XML','Expected the observed cc/xrp Prism PXF template.');
assert(isempty(regexp(raw,'ObjectType="(?!Target)[^"]+"','once')),'inkprof:XML','Template must not contain measurement objects.');
assert(~contains(raw,'ColorCMYK'),'inkprof:ColorFormat','RGB template required.');
date=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));date=replace(date,'Z','+00:00');
rgb=target.rgbPercent*2.55;sourceRGB=rgb;
if options.RGBEncoding~="float"
    difference=max(abs(rgb-round(rgb)),[],'all');
    assert(options.RGBEncoding=="round8"||difference<=2e-5,'inkprof:PXFPrecision', ...
        'RGB values are not on the 8-bit grid. RGBEncoding="round8" explicitly permits quantization; "float" is experimental and may be rejected by the receiver.');
    rgb=round(rgb);
end
objects=strings(n,1);
map=repmat(struct('pxfId',"",'sourceId',"",'sourceName',"",'sourceLocation',"",'rgbPercent',zeros(1,3)),n,1);
for k=1:n
 id="c"+k;name="Target"+k;
 objects(k)=sprintf(['\t\t\t<cc:Object ObjectType="Target" Name="%s" Id="%s">\n' ...
  '\t\t\t\t<cc:CreationDate>%s</cc:CreationDate>\n' ...
  '\t\t\t\t<cc:DeviceColorValues>\n' ...
  '\t\t\t\t\t<cc:ColorRGB ColorSpecification="Unknown">\n' ...
  '\t\t\t\t\t\t<cc:R>%.17g</cc:R>\n' ...
  '\t\t\t\t\t\t<cc:G>%.17g</cc:G>\n' ...
  '\t\t\t\t\t\t<cc:B>%.17g</cc:B>\n' ...
  '\t\t\t\t\t</cc:ColorRGB>\n' ...
  '\t\t\t\t</cc:DeviceColorValues>\n\t\t\t</cc:Object>'],name,id,date,rgb(k,1),rgb(k,2),rgb(k,3));
 loc="";
 if target.sourceFormat==".ti2"
  patches=target.sourceLayout.patches;match=find(string({patches.sampleId})==target.ids(k)&~[patches.isPadding]);
  assert(isscalar(match),'inkprof:Identity','Ambiguous source patch.');loc=string(patches(match).sampleLoc);
 end
 map(k)=struct('pxfId',id,'sourceId',target.ids(k),'sourceName',target.names(k),'sourceLocation',loc,'rgbPercent',target.rgbPercent(k,:));
end
raw=block(raw,'<cc:ObjectCollection>.*?</cc:ObjectCollection>',"<cc:ObjectCollection>"+newline+join(objects,newline)+newline+"</cc:ObjectCollection>");
raw=regexprep(raw,'<cc:Creator>[^<]*</cc:Creator>','<cc:Creator>InkProf</cc:Creator>');
raw=regexprep(raw,'<cc:CreationDate>[^<]*</cc:CreationDate>','<cc:CreationDate>'+date+'</cc:CreationDate>');
% Preserve the observed private Prism structure as compatibility defaults.
% These defaults are not a reproduction of TI2 physical print layout.
attrs=string(regexp(char(raw),'<xrp:CustomAttributes\s[^>]*?/?>','match','once'));
name=options.Name;if name=="",name=stem;end
for key=["numberCorePatches","numberImagePatches","numberSpotPatches","TitleString","WriteProtected","ScramblePatches"]
 value="0";if key=="numberCorePatches",value=string(n);elseif key=="TitleString",value=escape(name);elseif key=="WriteProtected",value="True";elseif key=="ScramblePatches",value="False";end
 pattern=key+'="[^"]*"';
 if isempty(regexp(attrs,pattern,'once')),attrs=replace(attrs,'/>',' '+key+'="'+value+'"/>');
 else,attrs=block(attrs,pattern,key+'="'+value+'"');end
end
raw=block(raw,'<xrp:CustomAttributes\s[^>]*?/?>',attrs);
if options.Name~=""
 raw=block(raw,'<cc:Description>.*?</cc:Description>',"<cc:Description>"+escape(options.Name)+"</cc:Description>");
end
stage=string(tempname(parent));mkdir(stage);clean=onCleanup(@()rmdir(stage,'s'));pxf=fullfile(stage,'target.pxf');
f=fopen(pxf,'w','n','UTF-8');assert(f>=0,'inkprof:IO','Cannot create PXF.');closer=onCleanup(@()fclose(f));fprintf(f,'%s',raw);clear closer
back=inkprof.importTarget(pxf);
assert(isequal(back.ids,string({map.pxfId})')&&isequal(back.names,"Target"+string((1:n)')),'inkprof:Identity','PXF identity/order readback failed.');
error=max(abs(back.rgbOriginal-rgb),[],'all');assert(error<1e-10,'inkprof:Precision','PXF RGB readback changed.');
excluded=0;if target.sourceFormat==".ti2",excluded=sum([target.sourceLayout.patches.isPadding]);end
report=struct('schemaVersion',1,'documentType','inkprof.pxf-export','sourcePath',sourcePath,'sourceSHA256',target.sourceSHA256, ...
 'pxfFile',outputPath,'pxfSHA256',inkprof.internal.sha256(pxf),'templateSHA256',inkprof.internal.sha256(templatePath), ...
 'patchCount',n,'excludedPaddingCount',excluded,'rgbScale',255,'rgbQuantization',options.RGBEncoding,'exportedRGB255',rgb,'maxRGB255Change',max(abs(rgb-sourceRGB),[],'all'), ...
 'maxRGBPercentRoundtripError',error/2.55,'mapping',map,'targetInfo',target.targetInfo, ...
 'layoutStatus','Patch definitions only. TI2 physical coordinates retained in JSON; PXF does not recreate the print.', ...
 'templateDefaults','Private Prism fields retained for compatibility; not verified source print/profile settings','receiverImportVerified',false);
inkprof.internal.writeJson(fullfile(stage,'target.json'),report);
published=strings(0,1);
try
 sources=[pxf,fullfile(stage,'target.json')];destinations=[outputPath,jsonPath];
 for k=1:2
  assert(~isfile(destinations(k)),'inkprof:Exists','Output appeared during export.');
  [ok,msg]=copyfile(sources(k),destinations(k));assert(ok,'inkprof:IO','%s',msg);published(end+1)=destinations(k); %#ok<AGROW>
 end
catch err
 for path=published,if isfile(path),delete(path);end,end
 rethrow(err);
end
inkprof.internal.recordProjectStep(parent,'Exported RGB patch definitions to PXF');
end
function out=escape(value)
out=replace(string(value),'&','&amp;');out=replace(out,'<','&lt;');out=replace(out,'>','&gt;');out=replace(out,'"','&quot;');out=replace(out,"'",'&apos;');
end
function raw=block(raw,pattern,replacement)
[a,b]=regexp(char(raw),pattern,'start','end','once');assert(~isempty(a),'inkprof:XML','Template block is missing.');
v=char(raw);raw=string(v(1:a-1))+replacement+string(v(b+1:end));
end
