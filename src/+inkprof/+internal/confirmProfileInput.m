% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [accepted,name]=confirmProfileInput(summary,name)
% Show the B1 decision visibly before waiting; do not block the MATLAB desktop.
accepted=false;dismissed=false;
f=uifigure('Name','InkProf - Select profile input','Tag','InkProfProfileInput', ...
 'Position',[180 140 850 650],'WindowStyle','alwaysontop','Visible','off');
cleanup=onCleanup(@()closeFigure(f));g=uigridlayout(f,[4 1]);g.RowHeight={25,32,'1x',36};
uilabel(g,'Text','Name for the frozen measurement revision');
field=uieditfield(g,'text','Value',char(name),'Tag','ProfileInputName');
uitextarea(g,'Value',splitlines(string(summary)),'Editable','off');
b=uigridlayout(g,[1 2]);b.Padding=[0 0 0 0];
uibutton(b,'Text','Lock profile input','Tag','LockProfileInput','ButtonPushedFcn',@accept);
uibutton(b,'Text','Cancel','Tag','CancelProfileInput','ButtonPushedFcn',@cancel);
f.CloseRequestFcn=@cancel;
f.Visible='on';drawnow;focus(f);
fprintf('InkProf B1: review the Select profile input window; choose Lock profile input or Cancel.\n');
topGuard=inkprof.internal.lowerTopWindows(f); %#ok<NASGU> keep the dialog above always-on-top windows
if ~dismissed,uiwait(f);end
if isvalid(f),name=string(field.Value);delete(f);end
 function accept(~,~)
  if strlength(strtrim(string(field.Value)))==0,uialert(f,'Enter a name.','Profile input');return;end
  accepted=true;dismissed=true;uiresume(f);
 end
 function cancel(~,~)
  dismissed=true;uiresume(f);
 end
end
function closeFigure(f)
if isvalid(f),delete(f);end
end
