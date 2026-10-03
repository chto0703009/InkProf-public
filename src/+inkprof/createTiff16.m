% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function info=createTiff16(sourcePath, referencePath, outputPath, options)
%CREATETIFF16 Render any RGB target with the InkProf 29 x 20 page template.
arguments
    sourcePath (1,1) string
    referencePath (1,1) string
    outputPath (1,1) string = ""
    options.Randomize (1,1) logical = false
    options.Seed (1,1) double {mustBeInteger,mustBeNonnegative} = 42
    options.DPI (1,1) double {mustBeInteger,mustBePositive} = 300
    options.RGBScale (1,1) double = NaN
    options.TxfTemplate (1,1) string = ""
    options.WriteTxfCandidate (1,1) logical = true
    options.Time (1,1) string = string(datetime('now','Format','HH:mm'))
    options.Date (1,1) string = string(datetime('today','Format','yyyy-MM-dd'))
end
if outputPath=="",outputPath=referencePath;referencePath="";end
assert(options.Seed<=2147483647,'inkprof:Seed','Seed must fit signed 32-bit integer.');
outputPath=inkprof.internal.absolutePath(outputPath);
[parent,stem,ext]=fileparts(outputPath);
assert(any(lower(ext)==[".tif",".tiff"]),'inkprof:Input','Output must have a .tif or .tiff extension.');
assert(options.DPI>=72&&options.DPI<=1200,'inkprof:DPI','Supported resolution: 72–1200 dpi.');
assert(~isfile(outputPath)&&~isfolder(outputPath),'inkprof:Exists','Output already exists: %s',outputPath);
if ~isfolder(parent),mkdir(parent);end
stage=string(tempname(parent));mkdir(stage);stageCleanup=onCleanup(@()removeStage(stage));
info=buildBundle(sourcePath,referencePath,fullfile(stage,stem+ext),options,outputPath);
entries=dir(stage);entries=entries(~[entries.isdir]);
for k=1:numel(entries)
    destination=fullfile(parent,entries(k).name);
    assert(~isfile(destination)&&~isfolder(destination),'inkprof:Exists','Output already exists: %s',destination);
end
% Publish only after all rendering, checks and optional TXF creation succeed.
% Roll back files published by this call if a move fails.
published=strings(0,1);
try
    for k=1:numel(entries)
        destination=fullfile(parent,entries(k).name);
        assert(~isfile(destination)&&~isfolder(destination),'inkprof:Exists','Output appeared during export.');
        [ok,msg]=movefile(fullfile(stage,entries(k).name),destination);
        assert(ok,'inkprof:IO','%s',msg);published(end+1)=destination; %#ok<AGROW>
    end
catch error
    for k=1:numel(published),delete(published(k));end
    rethrow(error);
end
for key=["file","ti2","layout","verification","manifest","patchCgats","physicalLayoutCgats"]
    [~,name,extension]=fileparts(info.(key));info.(key)=fullfile(parent,name+extension);
end
for k=1:numel(info.tiffs)
    [~,name,extension]=fileparts(info.tiffs(k));info.tiffs(k)=fullfile(parent,name+extension);
end
clear stageCleanup
inkprof.internal.recordProjectStep(parent,"legacy-print-package-saved");
end

function info=buildBundle(sourcePath,referencePath,outputPath,options,finalOutputPath)
assert(~isfile(outputPath)&&~isfolder(outputPath),'inkprof:Exists','Output already exists: %s',outputPath);
[outputFolder,outputStem,outputExtension]=fileparts(outputPath);
tiffName=outputStem+outputExtension;
if outputFolder=="",outputFolder=pwd;end
ti2Path=fullfile(outputFolder,outputStem+".ti2");
layoutPath=fullfile(outputFolder,outputStem+"-layout.json");
verificationPath=fullfile(outputFolder,outputStem+"-verification.json");
manifestPath=fullfile(outputFolder,outputStem+"-manifest.json");
patchCgatsPath=fullfile(outputFolder,outputStem+"-patches.cgats");
physicalCgatsPath=fullfile(outputFolder,outputStem+"-layout.cgats");
readmePath=fullfile(outputFolder,outputStem+"-README.txt");
txfPath=fullfile(outputFolder,outputStem+"-candidate.txf");
for sidecar=[ti2Path,layoutPath,verificationPath,manifestPath,patchCgatsPath,physicalCgatsPath,readmePath]
    assert(~isfile(sidecar)&&~isfolder(sidecar),'inkprof:Exists','Output already exists: %s',sidecar);
end
target=inkprof.importTarget(sourcePath,RGBScale=options.RGBScale);
count=numel(target.ids);pages=ceil(count/580);
assert(pages*20<=999,'inkprof:Layout','Too many rows for the TI2 index pattern.');
if referencePath~=""
assert(count==575 && ~options.Randomize,'inkprof:Layout','Reference-order mode requires 575 patches without randomization.');
reference=imread(referencePath);
assert(isa(reference,'uint8')&&isequal(size(reference),[780 1052 3]), ...
    'inkprof:Layout','Expected the observed 1052 x 780 RGB reference TIFF.');

% Reference geometry is 263 x 195 mm at 4 pixels/mm. The coloured area is
% 29 columns x 20 rows of 8 mm squares, beginning at (14.75,24.5) mm.
cells=zeros(580,3);n=0;
for row=1:20
    for column=1:29
        n=n+1;
        cells(n,:)=double(reshape(reference(114+(row-1)*32,75+(column-1)*32,:),1,3));
    end
end

% Recover the reference ordering while retaining the exact PXF device
% values. The five unmatched 210-grey cells are non-source fillers.
used=false(575,1);mapping=zeros(580,1);difference=nan(580,1);
for k=1:580
    % Ignore arithmetic noise in distance ties after scale normalization.
    % Only matching distances are rounded; source RGB and TIFF precision remain intact.
    d=round(max(abs(target.rgbOriginal/target.rgbScale*255-cells(k,:)),[],2),10);d(used)=inf;
    [difference(k),index]=min(d);
    if difference(k)<=1,mapping(k)=index;used(index)=true;end
end
assert(all(used)&&nnz(mapping)==575&&nnz(mapping==0)==5&&max(difference(mapping>0))<=1, ...
    'inkprof:Layout','Reference colours do not match the source patch set.');
assert(all(all(cells(mapping==0,:)==210)),'inkprof:Layout','Unexpected reference filler colours.');

else
    order=(1:count)';
    if options.Randomize
        stream=RandStream('mt19937ar','Seed',options.Seed);order=order(randperm(stream,count));
    end
    mapping=[order;zeros(pages*580-count,1)];
end

dpi=options.DPI;width=round(263*dpi/25.4);height=round(195*dpi/25.4);
layout=repmat(struct('sampleId',"",'originalId',"",'originalName',"",'sampleLoc',"", ...
    'page',0,'rowOnPage',0,'row',0,'column',"",'rectMm',zeros(1,4),'rgbOriginal',zeros(1,3), ...
    'rgbPercent',zeros(1,3),'rgb16',zeros(1,3),'isPadding',false),pages*580,1);
for k=1:numel(mapping)
    page=floor((k-1)/580)+1;local=mod(k-1,580);
    row=floor(local/29);column=mod(local,29);globalRow=(page-1)*20+row+1;
    if mapping(k)>0
        value=uint16(round(target.rgbOriginal(mapping(k),:)/target.rgbScale*65535));
        sampleId=string(mapping(k));originalId=target.ids(mapping(k));originalName=target.names(mapping(k));
        rgbOriginal=target.rgbOriginal(mapping(k),:);isPadding=false;
    else
        value=uint16([210 210 210]*257);
        sampleId="0";originalId="";originalName="";rgbOriginal=[210 210 210]/255*target.rgbScale;isPadding=true;
    end
    loc=string(globalRow)+argyllColumnLabel(column+1);
    layout(k)=struct('sampleId',sampleId,'originalId',originalId,'originalName',originalName, ...
        'sampleLoc',loc,'page',page,'rowOnPage',row+1,'row',globalRow,'column',columnLabel(column+1), ...
        'rectMm',[14.75+8*column 24.5+8*row 8 8],'rgbOriginal',rgbOriginal, ...
        'rgbPercent',double(value)/65535*100,'rgb16',double(value),'isPadding',isPadding);
end
tiffNames=strings(pages,1);tiffPaths=strings(pages,1);
for page=1:pages
image=repmat(uint16(65535),height,width,3);
selected=layout([layout.page]==page);
for k=1:numel(selected)
    rect=selected(k).rectMm;
    x=mmPixel(rect(1),dpi);x2=mmPixel(rect(1)+rect(3),dpi)-1;
    y=mmPixel(rect(2),dpi);y2=mmPixel(rect(2)+rect(4),dpi)-1;
    for channel=1:3,image(y:y2,x:x2,channel)=uint16(selected(k).rgb16(channel));end
end

% Dotted crop/row guides model the supplied TIFF without copying its text.
grey=uint16(32768);dot=max(1,round(0.75*dpi/25.4));gap=dot;
image=dottedH(image,0,263,0,grey,dot,gap,dpi);
image=dottedH(image,0,263,194.75,grey,dot,gap,dpi);
[image,rowGuides]=inkprof.internal.drawRowGuides(image,dpi,[14.75 246.75],24.5+8*(0:20));
image=dottedV(image,0,0,195,grey,dot,gap,dpi);
image=dottedV(image,262.75,0,195,grey,dot,gap,dpi);

titleText="InkProf Quality Profiling RGB printer";
image=inkprof.internal.drawBitmapText(image,"SIZE 263 X 195 MM",[131.5 15],dpi,2.5,"center");
for row=1:20
    image=inkprof.internal.drawBitmapText(image,string((page-1)*20+row),[1.25 24.5+(row-1)*8+0.8],dpi,2.0,"left",uint16(32768));
end
for column=1:29
    label=columnLabel(column);
    image=inkprof.internal.drawBitmapText(image,label,[14.75+(column-.5)*8 21],dpi,2.2,"center");
end

if page==1,tiffNames(page)=tiffName;else,tiffNames(page)=outputStem+compose('_%02d',page)+outputExtension;end
% Legacy 263 x 195 mm cropped artwork: retain geometry; centre inside paper margins.
image=inkprof.internal.drawPrintFurniture(image,dpi,page,pages,options.Date+" "+options.Time,fullfile(fileparts(finalOutputPath),tiffNames(page)),target.targetInfo.footerText,3.5);

parent=fileparts(outputPath);if parent~=""&&~isfolder(parent),mkdir(parent);end
tiffPaths(page)=fullfile(outputFolder,tiffNames(page));
file=Tiff(tiffPaths(page),'w');cleanup=onCleanup(@()close(file));
tags=struct('ImageLength',height,'ImageWidth',width,'Photometric',Tiff.Photometric.RGB, ...
    'BitsPerSample',16,'SamplesPerPixel',3,'PlanarConfiguration',Tiff.PlanarConfiguration.Chunky, ...
    'Compression',Tiff.Compression.LZW,'RowsPerStrip',32,'XResolution',dpi,'YResolution',dpi, ...
    'ResolutionUnit',Tiff.ResolutionUnit.Inch,'Software','InkProf TIFF16 renderer');
file.setTag(tags);file.write(image);clear cleanup
end
inkprof.internal.writeMeasurementTi2(ti2Path,layout);
inkprof.internal.writeExchangeCgats(patchCgatsPath,physicalCgatsPath,target,layout);
inkprof.internal.writeJson(layoutPath,struct('schemaVersion',1,'documentType',"inkprof.tiff16-layout", ...
    'targetInfo',target.targetInfo,'rowGuides',rowGuides,'coordinateSystem',"mm from upper left; rectMm=[x y width height]",'patches',layout));
verification=inkprof.internal.verifyTiff16Bundle(tiffPaths,ti2Path,layout,target);
inkprof.internal.writeJson(verificationPath,verification);
txfStatus="not requested";txfFile=strings(0,1);
templatePath=options.TxfTemplate;
if templatePath==""
    [~,~,sourceExt]=fileparts(sourcePath);
    if any(lower(sourceExt)==[".pxf",".txf"]),templatePath=sourcePath;end
end
if templatePath==""
    [referenceFolder,referenceStem]=fileparts(referencePath);
    candidate=fullfile(referenceFolder,referenceStem+".pxf");if isfile(candidate),templatePath=candidate;end
end
if options.WriteTxfCandidate
    exact8=all(mod(reshape([layout.rgb16],3,[])',257)==0,'all');
    if exact8 && templatePath~="" && isfile(templatePath)
        assert(~isfile(txfPath)&&~isfolder(txfPath),'inkprof:Exists','Output already exists: %s',txfPath);
        for page=1:pages
            if pages==1,name=outputStem+"-candidate.txf";else,name=outputStem+compose("-page_%02d-candidate.txf",page);end
            inkprof.internal.writeTxfCandidate(fullfile(outputFolder,name),templatePath,layout([layout.page]==page));
            txfFile(end+1,1)=name;
        end
        txfStatus="experimental candidate; structural round-trip verified; receiver layout and physical measurement not verified";

    elseif ~exact8
        txfStatus="not created: TIFF contains RGB16 values that the tested integer TXF variant cannot represent exactly";
    else
        txfStatus="not created: no compatible TXF/PXF XML template supplied";
    end
end
fid=fopen(readmePath,'w');assert(fid>=0,'inkprof:IO','Cannot write package instructions.');closer=onCleanup(@()fclose(fid));
fprintf(fid,['INKPROF TIFF16 EXCHANGE AND MEASUREMENT PACKAGE\n\n' ...
    'Print: %s at 100%% physical size without colour conversion.\n' ...
    'Argyll measurement: run chartread with the basename; it reads %s.ti2 and writes TI3.\n' ...
    'Generic exchange: %s-patches.cgats contains the source patches; %s-layout.cgats contains all physical positions.\n' ...
    'TXF status: %s\n' ...
    'Do not use the TXF candidate for an existing print until its imported layout and a physical measurement have been verified.\n' ...
    'MXF is a measurement-result format and is therefore not created before measurement.\n'], ...
    join(tiffNames,", "),outputStem,outputStem,outputStem,txfStatus);clear closer
manifest=struct('schemaVersion',1,'documentType',"inkprof.tiff16-package", ...
    'createdUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
    'targetInfo',target.targetInfo,'sourcePath',target.sourcePath,'sourceSHA256',target.sourceSHA256,'sourceFormat',target.sourceFormat, ...
    'rgbScale',target.rgbScale,'tiff',tiffName,'tiffs',tiffNames,'pageCount',pages, ...
    'randomize',options.Randomize,'seed',options.Seed,'ti2',string(outputStem)+".ti2", ...
    'layout',string(outputStem)+"-layout.json",'verification',string(outputStem)+"-verification.json", ...
    'patchCgats',string(outputStem)+"-patches.cgats",'physicalLayoutCgats',string(outputStem)+"-layout.cgats", ...
    'txfCandidate',txfFile,'txfStatus',txfStatus, ...
    'measurementStatus',"TIFF/TI2 identity verified; physical chartread measurement not yet verified", ...
    'files',[]);
files=[reshape(tiffNames,1,[]),string(outputStem)+".ti2",string(outputStem)+"-layout.json", ...
    string(outputStem)+"-verification.json",string(outputStem)+"-patches.cgats", ...
    string(outputStem)+"-layout.cgats",string(outputStem)+"-README.txt"];
files=[files,reshape(txfFile,1,[])];
entries=struct('name',{},'sha256',{});
for k=1:numel(files),entries(end+1)=struct('name',files(k),'sha256',inkprof.internal.sha256(fullfile(outputFolder,files(k))));end %#ok<AGROW>
manifest.files=entries;
inkprof.internal.writeJson(manifestPath,manifest);
info=struct('file',inkprof.internal.absolutePath(outputPath),'widthMm',263,'heightMm',195, ...
    'dpi',dpi,'bitsPerChannel',16,'rows',20,'columns',29,'sourcePatches',count,'fillers',sum(mapping==0),'pageCount',pages,'tiffs',tiffPaths, ...
    'title',titleText,'pageLabel',"1 ("+pages+")",'ti2',inkprof.internal.absolutePath(ti2Path), ...
    'layout',inkprof.internal.absolutePath(layoutPath),'verification',inkprof.internal.absolutePath(verificationPath), ...
    'manifest',inkprof.internal.absolutePath(manifestPath),'patchCgats',inkprof.internal.absolutePath(patchCgatsPath), ...
    'physicalLayoutCgats',inkprof.internal.absolutePath(physicalCgatsPath),'txfCandidate',txfFile,'txfStatus',txfStatus);
end

function pixel=mmPixel(mm,dpi)
pixel=round(mm*dpi/25.4)+1;
end

function image=dottedH(image,x1,x2,y,value,dot,gap,dpi)
yy=min(size(image,1),mmPixel(y,dpi));a=mmPixel(x1,dpi);b=min(size(image,2),mmPixel(x2,dpi));
for x=a:dot+gap:b,image(yy,x:min(b,x+dot-1),:)=value;end
end

function image=dottedV(image,x,y1,y2,value,dot,gap,dpi)
xx=min(size(image,2),mmPixel(x,dpi));a=mmPixel(y1,dpi);b=min(size(image,1),mmPixel(y2,dpi));
for y=a:dot+gap:b,image(y:min(b,y+dot-1),xx,:)=value;end
end

function text=columnLabel(index)
if index<=26,text=string(char('A'+index-1));else,text="2"+string(char('A'+index-27));end
end

function text=argyllColumnLabel(index)
if index<=26,text=string(char('A'+index-1));else,text="A"+string(char('A'+index-27));end
end

function removeStage(path)
if isfolder(path),rmdir(path,'s');end
end
