function [rgb,clipped]=labD50ToSRGB(lab)
% Display preview only: D50 Lab -> Bradford D65 -> clipped sRGB.
assert(size(lab,2)==3&&all(isfinite(lab),'all'),'inkprof:Colour','Finite Lab triplets required.');
% CIELAB D50 -> XYZ D50 -> Bradford D65 -> display sRGB.
f=(lab(:,1)+16)/116;
q=[f+lab(:,2)/500,f,f-lab(:,3)/200];delta=6/29;
x=q.^3;low=q<=delta;x(low)=3*delta^2*(q(low)-4/29);
white50=[0.9642956764;1;0.8251046025];white65=[0.9504559271;1;1.0890577508];
xyz=x.*white50';
B=[0.8951 0.2664 -0.1614;-0.7502 1.7135 0.0367;0.0389 -0.0685 1.0296];
A=B\(diag((B*white65)./(B*white50))*B);
xyz=xyz*A';
M=[3.2406 -1.5372 -0.4986;-0.9689 1.8758 0.0415;0.0557 -0.2040 1.0570];
linear=xyz*M';rgb=12.92*linear;high=linear>0.0031308;
rgb(high)=1.055*linear(high).^(1/2.4)-0.055;
clipped=any(rgb<0 | rgb>1,2);rgb=max(0,min(1,rgb));
end
