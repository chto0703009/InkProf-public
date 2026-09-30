function report=exportChartTi2(chartJson,outputPath)
%EXPORTCHARTTI2 Adapt the canonical JSON chart to chartread's exchange format.
arguments
    chartJson (1,1) string
    outputPath (1,1) string
end
chart=jsondecode(fileread(chartJson));
assert(chart.schemaVersion==1&&string(chart.documentType)=="inkprof.measurement-chart",'inkprof:ChartFormat','Unsupported chart JSON.');
assert(string(chart.colorSpace)=="RGB",'inkprof:ColorFormat','Fel färgformat: endast RGB stöds.');
patches=chart.patches;
assert(numel(patches)==chart.patchCount,'inkprof:ChartFormat','Patch count mismatch.');
for p=reshape(patches,1,[]),inkprof.internal.requireRgb(double(p.rgbPercent(:)'),100);end
ids=string({patches.sampleId});loc=string({patches.sampleLoc});
assert(numel(unique(loc))==numel(loc)&&all(strlength(loc)>0),'inkprof:Identity','Duplicate/empty patch locations.');
real=ids~="0";assert(numel(unique(ids(real)))==sum(real),'inkprof:Identity','Duplicate source IDs.');
tables=struct('signature',{},'metadata',{},'fields',{},'data',{});
for t=reshape(chart.exchangeTables,1,[])
    metadata=cell(numel(t.metadata),1);
    for k=1:numel(metadata),metadata{k}=string(t.metadata(k).tokens(:)');end
    fields=string(t.fields(:)');data=strings(numel(t.rows),numel(fields));
    for k=1:numel(t.rows),data(k,:)=string(t.rows(k).values(:)');end
    tables(end+1)=struct('signature',string(t.signature),'metadata',{metadata},'fields',fields,'data',data); %#ok<AGROW>
end
assert(tables(1).signature=="CTI2"&&size(tables(1).data,1)==numel(patches),'inkprof:ChartFormat','Invalid exchange template.');
[ok,idx]=ismember(["SAMPLE_ID","SAMPLE_LOC","RGB_R","RGB_G","RGB_B"],tables(1).fields);
assert(all(ok),'inkprof:ChartFormat','Missing exchange fields.');
for k=1:numel(patches)
    tables(1).data(k,idx)=[string(patches(k).sampleId),string(patches(k).sampleLoc),compose('%.17g',double(patches(k).rgbPercent(:)'))];
end
doc=struct('documentType',"inkprof.cgats",'tables',tables);
report=inkprof.exportCgats(outputPath,doc);
end
