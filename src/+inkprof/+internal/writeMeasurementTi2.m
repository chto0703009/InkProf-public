% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function writeMeasurementTi2(path,layout)
%WRITEMEASUREMENTTI2 Write the TI2 measurement definition matching TIFF16.
rgb=vertcat(layout.rgbPercent);
inkprof.internal.requireRgb(rgb,100);
v=rgb/100;linear=v/12.92;mask=v>0.04045;
linear(mask)=((v(mask)+0.055)/1.055).^2.4;
xyz=100*linear*[0.4124564 0.2126729 0.0193339;0.3575761 0.7151522 0.1191920;0.1804375 0.0721750 0.9503041];
fid=fopen(path,'w');assert(fid>=0,'inkprof:IO','Cannot write TI2: %s',path);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'CTI2\n\n');
fprintf(fid,'DESCRIPTOR "InkProf TIFF16 chart information 2"\n');
fprintf(fid,'ORIGINATOR "InkProf"\n');
fprintf(fid,'CREATED "%s"\n',char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")));
fprintf(fid,'TARGET_INSTRUMENT "GretagMacbeth i1 Pro"\n');
fprintf(fid,'APPROX_WHITE_POINT "95.047 100.000 108.883"\n');
fprintf(fid,'COLOR_REP "iRGB"\n');
fprintf(fid,'PAPER_SIZE "263x195"\n');
fprintf(fid,'CHART_ID "%d"\n',sum(~[layout.isPadding]));
fprintf(fid,'STEPS_IN_PASS "29"\n');
fprintf(fid,'PASSES_IN_STRIPS2 "%s"\n',strjoin(repmat("20",1,max([layout.page])),","));
fprintf(fid,'STRIP_INDEX_PATTERN "0-9,@-9,@-9;1-999"\n');
fprintf(fid,'PATCH_INDEX_PATTERN "A-Z, A-Z"\n');
fprintf(fid,'INDEX_ORDER "STRIP_THEN_PATCH"\n\n');
fprintf(fid,'NUMBER_OF_FIELDS 8\nBEGIN_DATA_FORMAT\n');
fprintf(fid,'SAMPLE_ID SAMPLE_LOC RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z\nEND_DATA_FORMAT\n\n');
fprintf(fid,'NUMBER_OF_SETS %d\nBEGIN_DATA\n',numel(layout));
for k=1:numel(layout)
    fprintf(fid,'%s "%s" %.10f %.10f %.10f %.10f %.10f %.10f\n', ...
        layout(k).sampleId,layout(k).sampleLoc,rgb(k,:),xyz(k,:));
end
fprintf(fid,'END_DATA\n');
end
