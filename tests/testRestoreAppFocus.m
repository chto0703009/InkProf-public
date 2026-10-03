function tests=testRestoreAppFocus
tests=functiontests(localfunctions);
end
function testModalReturnAndChildClose(tc)
p=uifigure('Visible','on','HandleVisibility','on');cleanup=onCleanup(@()clean(p));
g=inkprof.internal.restoreAppFocus(p);other=uifigure('Visible','on');
original=@(src,~)delete(src);other.CloseRequestFcn=original;
clear g
verifyTrue(tc,isappdata(other,'InkProfFocusOwner'));
verifyEqual(tc,other.CloseRequestFcn,original);
verifyEqual(tc,getappdata(other,'InkProfFocusOwner'),p);
close(other);waitFocus(p);
verifyEqual(tc,groot().CurrentFigure,p);
g=inkprof.internal.restoreAppFocus(p);dialog=uifigure;delete(dialog);clear g
verifyEqual(tc,groot().CurrentFigure,p);
end
function testSiblingRetainsFocus(tc)
p=uifigure('HandleVisibility','on');cleanup=onCleanup(@()clean(p));
g=inkprof.internal.restoreAppFocus(p);a=uifigure('HandleVisibility','on');b=uifigure('HandleVisibility','on');clear g
children=onCleanup(@()clean([a,b]));
close(a);waitFocus(b);
verifyEqual(tc,groot().CurrentFigure,b);
close(b);waitFocus(p);
verifyEqual(tc,groot().CurrentFigure,p);
end
function testDeletedParentAndExistingWindow(tc)
p=uifigure;existing=uifigure;cleanup=onCleanup(@()clean([p,existing]));
g=inkprof.internal.restoreAppFocus(p);child=uifigure;clear g
verifyFalse(tc,isappdata(existing,'InkProfFocusOwner'));
delete(p);delete(child);pause(.15);drawnow;
verifyFalse(tc,isgraphics(p));verifyTrue(tc,isgraphics(existing));
end
function clean(figures)
for f=reshape(figures,1,[]),if isgraphics(f),delete(f);end,end
end

function waitFocus(target)
started=tic;
while toc(started)<3
 drawnow;
 if isequal(groot().CurrentFigure,target),return;end
 pause(.05);
end
end
