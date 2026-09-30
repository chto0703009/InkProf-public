function report=exportCgats(path,document)
%EXPORTCGATS Write a CGATS document without changing its dialect or values.
% Edit tables.fields/data/metadata before export. Counts are regenerated.
% Unknown metadata/columns and repeated keywords are preserved. No overwrite.
arguments
    path (1,1) string
    document (1,1) struct
end
if isfield(document,'documentType') && string(document.documentType)=="inkprof.target"
    target=document;
    inkprof.internal.requireRgb(target.rgbOriginal,target.rgbScale);
    fields=["SAMPLE_ID","SAMPLE_NAME","RGB_R","RGB_G","RGB_B"];
    data=[string(target.ids(:)),string(target.names(:)),compose('%.17g',target.rgbOriginal)];
    metadata={ ["ORIGINATOR","InkProf"]; ["KEYWORD","RGB_SCALE"]; ["RGB_SCALE",string(target.rgbScale)] };
    table=struct('signature',"CGATS.17",'metadata',{metadata},'fields',fields,'data',data);
    document=struct('documentType',"inkprof.cgats",'tables',table);
end
assert(isfield(document,'documentType') && string(document.documentType)=="inkprof.cgats", ...
    'inkprof:CGATS','Expected document from inkprof.importCgats.');
path=inkprof.internal.absolutePath(path);
assert(~isfile(path)&&~isfolder(path),'inkprof:Exists','Output already exists: %s',path);
lines=strings(0,1);
for t=reshape(document.tables,1,[])
    fields=string(t.fields);data=string(t.data);
    assert(isrow(fields)&&size(data,2)==numel(fields),'inkprof:CGATS','Invalid data dimensions.');
    lines(end+1,1)=atom(t.signature,false);
    for j=1:numel(t.metadata)
        tokens=string(t.metadata{j});
        if any(tokens(1)==["NUMBER_OF_FIELDS","NUMBER_OF_SETS"]),continue;end
        line=atom(tokens(1),false);
        for k=2:numel(tokens),line=line+" "+atom(tokens(k),true);end
        lines(end+1,1)=line; %#ok<AGROW>
    end
    lines=[lines;"NUMBER_OF_FIELDS "+numel(fields);"BEGIN_DATA_FORMAT";join(arrayfun(@(v)atom(v,false),fields)," ");"END_DATA_FORMAT"; ...
        "NUMBER_OF_SETS "+size(data,1);"BEGIN_DATA"]; %#ok<AGROW>
    for j=1:size(data,1)
        tokens=strings(1,numel(fields));
        for k=1:numel(fields)
            numeric=~isempty(regexp(char(data(j,k)),'^[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?$','once'));
            tokens(k)=atom(data(j,k),~numeric || any(fields(k)==["SAMPLE_ID","SAMPLE_NAME","SAMPLE_LOC"]));
        end
        lines(end+1,1)=join(tokens," "); %#ok<AGROW>
    end
    lines=[lines;"END_DATA";""]; %#ok<AGROW>
end
raw=join(lines,newline);parsed=inkprof.internal.parseCgats(raw);
assert(numel(parsed)==numel(document.tables),'inkprof:CGATS','Export table mismatch.');
for j=1:numel(parsed)
    assert(isequal(parsed(j).fields,string(document.tables(j).fields)) && isequal(parsed(j).data,string(document.tables(j).data)), ...
        'inkprof:CGATS','Export changed fields or values.');
end
parent=fileparts(path);assert(isfolder(parent),'inkprof:Input','Output directory does not exist.');
tmp=string(tempname(parent));cleanup=onCleanup(@()removeTemp(tmp));
fid=fopen(tmp,'w','n','UTF-8');assert(fid>=0,'inkprof:IO','Cannot write output.');closer=onCleanup(@()fclose(fid));
fprintf(fid,'%s',raw);clear closer
check=inkprof.importCgats(tmp);assert(isequal(check.tables,parsed),'inkprof:CGATS','Readback failed.');
assert(~isfile(path),'inkprof:Exists','Output appeared during export.');
[ok,msg]=movefile(tmp,path);assert(ok,'inkprof:IO','%s',msg);
report=struct('path',path,'tables',numel(parsed),'sha256',inkprof.internal.sha256(path), ...
    'verified',true,'note',"Values/metadata preserved; formatting and comments may change. No dialect conversion.");
end
function value=atom(value,quoted)
value=string(value);
assert(isscalar(value)&&~ismissing(value)&&~contains(value,[string(char(10)),string(char(13)),string(char(34))]), ...
    'inkprof:CGATS','Multiline strings and embedded quotation marks are unsupported.');
if quoted,value=string(char(34))+value+string(char(34));
else,assert(strlength(value)>0 && isempty(regexp(char(value),'[\s#]','once')),'inkprof:CGATS','Invalid bare token.');end
end
function removeTemp(path)
if isfile(path),delete(path);end
end
