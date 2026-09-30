function tables=parseCgats(raw)
% Strict text-table parser. Preserve ordered metadata (including repetitions).
lines=splitlines(string(raw));tables=struct('signature',{},'metadata',{},'fields',{},'data',{});
state="signature"; fields=strings(1,0);rows={};meta={};signature="";doneFormat=false;
for lineNo=1:numel(lines)
    line=char(lines(lineNo));if lineNo==1,line=erase(line,char(65279));end
    % Quotes may contain whitespace and #. Embedded quotes are not supported.
    [parts,start,finish]=regexp(line,'"[^"\r\n]*"|[^\s"#]+','match','start','end');
    tokens=strings(1,0);pos=1;
    for n=1:numel(parts)
        gap=line(pos:start(n)-1);
        if contains(gap,'#'),break;end
        assert(all(isspace(gap)),'inkprof:CGATS','Malformed quoting at line %d.',lineNo);
        item=parts{n};
        if startsWith(item,'"'),item=item(2:end-1);end
        tokens(end+1)=string(item);pos=finish(n)+1; %#ok<AGROW>
    end
    tail=line(pos:end);
    if ~contains(tail,'#'),assert(all(isspace(tail)),'inkprof:CGATS','Malformed quoting at line %d.',lineNo);end
    if isempty(tokens),continue;end
    key=tokens(1);
    switch state
        case "signature"
            assert(numel(tokens)==1 && ~startsWith(key,["BEGIN_","END_"]),'inkprof:CGATS','Expected table signature at line %d.',lineNo);
            signature=key;meta={};fields=strings(1,0);rows={};doneFormat=false;state="header";
        case "header"
            if key=="BEGIN_DATA_FORMAT"
                assert(~doneFormat && numel(tokens)==1,'inkprof:CGATS','Duplicate data format.');state="fields";
            elseif key=="BEGIN_DATA"
                assert(doneFormat && numel(tokens)==1,'inkprof:CGATS','Data before format.');state="data";
            else
                assert(numel(tokens)>=2 && ~startsWith(key,["BEGIN_","END_"]),'inkprof:CGATS','Unsupported header at line %d.',lineNo);
                meta{end+1,1}=tokens; %#ok<AGROW>
            end
        case "fields"
            if key=="END_DATA_FORMAT"
                assert(numel(tokens)==1 && ~isempty(fields) && numel(unique(fields))==numel(fields),'inkprof:CGATS','Invalid fields.');
                doneFormat=true;state="header";
            else
                assert(~any(startsWith(tokens,["BEGIN_","END_"])),'inkprof:CGATS','Unclosed format block.');
                fields=[fields tokens]; %#ok<AGROW>
            end
        case "data"
            if key=="END_DATA"
                assert(numel(tokens)==1,'inkprof:CGATS','Invalid END_DATA.');
                checkCount(meta,"NUMBER_OF_FIELDS",numel(fields));checkCount(meta,"NUMBER_OF_SETS",numel(rows));
                data=strings(0,numel(fields));if ~isempty(rows),data=vertcat(rows{:});end
                tables(end+1)=struct('signature',signature,'metadata',{meta},'fields',fields,'data',data); %#ok<AGROW>
                state="signature";
            else
                assert(numel(tokens)==numel(fields),'inkprof:CGATS','Wrong field count at line %d.',lineNo);
                rows{end+1,1}=tokens; %#ok<AGROW>
            end
    end
end
assert(state=="signature" && ~isempty(tables),'inkprof:CGATS','Incomplete or missing table.');
end
function checkCount(meta,key,actual)
found=cellfun(@(v)v(1)==key,meta);
assert(sum(found)==1,'inkprof:CGATS','Missing or duplicate %s.',key);
v=meta{find(found,1)};
assert(numel(v)==2 && str2double(v(2))==actual,'inkprof:CGATS','%s mismatch.',key);
end
