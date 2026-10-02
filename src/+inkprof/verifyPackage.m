function report=verifyPackage(folder)
%VERIFYPACKAGE Check hashes and every target patch against TIFF16 pixels.
arguments
    folder (1,1) string
end
folder=inkprof.internal.absolutePath(folder);
manifestPath=fullfile(folder,'manifest.json');
hasManifest=isfile(manifestPath);
if hasManifest
    manifest=jsondecode(fileread(manifestPath));
    for i=1:numel(manifest.files)
        relative=string(manifest.files(i).name);
        assert(~contains(relative,"..") && ~startsWith(relative,["/","\"]),'inkprof:Manifest','Unsafe manifest path.');
        assert(inkprof.internal.sha256(fullfile(folder,relative))==string(manifest.files(i).sha256), ...
            'inkprof:Integrity','Checksum mismatch: %s',relative);
    end
end
layout=inkprof.internal.readLayout(folder);
horizontal=isfolder(fullfile(folder,'argyll'));
if horizontal
    native=inkprof.internal.readCgats(fullfile(folder,'argyll','target.ti2'));
    final=inkprof.internal.readCgats(fullfile(folder,'target.ti2'));
    assert(isequal(native.fields,final.fields)&&isequal(native.data,final.data),'inkprof:Identity','TI2 patch data changed during orientation.');
    rows=unique(string({layout.strip}));
    for row=reshape(rows,1,[])
        patches=layout(string({layout.strip})==row);
        [~,order]=sort([patches.patchInStrip]);rects=vertcat(patches(order).rectMm);
        assert(all(abs(rects(:,2)-rects(1,2))<1e-6)&&all(diff(rects(:,1))>0),'inkprof:Direction','A measuring row must run horizontally left to right.');
    end
end
target=jsondecode(fileread(fullfile(folder,'target.json')));
ids=string(target.ids);rgb=target.rgbPercent;
seen=zeros(numel(ids),1);largest=0;largestInput=0;
names=unique(string({layout.tiff}));
pages=struct('file',{},'widthPixels',{},'heightPixels',{},'dpi',{},'sizeMm',{});
for name=reshape(names,1,[])
    path=fullfile(folder,name); tif=Tiff(path,'r');c=onCleanup(@()close(tif));
    bits=double(tif.getTag('BitsPerSample'));samples=double(tif.getTag('SamplesPerPixel'));
    assert(all(bits==16)&&samples==3&&tif.getTag('Photometric')==Tiff.Photometric.RGB, ...
        'inkprof:TIFF','Expected 16-bit RGB TIFF: %s',name);
    dpi=[double(tif.getTag('XResolution')),double(tif.getTag('YResolution'))];
    unit=tif.getTag('ResolutionUnit');
    assert(any(unit==[Tiff.ResolutionUnit.Inch,Tiff.ResolutionUnit.Centimeter]),'inkprof:TIFF','Missing physical resolution unit.');
    if unit==Tiff.ResolutionUnit.Centimeter,dpi=dpi*2.54;end
    image=tif.read();clear c
    assert(isa(image,'uint16'),'inkprof:TIFF','Expected uint16 pixels.');
    sizeMm=[size(image,2),size(image,1)]./dpi*25.4;
    if isfield(target.printSettings,'maximumWidthMm')
        assert(sizeMm(1)<=target.printSettings.maximumWidthMm+1e-6,'inkprof:TargetSize','TIFF exceeds recorded sweep limit: %s',name);
    end
    if isfield(target.printSettings,'maximumLengthMm')
        assert(sizeMm(2)<=target.printSettings.maximumLengthMm+1e-6,'inkprof:TargetSize','TIFF exceeds recorded length limit: %s',name);
    end
    if hasManifest
        if isfield(manifest,'renderPaperSizeMm'),expectedMm=double(manifest.renderPaperSizeMm(:)');else,expectedMm=double(manifest.options.PaperSizeMm(:)');end
        expected=expectedMm.*dpi/25.4;
        assert(all(abs([size(image,2),size(image,1)]-expected)<=1.1),'inkprof:TIFF','Page dimensions differ from recipe.');
    end
    pages(end+1)=struct('file',name,'widthPixels',size(image,2),'heightPixels',size(image,1),'dpi',dpi,'sizeMm',sizeMm); %#ok<AGROW>
    for k=find(string({layout.tiff})==name)
        p=layout(k);r=p.rectMm;
        % Every pixel in the central half rectangle must have the same code.
        x=round((r(1)+r(3)*[.25 .75])*dpi(1)/25.4)+1;
        y=round((r(2)+r(4)*[.25 .75])*dpi(2)/25.4)+1;
        assert(x(1)>=1&&y(1)>=1&&x(2)<=size(image,2)&&y(2)<=size(image,1), ...
            'inkprof:Geometry','Patch %s outside TIFF.',p.location);
        expected=round(p.rgbPercent/100*65535);
        actual=double(image(y(1):y(2),x(1):x(2),:));
        err=max(abs(actual-reshape(expected,1,1,3)),[],'all');largest=max(largest,err);
        assert(err==0,'inkprof:Pixels','TI2/CHT/TIFF mismatch at %s (%g codes).',p.location,err);
        if ~p.isPadding
            id=str2double(p.sampleId);
            assert(isfinite(id)&&id==fix(id)&&id>=1&&id<=numel(ids),'inkprof:Identity','Invalid generated SAMPLE_ID.');
            seen(id)=seen(id)+1;
            inputError=max(abs(expected-rgb(id,:)/100*65535));largestInput=max(largestInput,inputError);
            assert(inputError<=0.501,'inkprof:Quantization','Source changed beyond 16-bit quantization.');
        end
    end
end
assert(all(seen==1),'inkprof:Identity','Missing or duplicated source patch mapping.');
report=struct('schemaVersion',1,'documentType',"inkprof.verification",'passed',true, ...
    'sourcePatches',numel(ids),'paddingPatches',sum([layout.isPadding]),'pages',pages, ...
    'maxTi2PixelErrorCodes',largest,'maxSourceQuantizationErrorCodes',largestInput, ...
    'horizontalRowsVerified',horizontal,'physicalMeasurementVerified',false,'receiverLayoutVerified',false);
end
