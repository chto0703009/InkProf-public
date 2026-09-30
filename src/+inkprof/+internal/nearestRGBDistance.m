function distances=nearestRGBDistance(query,rgb)
%NEARESTRGBDISTANCE Euclidean nearest-point distance without extra toolboxes.
distances=zeros(size(query,1),1);
for first=1:512:size(query,1)
    idx=first:min(first+511,size(query,1));q=query(idx,:);
    squared=zeros(numel(idx),size(rgb,1));
    for channel=1:3,squared=squared+(q(:,channel)-rgb(:,channel)').^2;end
    distances(idx)=sqrt(min(squared,[],2));
end
end
