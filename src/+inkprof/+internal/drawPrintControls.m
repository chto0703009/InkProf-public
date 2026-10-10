% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function [image,patches]=drawPrintControls(image,dpi,page,tiff)
% Raw device RGB sentinels; deliberately absent from TI1/TI2 and fitting data.
width=size(image,2)/dpi*25.4;height=size(image,1)/dpi*25.4;
furniture=inkprof.internal.printFurnitureLayout(width);
patches=struct('page',{},'tiff',{},'label',{},'rgbPercent',{},'rgb16',{},'rectMm',{});
labels=["R","G","B"];
for k=1:3
 rect=[width/2-16+(k-1)*12,height-furniture.chartReservedMm+3,8,8];
 rgb=zeros(1,3);rgb(k)=100;codes=round(rgb/100*65535);
 x=floor(rect(1)*dpi/25.4)+1:ceil((rect(1)+rect(3))*dpi/25.4);
 y=floor(rect(2)*dpi/25.4)+1:ceil((rect(2)+rect(4))*dpi/25.4);
 image(y,x,:)=repmat(reshape(uint16(codes),1,1,3),numel(y),numel(x),1);
 image=inkprof.internal.drawBitmapText(image,labels(k),[rect(1)+4,rect(2)-2.4],dpi,1.6,"center",uint16(0));
 patches(k)=struct('page',page,'tiff',string(tiff),'label',labels(k),'rgbPercent',rgb,'rgb16',codes,'rectMm',rect);
end
image=inkprof.internal.drawBitmapText(image,"PRINT CHECK - SPOT ONLY", ...
 [width/2,height-furniture.chartReservedMm+12],dpi,1.5,"center",uint16(0));
end
