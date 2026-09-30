function writeExchangeCgats(patchPath,layoutPath,target,layout)
%WRITEEXCHANGECGATS Write source-order and physical-order RGB CGATS tables.
inkprof.internal.requireRgb(target.rgbOriginal,target.rgbScale);
inkprof.internal.requireRgb(vertcat(layout.rgbPercent),100);
fid=fopen(patchPath,'w');assert(fid>=0,'inkprof:IO','Cannot write CGATS: %s',patchPath);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'CGATS.17\nORIGINATOR "InkProf"\nDESCRIPTOR "RGB patch definition in source order"\n');
fprintf(fid,'RGB_SCALE "%.17g"\nSOURCE_SHA256 "%s"\n',target.rgbScale,target.sourceSHA256);
fprintf(fid,'NUMBER_OF_FIELDS 5\nBEGIN_DATA_FORMAT\nSAMPLE_ID SAMPLE_NAME RGB_R RGB_G RGB_B\nEND_DATA_FORMAT\n');
fprintf(fid,'NUMBER_OF_SETS %d\nBEGIN_DATA\n',numel(target.ids));
for k=1:numel(target.ids)
    fprintf(fid,'"%s" "%s" %.17g %.17g %.17g\n',escape(target.ids(k)),escape(target.names(k)),target.rgbOriginal(k,:));
end
fprintf(fid,'END_DATA\n');clear cleanup

fid=fopen(layoutPath,'w');assert(fid>=0,'inkprof:IO','Cannot write CGATS: %s',layoutPath);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'CGATS.17\nORIGINATOR "InkProf"\nDESCRIPTOR "Physical TIFF16 patch order"\n');
fprintf(fid,'RGB_SCALE "100"\nNUMBER_OF_FIELDS 9\nBEGIN_DATA_FORMAT\n');
fprintf(fid,'SAMPLE_ID SAMPLE_NAME SAMPLE_LOC PAGE ROW_ON_PAGE IS_PADDING RGB_R RGB_G RGB_B\nEND_DATA_FORMAT\n');
fprintf(fid,'NUMBER_OF_SETS %d\nBEGIN_DATA\n',numel(layout));
for k=1:numel(layout)
    fprintf(fid,'"%s" "%s" "%s" %d %d %d %.10f %.10f %.10f\n',layout(k).sampleId, ...
        escape(layout(k).originalName),layout(k).sampleLoc,layout(k).page,layout(k).rowOnPage,layout(k).isPadding,layout(k).rgbPercent);
end
fprintf(fid,'END_DATA\n');
end

function value=escape(value)
value=replace(string(value),'"','''');
end
