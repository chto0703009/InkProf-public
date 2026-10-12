% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function destination=offerTargetCopy(source,activity)
if nargin<2,activity=@(stage)[];end
% Offer external delivery after the complete project target has been saved.
destination="";
parent=uigetdir(char(fileparts(source)),'Save a copy of the TIFF16 print package elsewhere (Cancel keeps the project copy)');
if isequal(parent,0),return;end
activity("Copying print package");
destination=inkprof.internal.copyTargetPackage(source,string(parent),Activity=activity);
msgbox(char("Print package copied to:"+newline+destination+newline+"The project original is retained."),'Print copy saved','help');
end
