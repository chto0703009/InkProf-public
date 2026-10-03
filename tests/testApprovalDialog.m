% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testApprovalDialog
tests=functiontests(localfunctions);
end
function testEvidenceAndExplicitApproval(tc)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
folder=string(tempname);mkdir(folder);clean=onCleanup(@()rmdir(folder,'s'));
s=struct('count',1,'mean',2,'median',2,'p95',2,'max',2);
p=struct('coordinate','B1','role','colour','deltaE00',2,'predictedDeltaE00',.3,'gamutAssessment','model-reachable');
inkprof.internal.writeJson(fullfile(folder,'c3.json'),struct('summary',s,'patches',p));
inkprof.internal.writeJson(fullfile(folder,'feedback.json'),struct('recommendation','Review print conditions','repeatability',struct('status','within-reference'),'priorities',[]));
w=struct('State',struct('cycle',1),'output',@(id,key)fullfile(folder,string(id)+'.json'));
for approve=[false true]
 t=timer('StartDelay',1,'TimerFcn',@respond);cleanup=onCleanup(@()delete(t));start(t);
 result=inkprof.internal.approvalDialog(w);
 if approve,verifyTrue(tc,result.Confirmed);verifyEqual(tc,result.Notes,"Photographic prints; reviewed limitations.");
 else,verifyEmpty(tc,result);end
 clear cleanup
end
    function respond(~,~)
        f=findall(groot,'Tag','InkProfApproval');
        verifyEqual(tc,numel(f),1);
        table=findall(f,'Tag','approvalPatches');verifyEqual(tc,table.Data{1,1},'B1');
        evidence=findall(f,'Tag','approvalEvidence');verifyTrue(tc,any(contains(string(evidence.Value),'Review print conditions')));
        if approve
            notes=findall(f,'Tag','approvalNotes');notes.Value={'Photographic prints; reviewed limitations.'};
            box=findall(f,'Tag','approvalConfirm');box.Value=true;
            button=findall(f,'Tag','approvalSave');button.ButtonPushedFcn(button,[]);
        else
            f.CloseRequestFcn(f,[]);
        end
    end
end
