function tests=testPrintFooter
tests=functiontests(localfunctions);
end
function testFilenameAndPatchArea(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
dpi=100;blank=repmat(uint16(65535),round(210*dpi/25.4),round(297*dpi/25.4),3);
a=inkprof.internal.drawPrintFurniture(blank,dpi,1,2,"2026-09-26 12:00","/Users/christer/Desktop/InkProf/projects/example-a/target_01.tif");
b=inkprof.internal.drawPrintFurniture(blank,dpi,1,2,"2026-09-26 12:00","/Users/christer/Desktop/InkProf/projects/example-b/target_01.tif");
different=any(a~=b,3);[y,x]=find(different);
verifyNotEmpty(tc,x);
verifyGreaterThan(tc,min(y)/dpi*25.4,190);
verifyGreaterThan(tc,min(x)/dpi*25.4,55);
verifyLessThan(tc,max(x)/dpi*25.4,242);
verifyEqual(tc,a(100:750,:,:),blank(100:750,:,:));
% Full-page footers must leave the last 8 mm white, including wrapped paths.
last=ceil((210-8)*dpi/25.4);
verifyEqual(tc,a(last:end,:,:),blank(last:end,:,:));
verifyError(tc,@()inkprof.internal.drawPrintFurniture(blank,dpi,1,1,"2026-09-26 12:00",join(repmat("W",1,300),"")), 'inkprof:Label');
end
