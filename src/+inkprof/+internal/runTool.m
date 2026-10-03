% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function result=runTool(executable,args,folder,timeoutSeconds,allowHelpExit)
% Direct process argv avoids shell interpretation of filenames and options.
if nargin<5, allowHelpExit=false; end
argv=java.util.ArrayList(); argv.add(java.lang.String(char(executable)));
for a=reshape(string(args),1,[]), argv.add(java.lang.String(char(a))); end
builder=java.lang.ProcessBuilder(argv);
builder.directory(java.io.File(char(folder))); builder.redirectErrorStream(true);
logPath=string(tempname(folder))+".log";
builder.redirectOutput(java.io.File(char(logPath)));
process=builder.start(); start=tic;
while process.isAlive()
    if toc(start)>timeoutSeconds
        process.destroyForcibly();
        error('inkprof:Timeout','%s timed out. Log: %s',executable,logPath);
    end
    pause(0.05);
end
output=string(fileread(logPath)); delete(logPath);
code=process.exitValue();
assert(code==0||(allowHelpExit&&code==1),'inkprof:Argyll','%s failed (%d): %s',executable,code,output);
result=struct('executable',string(executable),'arguments',string(args),'exitCode',double(code),'output',output);
end
