% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testArgyllExecutableValidation
tests=functiontests(localfunctions);
end
function testExistingButBrokenToolsAreRejected(tc)
assumeFalse(tc,ispc);folder=string(tempname);mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s'));
for tool=["targen","printtarg"]
 p=fullfile(folder,tool);f=fopen(p,'w');fprintf(f,'#!/bin/sh\nexit 126\n');fclose(f);fileattrib(p,'+x','a');
end
verifyFalse(tc,inkprof.internal.argyllUsable(folder));
end
function testRunnableVersionHelpIsAccepted(tc)
assumeFalse(tc,ispc);folder=string(tempname);mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s'));
for tool=["targen","printtarg"]
 p=fullfile(folder,tool);f=fopen(p,'w');fprintf(f,'#!/bin/sh\necho "Version 3.5.0"\nexit 1\n');fclose(f);fileattrib(p,'+x','a');
end
verifyTrue(tc,inkprof.internal.argyllUsable(folder));
end
function testAutoSelectionDropsMachineSpecificConfig(tc)
c=struct('schemaVersion',1,'argyllBin','/old/computer/bin','argyllBinSource','explicit');
c=inkprof.internal.argyllLocalConfig(c,"","auto",false);
verifyFalse(tc,isfield(c,'argyllBin'));verifyFalse(tc,isfield(c,'argyllBinSource'));
end
