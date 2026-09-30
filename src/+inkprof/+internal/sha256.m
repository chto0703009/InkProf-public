function hash = sha256(path)
fid=fopen(path,'rb'); assert(fid>=0,'inkprof:IO','Cannot read %s',path);
closer=onCleanup(@()fclose(fid));
md=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    b=fread(fid,1048576,'*uint8');
    if ~isempty(b), md.update(typecast(b,'int8')); end
end
hash=lower(string(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[])));
end
