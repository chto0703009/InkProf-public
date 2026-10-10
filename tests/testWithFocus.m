% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function tests=testWithFocus
tests=functiontests(localfunctions);
end
function testPreviousDialogTimerCannotCoverNext(tc)
p=uifigure('HandleVisibility','on');clean=onCleanup(@()delete(p));
inkprof.internal.withFocus(p,@()[]);
inkprof.internal.withFocus(p,@nextDialog);
verifyFalse(tc,isappdata(p,'InkProfNativeDialogOpen'));
    function nextDialog
        child=uifigure('HandleVisibility','on');childClean=onCleanup(@()delete(child));
        figure(child);drawnow;set(groot,'CurrentFigure',child);pause(.55);drawnow;
        verifyEqual(tc,groot().CurrentFigure,child);
        verifyTrue(tc,getappdata(p,'InkProfNativeDialogOpen'));
    end
end
function testErrorRestoresDialogFlag(tc)
p=uifigure;clean=onCleanup(@()delete(p));
verifyError(tc,@()inkprof.internal.withFocus(p,@fail),'inkprof:TestDialog');
verifyFalse(tc,isappdata(p,'InkProfNativeDialogOpen'));
end
function fail
error('inkprof:TestDialog','Cancelled test dialog.');
end
function testNativeDialogSuspendsAndRestoresOwner(tc)
p=uifigure('Visible','on');clean=onCleanup(@()delete(p));
g=inkprof.internal.suspendForFileDialog(p);
verifyEqual(tc,string(p.Visible),"off");clear g
verifyEqual(tc,string(p.Visible),"on");
p.Visible='off';g=inkprof.internal.suspendForFileDialog(p);clear g
verifyEqual(tc,string(p.Visible),"off");
end
function testNativeDialogErrorRestoresOwner(tc)
p=uifigure('Visible','on');clean=onCleanup(@()delete(p));
verifyError(tc,@()raiseWithGuard(p),'inkprof:TestDialog');
verifyEqual(tc,string(p.Visible),"on");
end
function raiseWithGuard(p)
g=inkprof.internal.suspendForFileDialog(p); %#ok<NASGU>
fail;
end
function testDeliveryUsesDefinedProfileName(tc)
p=struct('name','Project name','printing',struct('profileName','Defined ICC name'));
verifyEqual(tc,inkprof.internal.projectDeliveryProfileName(p),"Defined ICC name");
p.printing.profileName='';
verifyEqual(tc,inkprof.internal.projectDeliveryProfileName(p),"Project name");
end
