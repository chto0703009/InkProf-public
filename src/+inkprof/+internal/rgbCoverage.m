function result=rgbCoverage(rgb)
%RGBCOVERAGE Separate sampled interior/surface coverage; not colour error.
a=linspace(0,1,33);[r,g,b]=ndgrid(a,a,a);q=[r(:) g(:) b(:)];
surface=any(q==0 | q==1,2);d=inkprof.internal.nearestRGBDistance(q,rgb);
result=struct('metric',"Nearest fitting-point distance in normalized RGB", ...
    'probeLevels',33,'maximumIsSampled',true,'interior',summary(d(~surface)), ...
    'surface',summary(d(surface)),'boundaryFitCount',sum(any(rgb==0 | rgb==1,2)), ...
    'interiorFitCount',sum(all(rgb>0 & rgb<1,2)));
end
function s=summary(d)
d=sort(d);s=struct('probeCount',numel(d),'mean',mean(d),'p95',d(ceil(.95*numel(d))),'max',max(d));
end
