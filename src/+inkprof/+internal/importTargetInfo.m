function info=importTargetInfo(rgb,path,ids,declared)
%IMPORTTARGETINFO Import provenance; trust a design sidecar only by hash.
info=inkprof.internal.targetInfo(rgb,path);
[parent,stem,ext]=fileparts(path);ext=lower(ext);sidecar=fullfile(parent,stem+".json");
if any(ext==[".ti1",".ti2"]) && isfile(sidecar)
    saved=jsondecode(fileread(sidecar));key=erase(ext,".")+"SHA256";
    metadata=struct;
    if ext==".ti1"&&isfield(saved,'definition'),metadata=saved.definition;
    elseif isfield(saved,'print'),metadata=saved.print;end
    if isfield(saved,'targetInfo')&&isfield(metadata,key)
        assert(string(metadata.(key))==info.source.sha256,'inkprof:Integrity','Design sidecar does not match the imported file.');
        fit=(1:numel(ids))';
        if isfield(saved,'roles')&&isfield(saved,'sampleId')
            [found,index]=ismember(ids,string(saved.sampleId));
            assert(all(found),'inkprof:Integrity','Design sidecar patch IDs do not match.');
            roles=string(saved.roles);fit=find(roles(index)=="fit");
            assert(~isempty(fit),'inkprof:Integrity','No fitting points in sidecar.');
        end
        info=inkprof.internal.targetInfo(rgb,path,saved.targetInfo.generation,fit);
        info.upstream=saved.targetInfo;
    end
end
info.source.declaredMetadata=declared;
end
