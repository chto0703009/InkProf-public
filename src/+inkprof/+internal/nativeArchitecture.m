% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function info=nativeArchitecture(executable)
%NATIVEARCHITECTURE Inspect physical hardware, independent of MATLAB/Rosetta.
arguments,executable (1,1) string="",end
info=struct('Physical',"",'Slices',strings(1,0),'Native',false);
if ~ismac,return;end
persistent physical
if isempty(physical)
 [status,value]=probe("/usr/sbin/sysctl",["-n","hw.optional.arm64"]);
 if status==0 && strip(value)=="1",physical="arm64";else,physical="x86_64";end
end
info.Physical=physical;
if executable=="" || ~isfile(executable),return;end
[status,value]=probe("/usr/bin/lipo",["-archs",executable]);
if status==0
 info.Slices=reshape(split(strip(value)),1,[]);
 info.Native=any(info.Slices==physical);
end
end
function [status,output]=probe(executable,args)
status=-1;output="";log=string(tempname)+".log";cleanup=onCleanup(@()remove(log));
try
 list=java.util.ArrayList();for value=[executable,args],list.add(java.lang.String(char(value)));end
 builder=java.lang.ProcessBuilder(list);builder.redirectErrorStream(true);builder.redirectOutput(java.io.File(char(log)));
 process=builder.start();
 if ~process.waitFor(int64(10),java.util.concurrent.TimeUnit.SECONDS),process.destroyForcibly();process.waitFor();return;end
 status=double(process.exitValue());output=string(fileread(log));
catch
end
end
function remove(file),if isfile(file),delete(file);end,end
