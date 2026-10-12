% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function [image,patches]=drawPrintControls(image,dpi,page,tiff)
% Raw device RGB sentinels; deliberately absent from TI1/TI2 and fitting data.
width=size(image,2)/dpi*25.4;
patches=struct('page',{},'tiff',{},'label',{},'rgbPercent',{},'rgb16',{},'rectMm',{});
labels=["R","G","B"];
for k=1:3
 rect=[width-40+(k-1)*12,7,8,8];
 rgb=zeros(1,3);rgb(k)=100;codes=round(rgb/100*65535);
 % Extend the rendered control by one pixel on every side.
 x=max(1,floor(rect(1)*dpi/25.4)):min(size(image,2),ceil((rect(1)+rect(3))*dpi/25.4)+1);
 y=max(1,floor(rect(2)*dpi/25.4)):min(size(image,1),ceil((rect(2)+rect(4))*dpi/25.4)+1);
 image(y,x,:)=repmat(reshape(uint16(codes),1,1,3),numel(y),numel(x),1);
 image=inkprof.internal.drawBitmapText(image,labels(k),[rect(1)+4,rect(2)-2.4],dpi,1.6,"center",uint16(0));
 actualRect=[x(1)-1,y(1)-1,numel(x),numel(y)]/dpi*25.4;
 patches(k)=struct('page',page,'tiff',string(tiff),'label',labels(k),'rgbPercent',rgb,'rgb16',codes,'rectMm',actualRect);
end
% Keep the bottom caption below the expanded squares at every supported DPI.
scale=max(1,floor(1.5*dpi/25.4/7));
bottom=max(arrayfun(@(p)p.rectMm(2)+p.rectMm(4),patches));
captionY=max(16.5,bottom+1+round(3.5*scale)*25.4/dpi);
image=inkprof.internal.drawBitmapText(image,"PRINT CHECK - SPOT ONLY", ...
 [width-24,captionY],dpi,1.5,"center",uint16(0));
end
