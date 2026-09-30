function [border,inner]=selectionBorder(rgb)
%SELECTIONBORDER Contrast for nominal on-screen RGB, not print colour accuracy.
rgb=max(0,min(1,double(reshape(rgb,1,3))));
linear=rgb/12.92;mask=rgb>.04045;linear(mask)=((rgb(mask)+.055)/1.055).^2.4;
y=dot(linear,[.2126 .7152 .0722]);
candidates=[1 0 0;0 1 1;0 0 0;1 1 1];luminance=[.2126;.7874;0;1];
contrast=(max(luminance,y)+.05)./(min(luminance,y)+.05);
if contrast(1)>=3 && norm(rgb-candidates(1,:))>.55,index=1;
elseif contrast(2)>=3,index=2;
else,[~,index]=max(contrast);end
border=candidates(index,:);
if (1.05/(y+.05))>=((y+.05)/.05),inner=[1 1 1];else,inner=[0 0 0];end
end
