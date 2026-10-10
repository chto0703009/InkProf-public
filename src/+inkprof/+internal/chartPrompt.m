% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function state=chartPrompt(text)
%CHARTPROMPT Recognize complete prompts only; never send keys automatically.
text=string(text);text=replace(text,char(13),"");
state=struct('kind',"busy",'row',NaN,'allRead',false,'text',text);
row=regexp(char(text),'Ready to read strip pass (\d+)','tokens');
starts=regexp(char(text),'Ready to read strip pass \d+','start');
if ~isempty(row),state.row=str2double(row{end}{1});end
if ~isempty(regexp(char(text),'(?:Trigger instrument switch or any other key to start:|Trigger instrument switch to start reading\.|Press any other key to start:)\s*$','once'))
 if isempty(row),return;end
 state.kind="row";state.allRead=contains(extractAfter(text,starts(end)-1),"ALL ROWS READ");
elseif ~isempty(regexp(char(text),'Hit Return to use it anyway, any other key to retry, Esc or\s*''q'' to give up:\s*$','once'))
 state.kind="unexpected";
elseif ~isempty(regexp(char(text),'Hit Esc(?: or\s*''q'')? to give up, any other key to retry:\s*$','once'))
 state.kind="retry";
elseif ~isempty(regexp(char(text),'Hit any key to retry, or Esc or Q to abort:\s*$','once'))
 state.kind="calibrationRetry";
elseif contains(text,"Place the instrument on its reflective white reference") && ...
 ~isempty(regexp(char(text),'or hit Esc or Q to abort:\s*$','once'))
 state.kind="calibration";
end
end
