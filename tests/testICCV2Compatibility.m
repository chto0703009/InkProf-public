% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testICCV2Compatibility
tests=functiontests(localfunctions);
end
function testV2PassesThroughWithoutConversion(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
f=string(tempname);c=onCleanup(@()delete(f));h=zeros(128,1,'uint8');h(9)=2;fid=fopen(f,'wb');fwrite(fid,h);fclose(fid);
[profile,r]=inkprof.internal.iccV2Compatibility(f,string(tempname));
verifyEqual(tc,profile,f);verifyFalse(tc,r.converted);
end
function testV4CancelDoesNotCreateCopy(tc)
f=string(tempname);c=onCleanup(@()delete(f));h=zeros(128,1,'uint8');h(9)=4;fid=fopen(f,'wb');fwrite(fid,h);fclose(fid);dest=string(tempname);
t=timer('ExecutionMode','fixedSpacing','Period',.3,'TimerFcn',@cancel);cleanup=onCleanup(@()dispose(t));start(t);
verifyError(tc,@()inkprof.internal.iccV2Compatibility(f,dest),'inkprof:Cancelled');
verifyFalse(tc,isfolder(dest));
 function cancel(~,~)
  b=findall(groot,'Tag','CancelV2Conversion');
  if isempty(b),return;end
  cb=b(1).ButtonPushedFcn;stop(t);if isa(cb,'function_handle'),cb(b(1),[]);elseif iscell(cb),feval(cb{1},b(1),[],cb{2:end});end
 end
end
function dispose(t)
if isvalid(t),stop(t);delete(t);end
end
