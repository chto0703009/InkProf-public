% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function target = importTarget(path, options)
%IMPORTTARGET Read RGB patch definitions; no measured data or relayout implied.
% CGATS needs RGBScale. CxF3 uses MaxRange/default 255; Prism PXF/TXF use 255.
arguments
    path (1,1) string
    options.RGBScale (1,1) double = NaN
end
assert(isfile(path),'inkprof:Input','File does not exist: %s',path);
path=inkprof.internal.absolutePath(path);
[~,~,ext]=fileparts(path); ext=lower(ext);
layout=struct; xyz=[]; xyzStatus="absent";
if ext==".ti2"
    assert(isnan(options.RGBScale)||options.RGBScale==100,'inkprof:Scale','TI2 RGB scale must be 100.');
    % Reuse measurement-chart validation and preserve original layout/tables.
    session=string(tempname);
    chart=inkprof.prepareChart(path,session);
    cleanup=onCleanup(@()rmdir(session,'s'));
    layout=chart;
    keep=~[chart.patches.isPadding];
    ids=string({chart.patches(keep).sampleId})';names=ids;
    rgb=vertcat(chart.patches(keep).rgbPercent);scale=100;
    t=inkprof.internal.readCgats(path);
    [ok,idx]=ismember(["XYZ_X","XYZ_Y","XYZ_Z"],t.fields);
    if all(ok)
        xyz=str2double(t.data(keep,idx));
        assert(all(isfinite(xyz),'all'),'inkprof:CGATS','Nonfinite XYZ.');
        xyzStatus="source TI2 estimates, not measurements";
    end
elseif ext==".cxf"
    cxf=inkprof.readCxF(path);
    objects=cxf.objects;
    assert(all(arrayfun(@(x)~isempty(x.rgb),objects)), 'inkprof:CxF', ...
        'Target import requires one device RGB definition per object. Use readCxF for mixed measurement data.');
    ids=string({objects.id})';names=string({objects.name})';
    scales=[objects.rgbScale]';
    assert(numel(unique(scales))==1,'inkprof:Scale','Mixed RGB MaxRange values require explicit normalization.');
    scale=scales(1);
    assert(isnan(options.RGBScale)||options.RGBScale==scale,'inkprof:Scale','RGBScale conflicts with CxF MaxRange/default 255.');
    rgb=zeros(numel(objects),3);
    for k=1:numel(objects),rgb(k,:)=reshape(objects(k).rgb,1,3);end
    layout=struct('cxf',cxf,'status',"Preserved metadata; physical layout not inferred");
elseif any(ext==[".pxf",".txf"])
    raw=fileread(path);
    assert(isempty(regexpi(raw,'<!DOCTYPE|<!ENTITY','once')),'inkprof:XML','DTD/entities are not accepted.');
    factory=javax.xml.parsers.DocumentBuilderFactory.newInstance();
    factory.setNamespaceAware(true);
    factory.setFeature('http://apache.org/xml/features/disallow-doctype-decl',true);
    factory.setFeature('http://xml.org/sax/features/external-general-entities',false);
    factory.setFeature('http://xml.org/sax/features/external-parameter-entities',false);
    doc=factory.newDocumentBuilder().parse(java.io.File(char(path)));
    ns='http://colorexchangeformat.com/CxF3-core';
    root=doc.getDocumentElement();
    assert(string(root.getNamespaceURI())==string(ns),'inkprof:XML','Only CxF3 core is supported.');
    custom=doc.getElementsByTagNameNS('http://www.xrite.com/products/prism','CustomAttributes');
    knownPrism=custom.getLength()==1 && any(ext==[".pxf",".txf"]);
    scale=options.RGBScale;
    if isnan(scale) && knownPrism, scale=255; end
    assert(isfinite(scale) && scale>0,'inkprof:Scale','Explicit RGBScale is required for this XML variant.');
    if custom.getLength()==1
        attrs=custom.item(0).getAttributes();
        for j=0:attrs.getLength()-1
            a=attrs.item(j); layout.(matlab.lang.makeValidName(char(a.getNodeName())))=string(a.getNodeValue());
        end
    end
    assert(doc.getElementsByTagNameNS(ns,'ColorCMYK').getLength()==0, ...
        'inkprof:ColorFormat','Fel färgformat: InkProf stöder endast RGB-target. CMYK kan inte importeras som target.');
    objects=doc.getElementsByTagNameNS(ns,'Object');
    ids=strings(0,1); names=ids; rgb=zeros(0,3);
    for j=0:objects.getLength()-1
        obj=objects.item(j);
        assert(string(obj.getAttribute('ObjectType'))=="Target",'inkprof:XML','Only Target objects are accepted in patch imports.');
        colors=obj.getElementsByTagNameNS(ns,'ColorRGB');
        assert(colors.getLength()==1,'inkprof:XML','Expected one RGB definition per patch.');
        color=colors.item(0); values=zeros(1,3);
        specification=string(color.getAttribute('ColorSpecification'));
        assert(specification=="Unknown",'inkprof:XML', ...
            'Only the verified ColorSpecification="Unknown" RGB target variant is supported.');
        for k=1:3
            channels={'R','G','B'}; v=color.getElementsByTagNameNS(ns,channels{k});
            assert(v.getLength()==1,'inkprof:XML','Missing or duplicate RGB channel.');
            values(k)=str2double(string(v.item(0).getTextContent()));
        end
        ids(end+1,1)=string(obj.getAttribute('Id')); %#ok<AGROW>
        names(end+1,1)=string(obj.getAttribute('Name')); %#ok<AGROW>
        rgb(end+1,:)=values; %#ok<AGROW>
    end
else
    assert(any(ext==[".ti1",".txt",".cgats"]),'inkprof:Input','Supported input: TI1, PXF, TXF, CxF3 and RGB CGATS TXT.');
    d=inkprof.importCgats(path);
    assert(numel(d.tables)==1 || ext==".ti1",'inkprof:CGATS','Select one table explicitly for a multi-table patch import.');
    t=inkprof.internal.readCgats(path);
    isCmyk=any(ismember(upper(t.fields),["CMYK_C","CMYK_M","CMYK_Y","CMYK_K"]));
    if isfield(t.headers,'COLOR_REP'),isCmyk=isCmyk || contains(upper(t.headers.COLOR_REP),"CMYK");end
    assert(~isCmyk,'inkprof:ColorFormat', ...
        'Fel färgformat: InkProf stöder endast RGB-target. CMYK kan inte importeras som target.');
    if ext==".ti1"
        assert(t.signature=="CTI1" && isfield(t.headers,'COLOR_REP') && any(t.headers.COLOR_REP==["RGB","iRGB"]), ...
            'inkprof:CGATS','Expected RGB CTI1.');
        scale=100;
        assert(isnan(options.RGBScale)||options.RGBScale==100,'inkprof:Scale','TI1 RGB scale must be 100.');
    else
        scale=options.RGBScale;
        assert(isfinite(scale)&&scale>0,'inkprof:Scale','Pass RGBScale explicitly for CGATS TXT (e.g. 255 for RGB8 data).');
    end
    required=["SAMPLE_ID","RGB_R","RGB_G","RGB_B"];
    [ok,idx]=ismember(required,t.fields);
    assert(all(ok),'inkprof:CGATS','Missing RGB fields or SAMPLE_ID.');
    ids=t.data(:,idx(1)); names=ids;
    if any(t.fields=="SAMPLE_NAME"), names=t.data(:,t.fields=="SAMPLE_NAME"); end
    rgb=str2double(t.data(:,idx(2:4)));
    [ok,idx]=ismember(["XYZ_X","XYZ_Y","XYZ_Z"],t.fields);
    if ext==".ti1" && all(ok)
        xyz=str2double(t.data(:,idx)); xyzStatus="source TI1 estimates, not measurements";
        assert(all(isfinite(xyz),'all'),'inkprof:CGATS','Nonfinite XYZ.');
    end
end
assert(~isempty(ids)&&all(strlength(ids)>0)&&numel(unique(ids))==numel(ids),'inkprof:Identity','Patch IDs must be nonempty and unique.');
assert(all(isfinite(rgb)&rgb>=0&rgb<=scale,'all'),'inkprof:Scale','RGB outside the declared scale or nonfinite.');
target=struct('schemaVersion',1,'documentType',"inkprof.target",'sourcePath',path, ...
    'sourceSHA256',inkprof.internal.sha256(path),'sourceFormat',ext,'ids',ids,'names',names, ...
    'rgbOriginal',rgb,'rgbScale',scale,'rgbPercent',rgb/scale*100, ...
    'estimatedXYZ',xyz,'xyzStatus',xyzStatus,'sourceLayout',layout, ...
    'layoutStatus',"source metadata only; original physical layout not reproduced");
if any(ext==[".pxf",".txf",".cxf"])
    declared=layout;
elseif ext==".ti2"
    declared=layout.metadata;
else
    declared=t.headers;
end
target.targetInfo=inkprof.internal.importTargetInfo(rgb/scale,path,ids,declared);
end
