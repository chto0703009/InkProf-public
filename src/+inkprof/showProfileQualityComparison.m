% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function f=showProfileQualityComparison(folder)
%SHOWPROFILEQUALITYCOMPARISON Reopen saved results without rebuilding ICCs.
arguments
 folder (1,1) string = ""
end
f=[];
if folder==""
 [name,path]=uigetfile('comparison.csv','Select saved accuracy and gradient comparison');
 if isequal(name,0),return;end
 folder=string(path);
end
if isfile(folder),folder=string(fileparts(folder));end
T=readtable(fullfile(folder,'comparison.csv'),'TextType','string');
f=inkprof.internal.showProfileTradeoffResults(T,folder);
end
