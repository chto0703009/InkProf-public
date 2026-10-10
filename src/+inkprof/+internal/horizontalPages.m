% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function horizontalPages(folder,paperMm,outputFolder,targetInfo,iccFile)
% Transpose native Argyll strips into horizontal left-to-right rows.
% Preserve all patch/spacer pixels, redraw labels upright in whitespace.
% iccFile (optional): printer ICC to embed as a tag only. Pixels are unchanged;
% the tag stops applications from assigning a working space to untagged RGB.
if nargin<5,iccFile="";end
icc=uint8([]);
if strlength(iccFile)>0
    fid=fopen(iccFile,'r');assert(fid>=0,'inkprof:IO','Cannot read ICC to embed: %s',iccFile);
    icc=fread(fid,Inf,'*uint8');fclose(fid);
    assert(numel(icc)>=132&&isequal(char(icc(37:40))','acsp'),'inkprof:ICC','Not an ICC profile: %s',iccFile);
end
native=fullfile(folder,'argyll');
pages=dir(fullfile(native,'target*.tif'));
timestamp=string(datetime('now','Format','yyyy-MM-dd HH:mm'));
placements=struct('tiff',{},'offsetMm',{},'rowGuides',{});
controls=struct('page',{},'tiff',{},'label',{},'rgbPercent',{},'rgb16',{},'rectMm',{});
for k=1:numel(pages)
    name=string(pages(k).name);[~,stem]=fileparts(name);
    input=Tiff(fullfile(native,name),'r');c=onCleanup(@()close(input));
    image=input.read();
    res=[double(input.getTag('XResolution')),double(input.getTag('YResolution'))];
    unit=input.getTag('ResolutionUnit');clear c
    dpi=res;if unit==Tiff.ResolutionUnit.Centimeter,dpi=dpi*2.54;end
    assert(isa(image,'uint16')&&size(image,3)==3,'inkprof:TIFF','Expected native RGB16.');
    % CHT D and X boxes identify the strip body including boundary spacers.
    lines=splitlines(string(fileread(fullfile(native,stem+".cht"))));rects=[];rows=struct;
    for line=reshape(lines,1,[])
        tokens=split(strtrim(line));
        if numel(tokens)~=11||~any(tokens(1)==["X","D"]),continue;end
        geom=str2double(tokens(6:9));
        assert(all(isfinite(geom))&&all(str2double(tokens(10:11))==0),'inkprof:Geometry','Unsupported native boxes.');
        rects(end+1,:)=[geom(3:4)' geom(1:2)']; %#ok<AGROW>
        if tokens(1)=="X"
            [rowLabel,~,~]=inkprof.internal.decodeLocation(tokens(2));
            key=matlab.lang.makeValidName(char(rowLabel));
            rows.(key)=struct('y',geom(3)+geom(1)/2,'x',geom(4)+geom(2)/2,'label',rowLabel,'height',geom(1));
        end
    end
    assert(~isempty(rects),'inkprof:Geometry','No strip geometry found.');
    lo=min(rects(:,1:2),[],1);hi=max(rects(:,1:2)+rects(:,3:4),[],1);
    % Copy the whole strip region, including interpatch/row spacers. Other
    % native content is orientation-dependent text/fiducials, not scan data.
    x=max(1,floor(lo(1)*dpi(1)/25.4)+1):min(size(image,2),ceil(hi(1)*dpi(1)/25.4)+1);
    y=max(1,floor(lo(2)*dpi(2)/25.4)+1):min(size(image,1),ceil(hi(2)*dpi(2)/25.4)+1);
    outDpi=fliplr(dpi);
    assert(outDpi(1)==outDpi(2),'inkprof:TIFF','Expected square pixels.');
    pixels=floor(paperMm.*outDpi/25.4+1e-6);
    % Center the entire strip body, including spacers, using integer pixels.
    % Reserve heading space and the same footer band as the text renderer.
    furniture=inkprof.internal.printFurnitureLayout(paperMm(1));
    top=ceil(20*outDpi(2)/25.4);bottom=floor((paperMm(2)-furniture.chartReservedMm)*outDpi(2)/25.4);
    assert(numel(y)<=pixels(1)&&numel(x)<=bottom-top,'inkprof:Geometry','Strip body does not fit the printable area.');
    dx=floor((pixels(1)-numel(y))/2)+1-y(1);
    dy=top+floor((bottom-top-numel(x))/2)+1-x(1);
    offset=[dx dy]./outDpi*25.4;
    output=repmat(uint16(65535),pixels(2),pixels(1),3);
    output(x+dy,y+dx,:)=permute(image(y,x,:),[2 1 3]);
    keys=fieldnames(rows);
    boundaries=[];
    for j=1:numel(keys)
        item=rows.(keys{j});
        boundaries=[boundaries item.y+offset(2)+[-.5 .5]*item.height]; %#ok<AGROW>
    end
    [output,guides]=inkprof.internal.drawRowGuides(output,outDpi(1), ...
        [lo(2) hi(2)]+offset(1),boundaries);
    placements(end+1)=struct('tiff',name,'offsetMm',offset,'rowGuides',guides); %#ok<AGROW>
    for j=1:numel(keys)
        item=rows.(keys{j});
        % Labels align near the row top, outside the central scan band.
        leftLabel=max(2,min(8,lo(2)+offset(1)-12));
        labelY=item.y-item.height/2+0.8+offset(2);
        output=inkprof.internal.drawBitmapText(output,item.label, ...
            [leftLabel,labelY],outDpi(1),2.0,"left",uint16(32768));
        % Mirror the label in the opposite margin for reverse scans. The same
        % row ID and height are used; all patch and spacer pixels stay intact.
        output=inkprof.internal.drawBitmapText(output,item.label, ...
            [paperMm(1)-leftLabel,labelY],outDpi(1),2.0,"right",uint16(32768));
    end
    % Column letters share their X positions across the rows. Use any row.
    first=rows.(keys{1}).label;
    for line=reshape(lines,1,[])
        tokens=split(strtrim(line));
        if numel(tokens)~=11||tokens(1)~="X",continue;end
        [rowLabel,columnLabel,~]=inkprof.internal.decodeLocation(tokens(2));
        if rowLabel~=first,continue;end
        geom=str2double(tokens(6:9));
        output=label(output,columnLabel,[geom(4)+geom(2)/2-2+offset(1),lo(1)-6+offset(2)],outDpi,2.5);
    end
    assert(hi(1)+offset(2)<paperMm(2)-furniture.chartReservedMm+1,'inkprof:Geometry','No clear space for print controls.');
    [output,pageControls]=inkprof.internal.drawPrintControls(output,outDpi(1),k,name);
    controls=[controls pageControls]; %#ok<AGROW>
    output=inkprof.internal.drawPrintFurniture(output,outDpi(1),k,numel(pages),timestamp,fullfile(outputFolder,name),targetInfo.footerText);
    file=Tiff(fullfile(folder,name),'w');c=onCleanup(@()close(file));
    tags=struct('ImageLength',size(output,1),'ImageWidth',size(output,2), ...
        'Photometric',Tiff.Photometric.RGB,'BitsPerSample',16,'SamplesPerPixel',3, ...
        'PlanarConfiguration',Tiff.PlanarConfiguration.Chunky,'Compression',Tiff.Compression.LZW, ...
        'RowsPerStrip',32,'XResolution',outDpi(1),'YResolution',outDpi(2), ...
        'ResolutionUnit',Tiff.ResolutionUnit.Inch,'Software','InkProf horizontal rows');
    if ~isempty(icc),tags.ICCProfile=icc;end
    file.setTag(tags);file.write(output);clear c
end
inkprof.internal.writeJson(fullfile(folder,'page-placement.json'),struct('schemaVersion',1, ...
    'documentType',"inkprof.page-placement",'pages',placements));
inkprof.internal.writeJson(fullfile(folder,'print-controls.json'),struct('schemaVersion',1, ...
    'documentType',"inkprof.print-controls",'measurementMode',"stationary native M0 spots", ...
    'excludedFromProfiling',true,'patches',controls));
% SAMPLE_LOC/IDs/RGB and strip membership remain unchanged. Only page axes
% change; chartread uses the same row label and patch order.
text=fileread(fullfile(native,'target.ti2'));
replacement=sprintf('PAPER_SIZE "%.10gx%.10g"',paperMm);
text=regexprep(text,'(?m)^PAPER_SIZE[^\r\n]*',replacement);
fid=fopen(fullfile(folder,'target.ti2'),'w');c=onCleanup(@()fclose(fid));fprintf(fid,'%s',text);
end

function image=label(image,text,position,dpi,heightMm)
% Fixed bitmap labels require only MATLAB Base; no fonts/toolboxes/renderers.
alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/ ';
glyphs={ ...
 '01110 10001 10001 11111 10001 10001 10001', ...
 '11110 10001 10001 11110 10001 10001 11110', ...
 '01111 10000 10000 10000 10000 10000 01111', ...
 '11110 10001 10001 10001 10001 10001 11110', ...
 '11111 10000 10000 11110 10000 10000 11111', ...
 '11111 10000 10000 11110 10000 10000 10000', ...
 '01111 10000 10000 10111 10001 10001 01111', ...
 '10001 10001 10001 11111 10001 10001 10001', ...
 '11111 00100 00100 00100 00100 00100 11111', ...
 '00111 00010 00010 00010 10010 10010 01100', ...
 '10001 10010 10100 11000 10100 10010 10001', ...
 '10000 10000 10000 10000 10000 10000 11111', ...
 '10001 11011 10101 10101 10001 10001 10001', ...
 '10001 11001 10101 10011 10001 10001 10001', ...
 '01110 10001 10001 10001 10001 10001 01110', ...
 '11110 10001 10001 11110 10000 10000 10000', ...
 '01110 10001 10001 10001 10101 10010 01101', ...
 '11110 10001 10001 11110 10100 10010 10001', ...
 '01111 10000 10000 01110 00001 00001 11110', ...
 '11111 00100 00100 00100 00100 00100 00100', ...
 '10001 10001 10001 10001 10001 10001 01110', ...
 '10001 10001 10001 10001 10001 01010 00100', ...
 '10001 10001 10001 10101 10101 10101 01010', ...
 '10001 10001 01010 00100 01010 10001 10001', ...
 '10001 10001 01010 00100 00100 00100 00100', ...
 '11111 00001 00010 00100 01000 10000 11111', ...
 '01110 10001 10011 10101 11001 10001 01110', ...
 '00100 01100 00100 00100 00100 00100 01110', ...
 '01110 10001 00001 00010 00100 01000 11111', ...
 '11110 00001 00001 01110 00001 00001 11110', ...
 '00010 00110 01010 10010 11111 00010 00010', ...
 '11111 10000 10000 11110 00001 00001 11110', ...
 '01110 10000 10000 11110 10001 10001 01110', ...
 '11111 00001 00010 00100 01000 01000 01000', ...
 '01110 10001 10001 01110 10001 10001 01110', ...
 '01110 10001 10001 01111 00001 00001 01110', ...
 '00001 00010 00010 00100 01000 01000 10000', ...
 '00000 00000 00000 00000 00000 00000 00000'};
scale=max(1,floor(heightMm*dpi(2)/25.4/7));
x=round(position(1)*dpi(1)/25.4)+1;y=round(position(2)*dpi(2)/25.4)+1;
for ch=char(text)
    index=find(alphabet==ch,1);assert(~isempty(index),'inkprof:Label','Unsupported label character.');
    bits=reshape(strrep(glyphs{index},' ','')=='1',5,7)';mask=logical(kron(bits,true(scale)));
    assert(x>=1&&y>=1&&x+size(mask,2)-1<=size(image,2)&&y+size(mask,1)-1<=size(image,1), ...
        'inkprof:Label','Label does not fit the page.');
    for channel=1:3
        block=image(y:y+size(mask,1)-1,x:x+size(mask,2)-1,channel);block(mask)=0;
        image(y:y+size(mask,1)-1,x:x+size(mask,2)-1,channel)=block;
    end
    x=x+6*scale;
end
end
