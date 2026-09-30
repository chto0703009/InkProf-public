function [image,info]=drawRowGuides(image,dpi,bodyX,boundariesY)
%DRAWROWGUIDES Matching solid ticks at row boundaries, outside scan margins.
% Dimensions are physical millimetres. Never paint inside the strip body.
width=size(image,2)*25.4/dpi;
gap=6;edge=3;lengthMm=min([6 bodyX(1)-gap-edge width-bodyX(2)-gap-edge]);
assert(lengthMm>=1,'inkprof:Geometry','Insufficient side margin for row guides; use a wider page or narrower strip.');
spans=[bodyX(1)-gap-lengthMm bodyX(1)-gap;bodyX(2)+gap bodyX(2)+gap+lengthMm];
thickness=.4;gray=uint16(round(.35*65535));
y=unique(round(boundariesY(:)*dpi/25.4)+1);
n=max(1,round(thickness*dpi/25.4));
for centre=reshape(y,1,[])
    yy=centre-floor(n/2)+(0:n-1);yy=yy(yy>=1&yy<=size(image,1));
    for side=1:2
        xx=ceil(spans(side,1)*dpi/25.4)+1:floor(spans(side,2)*dpi/25.4);
        image(yy,xx,:)=gray;
    end
end
info=struct('style',"solid paired row-boundary ticks",'grayFraction',.35, ...
    'thicknessMm',thickness,'lengthMm',lengthMm,'clearGapMm',gap, ...
    'xSpansMm',spans,'boundaryYmm',(y-1)*25.4/dpi);
end
