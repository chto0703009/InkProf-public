% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function plan=preparePairedChart(folder)
% Two logical passes per physical row. Reverse pass has reversed identities,
% so chartread -B stores both readings separately without overwriting.
chart=jsondecode(fileread(fullfile(folder,'chart.json')));
runFolder=fullfile(folder,'paired');
assert(~isfolder(runFolder),'inkprof:Exists','Paired measurement already prepared.');
doc=inkprof.importCgats(fullfile(folder,'source.ti2'));t=doc.tables(1);
[~,idcol]=ismember('SAMPLE_ID',t.fields);[~,loccol]=ismember('SAMPLE_LOC',t.fields);
p=chart.patches;steps=chart.stepsInPass;n=numel(p);
assert(2*n/steps<=999,'inkprof:Layout','Paired scan exceeds the supported row index range.');
assert(mod(n,steps)==0,'inkprof:Layout','Incomplete physical rows.');
% Require the indexing convention used by InkProf horizontal charts.
assert(all(~cellfun('isempty',regexp(cellstr(string({p.sampleLoc})),'^\d+[A-Z]+$','once'))), ...
 'inkprof:Layout','Paired scanning requires numbered rows and lettered columns.');
% TI2 records may be stored by SAMPLE_ID even when the print is randomized.
% Sort only the traversal, preserving indices into the authoritative chart.
coordinates=zeros(n,2);
for k=1:n
    [rowLabel,~,columnIndex]=inkprof.internal.decodeLocation(p(k).sampleLoc);
    coordinates(k,:)=[str2double(rowLabel),columnIndex];
end
[~,physicalOrder]=sortrows(coordinates,[1 2]);
newData=strings(2*n,numel(t.fields));mapping=zeros(2*n,1);scan=zeros(2*n,1);
passes=struct('physicalRow',{},'page',{},'rowOnPage',{},'phase',{},'expectedDirection',{});
pageRows=repelem((1:numel(chart.passesInStrips))',chart.passesInStrips(:));
for row=1:n/steps
    indices=reshape(physicalOrder((row-1)*steps+(1:steps)),1,[]);
    originalRow=regexp(char(p(indices(1)).sampleLoc),'^\d+','match','once');
    for j=1:steps
        [rowLabel,~,columnIndex]=inkprof.internal.decodeLocation(p(indices(j)).sampleLoc);
        assert(rowLabel==string(originalRow)&&columnIndex==j,'inkprof:Layout', ...
            'Paired scanning requires each physical row to contain columns A onward exactly once.');
    end
    for phase=1:2
        logicalRow=2*row-2+phase;order=indices;if phase==2,order=fliplr(order);end
        dest=(logicalRow-1)*steps+(1:steps);newData(dest,:)=t.data(order,:);
        mapping(dest)=order;scan(dest)=phase;
        for j=1:steps
            if p(order(j)).isPadding,newData(dest(j),idcol)="0";else,newData(dest(j),idcol)=string(dest(j));end
            [~,column]=inkprof.internal.decodeLocation(p(indices(j)).sampleLoc);
            newData(dest(j),loccol)=string(logicalRow)+column;
        end
        page=pageRows(row);rowOnPage=row-sum(chart.passesInStrips(1:page-1));
        direction="forward";if phase==2,direction="reverse";end
        passes(logicalRow)=struct('physicalRow',string(originalRow),'page',page,'rowOnPage',rowOnPage,'phase',phase,'expectedDirection',direction);
    end
end
t.data=newData;
for k=1:numel(t.metadata)
    token=t.metadata{k};
    if token(1)=="PASSES_IN_STRIPS2",token(2)=join(string(2*chart.passesInStrips),",");end
    if token(1)=="STRIP_INDEX_PATTERN",token(2)="0-9,@-9,@-9;1-999";end
    t.metadata{k}=token;
end
doc.tables(1)=t;
input=fullfile(folder,'paired-input.ti2');inkprof.exportCgats(input,doc);
inkprof.prepareChart(input,runFolder);
plan=struct('schemaVersion',1,'documentType',"inkprof.paired-scan-plan", ...
 'physicalChartSHA256',inkprof.internal.sha256(fullfile(folder,'chart.json')), ...
 'runtimeChartSHA256',inkprof.internal.sha256(fullfile(runFolder,'chart.json')), ...
 'runtimeFolder',"paired",'originalChartIndex',mapping,'scanNumber',scan,'passes',passes, ...
 'directionPolicy',"chartread -B; forward and explicitly reversed expected patch order; operator follows displayed direction");
inkprof.internal.writeJson(fullfile(folder,'paired-plan.json'),plan);
end
