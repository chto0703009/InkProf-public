% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function writeTxfCandidate(path,templatePath,layout)
%WRITETXFCANDIDATE Write an explicitly experimental TXF compatibility file.
inkprof.internal.requireRgb(vertcat(layout.rgb16),65535);
assert(all(mod(vertcat(layout.rgb16),257)==0,'all'),'inkprof:TXFPrecision','TXF cannot represent these RGB16 values exactly.');
% Receiver places objects top-to-bottom by column. Keep coordinate names
% tied to the physical row-major layout while reordering only TXF objects.
rect=vertcat(layout.rectMm);[~,order]=sortrows(rect,[1 2]);layout=layout(order);
inkprof.importTarget(templatePath);
template=string(fileread(templatePath));
objectTemplate=string(regexp(char(template),'<cc:Object ObjectType=.*?</cc:Object>','match','once'));
assert(strlength(objectTemplate)>0,'inkprof:TXFTemplate','Missing target object template.');
objects=strings(numel(layout),1);
for k=1:numel(layout)
    object=regexprep(objectTemplate,'Name="[^"]*"','Name="'+escape(layout(k).sampleLoc)+'"','once');
    object=regexprep(object,'Id="[^"]*"',compose('Id="c%d"',k),'once');
    rgb=round(layout(k).rgb16/257);
    for channel=1:3
        tag=["R","G","B"];object=regexprep(object,'<cc:'+tag(channel)+'>[^<]*</cc:'+tag(channel)+'>', ...
            "<cc:"+tag(channel)+">"+rgb(channel)+"</cc:"+tag(channel)+">");
    end
    objects(k)=object;
end
raw=replaceBlock(template,'<cc:ObjectCollection>.*?</cc:ObjectCollection>', ...
    "<cc:ObjectCollection>"+newline+join(objects,newline)+newline+"</cc:ObjectCollection>");
custom=string(regexp(char(raw),'<xrp:CustomAttributes [^>]*?/?>','match','once'));
assert(strlength(custom)>0,'inkprof:TXFTemplate','Missing layout attributes.');
attrs=struct('ColorSpace',"RGB",'MeasurementDevice',"i1Pro 2", ...
    'PatchSizeWidthPercent',compose('%.17g',100/18),'PatchSizeHeightPercent',"0",'NumberPatchColumns',"29",'NumberPatchRows',"20", ...
    'NumberPatchPages',"1",'PageWidth',"263",'PageHeight',"195",'PaperFormat',"0", ...
    'PaperOrientation',"Landscape",'PatchSizeWidthValue',"8",'PatchSizeHeightValue',"8", ...
    'UsePatchSettingDefaults',"False",'ScramblePatches',"False",'TitleString',"InkProf TIFF16 target", ...
    'numberCorePatches',string(numel(layout)),'numberImagePatches',"0",'numberSpotPatches',"0");
for key=reshape(string(fieldnames(attrs)),1,[])
    attribute=key+'="'+escape(attrs.(key))+'"';
    if ~isempty(regexp(char(custom),char('\s'+key+'="'),'once'))
        custom=regexprep(custom,key+'="[^"]*"',attribute);
    else
        custom=replace(custom,'/>',' '+attribute+'/>');
    end
end
raw=replaceBlock(raw,'<xrp:CustomAttributes [^>]*?/?>',custom);
raw=regexprep(raw,'<cc:Creator>[^<]*</cc:Creator>','<cc:Creator>InkProf</cc:Creator>');
fid=fopen(path,'w','n','UTF-8');assert(fid>=0,'inkprof:IO','Cannot write TXF.');cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',raw);clear cleanup
back=inkprof.importTarget(path);expected=reshape([layout.rgb16],3,[])'/257;
assert(isequal(back.rgbOriginal,expected),'inkprof:TXFValues','TXF RGB round-trip failed.');
end

function text=escape(text)
text=string(text);text=replace(text,'&','&amp;');text=replace(text,'<','&lt;');text=replace(text,'>','&gt;');text=replace(text,'"','&quot;');
end

function result=replaceBlock(source,pattern,replacement)
[a,b]=regexp(char(source),pattern,'start','end','once');assert(~isempty(a),'inkprof:TXFTemplate','Missing XML block.');
text=char(source);result=string(text(1:a-1))+replacement+string(text(b+1:end));
end
