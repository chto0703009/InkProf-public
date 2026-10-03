% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testPrintWindowLifecycle
 tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
end
function testCancelButtons(tc)
f=inkprof.renderTarget();b=findobj(f,'Tag','renderCancel');b.ButtonPushedFcn(b,[]);verifyFalse(tc,isvalid(f));
f=inkprof.designTarget();b=findobj(f,'Tag','designCancel');b.ButtonPushedFcn(b,[]);verifyFalse(tc,isvalid(f));
end
function testCancelledPackage(tc)
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));n=0;
verifyError(tc,@()inkprof.createTarget(fullfile(w,'cancelled'),PatchCount=20,GraySteps=3,DPI=100,Continue=@keepGoing),'inkprof:Cancelled');
verifyFalse(tc,isfolder(fullfile(w,'cancelled')));
a=dir(w);verifyEqual(tc,numel(a),2);
    function yes=keepGoing()
        n=n+1;yes=n<2;
    end
end
function testSavedPages(tc)
w=string(tempname);cleanup=onCleanup(@()rmdir(w,'s'));
m=inkprof.createTarget(w,PatchCount=20,GraySteps=3,DPI=100);
t=jsondecode(fileread(fullfile(w,'target.json')));
f=inkprof.showPrintResult(w);closeFig=onCleanup(@()delete(f));
verifyEqual(tc,f.UserData.pageCount,m.pageCount);
verifyEqual(tc,t.printSettings.pageCount,m.pageCount);
verifyTrue(tc,contains(findobj(f,'Tag','savedPageCount').Text,sprintf('%d pages',m.pageCount)));
exportapp(f,'/tmp/inkprof-saved-result.png');
end
