% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function saved=saveRGBDefinition(design,ti1Path)
%SAVERGBDEFINITION Save device RGB points and design metadata, without layout.
arguments
    design (1,1) struct
    ti1Path (1,1) string
end
assert(isfield(design,'documentType')&&string(design.documentType)=="inkprof.rgb-design",'inkprof:Design','Expected RGB target design.');
inkprof.internal.requireRgb(design.rgb,1);
n=size(design.rgb,1);
assert(numel(design.sampleId)==n&&numel(unique(string(design.sampleId)))==n&&numel(design.roles)==n, ...
    'inkprof:Design','Invalid design identities or roles.');
ti1Path=inkprof.internal.absolutePath(ti1Path);[parent,stem,ext]=fileparts(ti1Path);
assert(lower(ext)==".ti1",'inkprof:Design','Choose a .ti1 filename.');
assert(isfolder(parent),'inkprof:Input','Output directory must exist.');
jsonPath=fullfile(parent,stem+".json");
outputs=[ti1Path,jsonPath];
hasPrecondition=isfield(design,'preconditioning')&&isfield(design.preconditioning,'sha256');
if hasPrecondition,outputs(end+1)=fullfile(parent,stem+"-precondition.icc");end
for p=outputs
    assert(~isfile(p)&&~isfolder(p),'inkprof:Exists','Output already exists: %s',p);
end
w=string(tempname(parent));mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
table=struct('signature',"CTI1",'metadata',{{["DESCRIPTOR",design.name];["ORIGINATOR","InkProf"];["COLOR_REP","iRGB"]}}, ...
    'fields',["SAMPLE_ID","RGB_R","RGB_G","RGB_B"], ...
    'data',[string(design.sampleId(:)),compose('%.17g',design.rgb*100)]);
inkprof.exportCgats(fullfile(w,'definition.ti1'),struct('documentType',"inkprof.cgats",'tables',table));
record=design;
if isfield(record,'print'),record=rmfield(record,'print');end
info=design.targetInfo;
info.source=struct('fileName',stem+".ti1",'path',ti1Path,'format',".ti1", ...
    'sha256',inkprof.internal.sha256(fullfile(w,'definition.ti1')),'declaredMetadata',struct);
info.footerText=inkprof.internal.targetInfoText(info);record.targetInfo=info;
record.definition=struct('ti1',stem+".ti1",'ti1SHA256',info.source.sha256, ...
    'layoutStatus',"not rendered; open TI1 in inkprof.renderTarget to create TIFF16 and TI2");
if hasPrecondition
    % Archive the exact profile that steered targen, next to the definition.
    copyfile(design.preconditioning.path,fullfile(w,'precondition.icc'));
    assert(inkprof.internal.sha256(fullfile(w,'precondition.icc'))==string(design.preconditioning.sha256), ...
        'inkprof:Integrity','Pre-conditioning profile changed after target generation.');
    record.preconditioning.archivedFile=stem+"-precondition.icc";
end
inkprof.internal.writeJson(fullfile(w,'definition.json'),record);
published=strings(0,1);
try
    sources=[fullfile(w,'definition.ti1'),fullfile(w,'definition.json')];destinations=[ti1Path,jsonPath];
    if hasPrecondition,sources(end+1)=fullfile(w,'precondition.icc');destinations(end+1)=outputs(3);end
    for k=1:numel(sources)
        assert(~isfile(destinations(k))&&~isfolder(destinations(k)),'inkprof:Exists','Output appeared during export.');
        [ok,msg]=copyfile(sources(k),destinations(k));assert(ok,'inkprof:IO','%s',msg);
        published(end+1)=destinations(k); %#ok<AGROW>
    end
catch err
    for p=published,if isfile(p),delete(p);end,end
    rethrow(err);
end
inkprof.internal.recordProjectStep(parent,"definition-saved");
saved=struct('ti1',ti1Path,'json',jsonPath,'patchCount',n);
end
