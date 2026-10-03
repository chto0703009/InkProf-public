% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function report=exportTxfTarget(packageFolder,outputFolder,options)
%EXPORTTXFTARGET Experimental TXF candidates plus exact patch mapping.
% One TXF per printed page. NOT yet qualified for measuring existing prints.
% A TXF cannot encode Argyll's separator geometry with the verified attributes.
arguments
    packageFolder (1,1) string
    outputFolder (1,1) string
    options.Experimental (1,1) logical = false
    options.Template (1,1) string = ""
end
assert(options.Experimental,'inkprof:UnverifiedTXF', ...
    'TXF layout compatibility is not verified. Use Experimental=true only for compatibility testing.');
packageFolder=inkprof.internal.absolutePath(packageFolder);
outputFolder=inkprof.internal.absolutePath(outputFolder);
assert(~isfolder(outputFolder)&&~isfile(outputFolder),'inkprof:Exists','Output already exists.');
inkprof.verifyPackage(packageFolder);
layout=jsondecode(fileread(fullfile(packageFolder,'layout.json')));
manifest=jsondecode(fileread(fullfile(packageFolder,'manifest.json')));
patches=layout.patches;
assert(all(arrayfun(@(p) numel(p.rgb16)==3,patches)), ...
    'inkprof:ColorFormat','Fel färgformat: InkProf stöder endast RGB-target och RGB-mätunderlag.');
inkprof.internal.requireRgb(reshape([patches.rgb16],3,[])',65535);
assert(all(mod([patches.rgb16],257)==0,'all'),'inkprof:TXFPrecision', ...
    'The tested TXF variant requires integer RGB 0..255 in the tested variant. This print contains other RGB16 codes; no silent rounding is allowed.');
templatePath=options.Template;
if templatePath=="",templatePath=fullfile(packageFolder,'source','original.txf');end
assert(isfile(templatePath),'inkprof:TXFTemplate','Supply a verified TXF as Template.');
inkprof.importTarget(templatePath); % Validate XML safely before processing the observed variant.
template=string(fileread(templatePath));
objectTemplate=string(regexp(char(template),'<cc:Object ObjectType=.*?</cc:Object>','match','once'));
assert(strlength(objectTemplate)>0 && contains(template,'<xrp:CustomAttributes '), ...
    'inkprof:TXFTemplate','Expected the verified cc/xrp Prism serialization.');
parent=fileparts(outputFolder);assert(isfolder(parent),'inkprof:Input','Output parent does not exist.');
stage=string(tempname(parent));mkdir(stage);cleanup=onCleanup(@()removeStage(stage));
date=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
reports=struct('file',{},'page',{},'patchCount',{},'columns',{},'rows',{},'sha256',{});
map=struct('txfFile',{},'txfId',{},'txfIndex',{},'page',{},'rowOnPage',{},'columnOnPage',{}, ...
    'coordinate',{},'sampleId',{},'isPadding',{},'rgb16',{},'rgb255',{},'rectMm',{});
for page=reshape(unique([patches.page]),1,[])
    selected=patches([patches.page]==page);
    rect=reshape([selected.rectMm],4,[])';
    [~,order]=sortrows(rect,[2 1]);selected=selected(order);rect=rect(order,:);
    ys=unique(rect(:,2));xs=unique(rect(:,1));cols=numel(xs);rows=numel(ys);
    assert(numel(selected)==rows*cols,'inkprof:TXFGeometry','Only complete rectangular pages supported.');
    assert(all(abs(rect(:,3:4)-rect(1,3:4))<1e-6,'all'),'inkprof:TXFGeometry','Unequal patch sizes.');
    expectedX=repmat(xs(:),rows,1);expectedY=repelem(ys(:),cols);
    assert(all(abs(rect(:,1)-expectedX)<1e-6)&all(abs(rect(:,2)-expectedY)<1e-6), ...
        'inkprof:TXFGeometry','Irregular page grid.');
    name=compose('page_%02d.txf',page);title="InkProf experimental page "+page;
    objects=strings(numel(selected),1);
    for k=1:numel(selected)
        p=selected(k);rgb16=double(p.rgb16(:)');rgb255=rgb16/257;id="c"+k;
        object=regexprep(objectTemplate,'Name="[^"]*"','Name="'+escape(p.coordinate)+'"','once');
        object=regexprep(object,'Id="[^"]*"','Id="'+id+'"','once');
        for channel=1:3
            names=["R","G","B"];tag=names(channel);
            object=regexprep(object,'<cc:'+tag+'>[^<]*</cc:'+tag+'>', ...
                '<cc:'+tag+'>'+string(round(rgb255(channel)))+'</cc:'+tag+'>');
        end
        objects(k)=object;
        map(end+1)=struct('txfFile',name,'txfId',id,'txfIndex',k,'page',page, ...
            'rowOnPage',ceil(k/cols),'columnOnPage',mod(k-1,cols)+1, ...
            'coordinate',string(p.coordinate),'sampleId',string(p.sampleId), ...
            'isPadding',p.isPadding,'rgb16',rgb16,'rgb255',rgb255,'rectMm',p.rectMm); %#ok<AGROW>
    end
    % These attributes are observed in supplied Prism TXF/MXF files. They do
    % not provide a verified representation of per-boundary coloured spacers.
    % The verified receiver re-import uses percent fields, not only mm values.
    % Only 10 x 8 mm has been checked by an application round-trip.
    assert(all(abs(rect(1,3:4)-[10 8])<1e-6),'inkprof:TXFGeometry', ...
        'The experimental i1Pro 2 export currently supports only verified 10 x 8 mm patch dimensions.');
    sizeMm=double(manifest.renderPaperSizeMm(:)');orientation="Portrait";
    if sizeMm(1)>sizeMm(2),orientation="Landscape";end
    attrs=struct('ColorSpace',"RGB",'DimensionUnit',"2",'MeasurementDevice',"i1Pro 2", ...
        'MeasurementDeviceSerialNumber',"0",'MeasurementMode',"2",'MeasurementPerPatch',"0", ...
        'NumberPatchColumns',string(cols),'NumberPatchRows',string(rows),'NumberPatchPages',"1", ...
        'PageWidth',compose('%.10g',sizeMm(1)),'PageHeight',compose('%.10g',sizeMm(2)), ...
        'PaperFormat',"0",'PaperOrientation',orientation,'PatchSizeWidthValue',string(rect(1,3)), ...
        'PatchSizeHeightValue',string(rect(1,4)), ...
        'PatchSizeWidthPercent',compose('%.17g',(rect(1,3)-7)/18*100), ...
        'PatchSizeHeightPercent',compose('%.17g',(rect(1,4)-8)/4*100), ...
        'UsePatchSettingDefaults',"False", ...
        'ScramblePatches',"False",'BarCodeEnabled',"False",'TitleString',title, ...
        'TestChartType',"RGB Variable",'numberCorePatches',string(numel(selected)), ...
        'numberImagePatches',"0",'numberSpotPatches',"0");
    custom=string(regexp(char(template),'<xrp:CustomAttributes [^>]*?/?>','match','once'));
    for key=reshape(string(fieldnames(attrs)),1,[])
        attribute=key+'="'+escape(attrs.(key))+'"';
        if ~isempty(regexp(char(custom),char('\s'+key+'="'),'once'))
            custom=regexprep(custom,key+'="[^"]*"',attribute);
        else
            custom=replace(custom,'/>',' '+attribute+'/>');
        end
    end
    raw=replaceBlock(template,'<cc:ObjectCollection>.*?</cc:ObjectCollection>', ...
        "<cc:ObjectCollection>"+newline+join(objects,newline)+newline+"</cc:ObjectCollection>");
    raw=replaceBlock(raw,'<xrp:CustomAttributes [^>]*?/?>',custom);
    raw=regexprep(raw,'<cc:CreationDate>[^<]*</cc:CreationDate>', ...
        '<cc:CreationDate>'+replace(date,'Z','+00:00')+'</cc:CreationDate>');
    raw=regexprep(raw,'<cc:Creator>[^<]*</cc:Creator>','<cc:Creator>InkProf</cc:Creator>');
    path=fullfile(stage,name);fid=fopen(path,'w','n','UTF-8');assert(fid>=0,'inkprof:IO','Cannot write TXF.');
    closer=onCleanup(@()fclose(fid));fprintf(fid,'%s',raw);clear closer
    back=inkprof.importTarget(path);
    expected=reshape([selected.rgb16],3,[])';
    assert(isequal(round(back.rgbOriginal*257),expected),'inkprof:TXFValues','RGB16 round-trip failed.');
    assert(isequal(back.names,string({selected.coordinate})'),'inkprof:TXFValues','Patch order changed.');
    reports(end+1)=struct('file',name,'page',page,'patchCount',numel(selected),'columns',cols,'rows',rows, ...
        'sha256',inkprof.internal.sha256(path)); %#ok<AGROW>
end
report=struct('schemaVersion',1,'documentType',"inkprof.experimental-txf-export", ...
    'sourceManifestSHA256',inkprof.internal.sha256(fullfile(packageFolder,'manifest.json')), ...
    'sourcePackage',packageFolder,'templateSHA256',inkprof.internal.sha256(templatePath),'files',reports,'mapping',map, ...
    'rgb16RoundTripVerified',true,'receiverImportVerified',false,'receiverLayoutVerified',false, ...
    'physicalMeasurementVerified',false,'status',"EXPERIMENTAL: do not use to measure existing prints", ...
    'limitations',"Prism spacer geometry and object-to-grid order require receiver verification. Only exact 8-bit-representable RGB16 codes are accepted.");
inkprof.internal.writeJson(fullfile(stage,'txf-export.json'),report);
fid=fopen(fullfile(stage,'READ-ME.txt'),'w');assert(fid>=0,'inkprof:IO','Cannot write instructions.');
fprintf(fid,['EXPERIMENTAL TXF compatibility test, not approved measurement files.\n' ...
    'One file per printed page. All patches including Argyll padding are included.\n' ...
    'txf-export.json preserves the exact source mapping and RGB16 codes.\n' ...
    'Load the TXF in the receiving measurement application. Verify rows, columns, order, RGB and geometry.\n' ...
    'Do not regenerate or scramble the chart. Do not measure existing prints with these files yet.\n' ...
    'Argyll separators are not represented by verified TXF attributes.\n']);fclose(fid);
assert(~isfolder(outputFolder)&&~isfile(outputFolder),'inkprof:Exists','Output appeared during export.');
[ok,msg]=movefile(stage,outputFolder);assert(ok,'inkprof:IO','%s',msg);clear cleanup
end
function text=escape(text)
text=string(text);text=replace(text,'&','&amp;');text=replace(text,'<','&lt;');
text=replace(text,'>','&gt;');text=replace(text,'"','&quot;');
end
function removeStage(path)
if isfolder(path),rmdir(path,'s');end
end

function result=replaceBlock(source,pattern,replacement)
[a,b]=regexp(char(source),pattern,'start','end','once');
assert(~isempty(a),'inkprof:TXFTemplate','Missing template block.');
text=char(source);result=string(text(1:a-1))+replacement+string(text(b+1:end));
end
