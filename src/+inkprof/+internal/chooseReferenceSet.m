% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [file,cancelled]=chooseReferenceSet(fig,generatedFirst)
%CHOOSEREFERENCESET Ask which colours the C2 profile test target uses.
% Returns "" for InkProf's generated balanced set. The default reference set
% is kept per installation in local-config/reference-sets (not in the
% repository: reference data such as ColorChecker SG values may carry
% third-party licence terms).
file="";cancelled=false;
folder=fullfile(inkprof.paths().Root,'local-config','reference-sets');
default=dir(fullfile(folder,'*.*'));default=default(~[default.isdir]);
defaultLabel='Default reference set (choose file)';
if ~isempty(default),defaultLabel=['Default: ' default(1).name];end
options={defaultLabel,'Other file (Lab, Argyll .cie, TI1)…','Generated balanced set','Cancel'};
if generatedFirst,options=options([3 1 2 4]);end
choice=uiconfirm(fig,['Which colours should the profile test target contain? ' ...
    'Lab sets are reproduced through the ICC; TI1 device RGB is printed as-is and compared with the profile''s prediction.'], ...
    'Profile test target','Options',options,'DefaultOption',1,'CancelOption',4);
switch choice
    case 'Cancel',cancelled=true;
    case 'Generated balanced set'
    case defaultLabel
        if ~isempty(default)
            file=string(fullfile(default(1).folder,default(1).name));
        else
            file=pickFile();if file=="",cancelled=true;return;end
            keep=uiconfirm(fig,'Use this file as the default reference set on this computer?','Default reference set', ...
                'Options',{'Yes','No'},'DefaultOption',1);
            if strcmp(keep,'Yes')
                if ~isfolder(folder),mkdir(folder);end
                [~,stem,ext]=fileparts(file);copyfile(file,fullfile(folder,stem+ext));
            end
        end
    otherwise
        file=pickFile();if file=="",cancelled=true;end
end
    function f=pickFile()
        [n,p]=inkprof.internal.withFocus(fig,@uigetfile,{'*.txt;*.cie;*.ti1;*.ti2;*.ti3;*.cgats','Reference sets (Lab/XYZ table, CGATS, TI1)'},'Select reference set');
        if isequal(n,0),f="";else,f=string(fullfile(p,n));end
    end
end
