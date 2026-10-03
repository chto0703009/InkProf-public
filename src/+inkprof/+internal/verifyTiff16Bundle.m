% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function report=verifyTiff16Bundle(tiffPath,ti2Path,layout,target)
%VERIFYTIFF16BUNDLE Verify TIFF16 pixels, TI2 rows and source coverage.
t=inkprof.internal.readCgats(ti2Path);
required=["SAMPLE_ID","SAMPLE_LOC","RGB_R","RGB_G","RGB_B"];
[ok,index]=ismember(required,t.fields);assert(all(ok),'inkprof:TI2','Incomplete TI2 fields.');
assert(size(t.data,1)==numel(layout),'inkprof:TI2','TI2/layout row count differs.');
seen=zeros(numel(target.ids),1);largest=0;
currentPage=0;
for k=1:numel(layout)
    if layout(k).page~=currentPage
        currentPage=layout(k).page;
tif=Tiff(tiffPath(currentPage),'r');cleanup=onCleanup(@()close(tif));image=tif.read();
bits=double(tif.getTag('BitsPerSample'));samples=double(tif.getTag('SamplesPerPixel'));
assert(isa(image,'uint16')&&all(bits==16)&&samples==3,'inkprof:TIFF','Expected RGB TIFF16.');
dpi=[double(tif.getTag('XResolution')),double(tif.getTag('YResolution'))];clear cleanup
    end
    item=layout(k);
    assert(string(t.data(k,index(1)))==item.sampleId&&string(t.data(k,index(2)))==item.sampleLoc, ...
        'inkprof:TI2','TI2 identity differs at row %d.',k);
    ti2Rgb=str2double(t.data(k,index(3:5)));
    assert(max(abs(ti2Rgb-item.rgbPercent))<1e-7,'inkprof:TI2','TI2 RGB differs at %s.',item.sampleLoc);
    rect=item.rectMm;x=round((rect(1)+rect(3)*[.25 .75])*dpi(1)/25.4)+1;
    y=round((rect(2)+rect(4)*[.25 .75])*dpi(2)/25.4)+1;
    actual=double(image(y(1):y(2),x(1):x(2),:));
    error=max(abs(actual-reshape(item.rgb16,1,1,3)),[],'all');largest=max(largest,error);
    assert(error==0,'inkprof:Pixels','TIFF/layout mismatch at %s.',item.sampleLoc);
    if ~item.isPadding
        id=str2double(item.sampleId);assert(isfinite(id)&&id>=1&&id<=numel(seen),'inkprof:Identity','Invalid source ID.');
        seen(id)=seen(id)+1;
    end
end
assert(all(seen==1),'inkprof:Identity','Each source patch must occur exactly once.');
report=struct('schemaVersion',1,'documentType',"inkprof.tiff16-verification",'passed',true, ...
    'tiffTi2IdentityVerified',true,'sourceCoverageVerified',true,'physicalMeasurementVerified',false, ...
    'sourcePatches',numel(target.ids),'paddingPatches',sum([layout.isPadding]), ...
    'pageCount',numel(tiffPath),'rowsPerPage',20,'columns',29,'maxPixelErrorCodes',largest);
end
