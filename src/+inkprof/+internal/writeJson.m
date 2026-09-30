function writeJson(path,value)
text=jsonencode(value,PrettyPrint=true);
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0,'inkprof:IO','Cannot write %s',path);
c=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',text);
end
