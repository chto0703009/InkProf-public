% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testDialogText
tests=functiontests(localfunctions);
end
function testMultilineMotivation(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
value=char('Profile difference is small.','I will use iteration 2.');
text=inkprof.internal.dialogText(value);
verifySize(tc,text,[1 1]);
verifyEqual(tc,text,"Profile difference is small."+newline+"I will use iteration 2.");
verifyTrue(tc,~isempty(value)&&strlength(strtrim(text))>0);
end
function testBlankAndSingleLine(tc)
verifyEqual(tc,inkprof.internal.dialogText('one line'),"one line");
verifyEqual(tc,inkprof.internal.dialogText(strings(0,1)),"");
text=inkprof.internal.dialogText(char('   ','   '));
verifyTrue(tc,isempty(char(strtrim(text))));
end
