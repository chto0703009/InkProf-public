% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function options=approvalDialog(w)
%APPROVALDIALOG Show saved evidence before requesting explicit user approval.
options=[];dismissed=false;
reportFile=w.output('c3','report');report=jsondecode(fileread(reportFile));
feedbackFile=w.output('feedback','feedback');feedback=jsondecode(fileread(feedbackFile));
profile=w.output('profile','profile');s=report.summary;
f=uifigure('Name','InkProf - Review profile before approval','Position',[130 100 1050 780], ...
    'WindowStyle','modal','Tag','InkProfApproval');
g=uigridlayout(f,[8 1]);g.RowHeight={32,150,'1x',45,28,85,42,40};g.Padding=[16 16 16 16];
uilabel(g,'Text','Review the result before approving this profile','FontSize',20,'FontWeight','bold');
lines=["Profile: "+profile;"Iteration: "+w.State.cycle; ...
    sprintf('Verification: %d unique patches | mean %.3f | median %.3f | 95th percentile %.3f | maximum %.3f ΔE00',s.count,s.mean,s.median,s.p95,s.max); ...
    "ΔE00 describes colour difference; lower values mean closer colours."; ...
    "Feedback: "+string(feedback.recommendation); ...
    "Repeatability: "+string(feedback.repeatability.status)+" | Patches prioritised for review: "+numel(feedback.priorities); ...
    "Saved verification: "+reportFile];
uitextarea(g,'Value',cellstr(lines),'Editable','off','Tag','approvalEvidence');
p=report.patches;[~,order]=sort([p.deltaE00],'descend');p=p(order);rows=cell(numel(p),5);
for k=1:numel(p)
    rows(k,:)={char(string(p(k).coordinate)),char(string(p(k).role)),p(k).deltaE00,p(k).predictedDeltaE00, ...
        char(string(p(k).gamutAssessment))};
end
uitable(g,'Data',rows,'ColumnName',{'Patch','Role','Measured vs desired ΔE00','Model vs measurement ΔE00','Model gamut assessment'}, ...
    'ColumnWidth',{65,100,200,210,'auto'},'RowName',{},'ColumnEditable',false,'Tag','approvalPatches');
uilabel(g,'Text','Largest colour differences are listed first. Consider print settings, measurement repeatability and the limits of the printer, paper and ink. Approval is for your stated use; it is not ISO certification.','WordWrap','on');
uilabel(g,'Text','Your assessment: intended use, quality requirements and accepted limitations');
notes=uitextarea(g,'Value',{''},'Tag','approvalNotes');
confirm=uicheckbox(g,'Text','I have reviewed these results and checked that the print settings match the project.', ...
    'Value',false,'Tag','approvalConfirm');
bar=uigridlayout(g,[1 2]);bar.Padding=[0 0 0 0];
uibutton(bar,'Text','Cancel - continue reviewing','ButtonPushedFcn',@cancel);
uibutton(bar,'Text','Approve for stated use','ButtonPushedFcn',@accept,'Tag','approvalSave');
f.CloseRequestFcn=@cancel;
topGuard=inkprof.internal.lowerTopWindows(f); %#ok<NASGU> keep the dialog above always-on-top windows
if ~dismissed,uiwait(f);end
if isvalid(f),delete(f);end
    function cancel(~,~)
        dismissed=true;uiresume(f);
    end
    function accept(~,~)
        note=strtrim(join(string(notes.Value),newline));
        if ~confirm.Value||strlength(note)==0
            uialert(f,'Review the results, record your assessment and tick the confirmation before approving.','Review required');return
        end
        options=struct('Confirmed',true,'Notes',note);
        dismissed=true;uiresume(f);
    end
end
