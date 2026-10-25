% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function result=runTool(executable,args,folder,timeoutSeconds,allowHelpExit)
% Direct process argv avoids shell interpretation of filenames and options.
if nargin<5, allowHelpExit=false; end
native=inkprof.internal.nativeArchitecture(string(executable));
launch=string(executable);launchArgs=reshape(string(args),1,[]);
if native.Native && native.Physical=="arm64",launch="/usr/bin/arch";launchArgs=["-arm64",string(executable),launchArgs];end
argv=java.util.ArrayList(); argv.add(java.lang.String(char(launch)));
for a=launchArgs, argv.add(java.lang.String(char(a))); end
builder=java.lang.ProcessBuilder(argv);
builder.directory(java.io.File(char(folder))); builder.redirectErrorStream(true);
logPath=string(tempname(folder))+".log";
builder.redirectOutput(java.io.File(char(logPath)));
try
 process=builder.start();
catch
 throwAsCaller(MException('inkprof:ExecutableUnavailable', ...
  'Cannot start %s on this computer. Its CPU architecture or runtime dependencies are incompatible. For ArgyllCMS, run setupInkProf(ArgyllBin="auto") from the updated program folder.',executable));
end
start=tic;
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
