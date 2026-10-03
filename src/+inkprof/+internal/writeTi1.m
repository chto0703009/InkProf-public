% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function xyz=writeTi1(path,target,template)
% Keep Argyll's own spacer/device helper tables; replace only the target table.
raw=fileread(template); ends=regexp(raw,'(?m)^END_DATA\s*\n','end');
assert(numel(ends)>=3,'inkprof:Template','Argyll helper tables missing.');
tail=raw(ends(1)+1:end);
rgb=target.rgbPercent;
xyz=target.estimatedXYZ;
if isempty(xyz)
    % Approximate D65 sRGB XYZ ONLY for patch recognition/layout heuristics.
    % This never transforms device RGB, and is not a printer characterization.
    v=rgb/100; linear=v/12.92;mask=v>0.04045;
    linear(mask)=((v(mask)+0.055)/1.055).^2.4;
    xyz=100*linear*[0.4124564 0.2126729 0.0193339;0.3575761 0.7151522 0.1191920;0.1804375 0.0721750 0.9503041];
end
fid=fopen(path,'w');assert(fid>=0,'inkprof:IO','Cannot write TI1.');c=onCleanup(@()fclose(fid));
fprintf(fid,'CTI1\nDESCRIPTOR "InkProf RGB target; XYZ estimates only"\nORIGINATOR "InkProf"\nCOLOR_REP "iRGB"\n');
white=regexp(raw,'(?m)^APPROX_WHITE_POINT[^\r\n]*','match','once');
assert(~isempty(white),'inkprof:Template','Missing approximate white in template.');
fprintf(fid,'%s\n',white);
fprintf(fid,'NUMBER_OF_FIELDS 7\nBEGIN_DATA_FORMAT\nSAMPLE_ID RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z\nEND_DATA_FORMAT\n');
fprintf(fid,'NUMBER_OF_SETS %d\nBEGIN_DATA\n',size(rgb,1));
for i=1:size(rgb,1)
    fprintf(fid,'%d %.17g %.17g %.17g %.17g %.17g %.17g\n',i,rgb(i,:),xyz(i,:));
end
fprintf(fid,'END_DATA\n%s',tail);
end
