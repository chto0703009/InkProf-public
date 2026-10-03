% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function layout=readLayout(folder)
% CHT X boxes produced by printtarg -S use mm from the image's upper left.
% Restrict to individual rectangular boxes, not arbitrary scanin geometry.
t=inkprof.internal.readCgats(fullfile(folder,'target.ti2'));
required=["SAMPLE_ID","SAMPLE_LOC","RGB_R","RGB_G","RGB_B"];
[ok,idx]=ismember(required,t.fields);assert(all(ok),'inkprof:Layout','Incomplete TI2.');
layout=struct('sampleId',{},'location',{},'rgbPercent',{},'page',{},'strip',{},'patchInStrip',{},'rectMm',{},'tiff',{},'isPadding',{},'column',{},'coordinate',{});
geometryFolder=folder;
horizontal=isfolder(fullfile(folder,'argyll'));
placements=[];
if horizontal
    geometryFolder=fullfile(folder,'argyll');
    placementFile=fullfile(folder,'page-placement.json');
    if isfile(placementFile)
        placement=jsondecode(fileread(placementFile));placements=placement.pages;
    end
end
files=dir(fullfile(geometryFolder,'target*.cht'));
assert(~isempty(files),'inkprof:Layout','No CHT geometry generated.');
for f=1:numel(files)
    name=string(files(f).name); [~,stem]=fileparts(name);
    number=regexp(char(stem),'_(\d+)$','tokens','once');page=1;
    if ~isempty(number),page=str2double(number{1});end
    imageName=stem+".tif";
    offset=[0 0];
    if ~isempty(placements)
        index=find(string({placements.tiff})==imageName);
        assert(isscalar(index),'inkprof:Geometry','Missing or duplicated page placement.');
        offset=reshape(placements(index).offsetMm,1,[]);
        assert(numel(offset)==2&&all(isfinite(offset)),'inkprof:Geometry','Invalid page offset.');
    end
    assert(isfile(fullfile(folder,imageName)),'inkprof:Layout','CHT/TIFF pairing missing.');
    lines=splitlines(string(fileread(fullfile(geometryFolder,name))));
    for line=reshape(lines,1,[])
        tokens=split(strtrim(line));
        if isempty(tokens)||tokens(1)~="X",continue;end
        assert(numel(tokens)==11 && tokens(2)==tokens(3) && all(tokens(4:5)=="_") && all(str2double(tokens(10:11))==0), ...
            'inkprof:Layout','Unsupported CHT box geometry.');
        loc=tokens(2);row=find(t.data(:,idx(2))==loc);
        assert(isscalar(row),'inkprof:Layout','CHT location must match exactly one TI2 row.');
        geom=str2double(tokens(6:9));
        assert(all(isfinite(geom))&&all(geom(1:2)>0),'inkprof:Layout','Invalid rectangle.');
        [rowLabel,columnLabel,columnIndex]=inkprof.internal.decodeLocation(loc);
        item=struct('sampleId',t.data(row,idx(1)),'location',loc, ...
            'rgbPercent',str2double(t.data(row,idx(3:5))), ...
            'page',page,'strip',rowLabel,'patchInStrip',columnIndex, ...
            'rectMm',[geom(3:4)' geom(1:2)'],'tiff',imageName,'isPadding',t.data(row,idx(1))=="0",'column',columnLabel,'coordinate',columnLabel+rowLabel);
        if horizontal
            item.rectMm=item.rectMm([2 1 4 3]);
            item.rectMm(1:2)=item.rectMm(1:2)+offset;
        end
        layout(end+1)=item; %#ok<AGROW>
    end
end
assert(numel(layout)==size(t.data,1)&&numel(unique([layout.location]))==numel(layout),'inkprof:Layout','TI2/CHT coverage mismatch.');
end
